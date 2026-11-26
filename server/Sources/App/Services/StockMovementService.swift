import Fluent
import Vapor
import SQLKit

struct StockMovementService {
    func all(on db: Database) async throws -> [StockMovement] {
        try await StockMovement.query(on: db)
            .sort(\.$createdAt, .descending)
            .all()
    }

    func usersByID(on db: Database) async throws -> [UUID: AppUser] {
        let users = try await AppUser.query(on: db).all()
        var result: [UUID: AppUser] = [:]

        for user in users {
            if let id = user.id {
                result[id] = user
            }
        }

        return result
    }

    func create(
        batchID: UUID,
        fromLocationID: UUID,
        toLocationID: UUID,
        quantity: Int,
        userID: UUID,
        on db: Database
    ) async throws -> StockMovement {
        guard quantity > 0 else {
            throw Abort(.badRequest, reason: "Quantity must be greater than zero")
        }

        guard fromLocationID != toLocationID else {
            throw Abort(.badRequest, reason: "Source and destination must differ")
        }

        return try await db.transaction { database in
            guard let sql = database as? any SQLDatabase else {
                throw Abort(.internalServerError, reason: "SQL database is required")
            }

            _ = try await sql.raw("""
                SELECT id FROM batches
                WHERE id = \(bind: batchID)
                FOR UPDATE
                """).all()

            guard try await Batch.find(batchID, on: database) != nil else {
                throw Abort(.notFound, reason: "Batch not found")
            }

            guard try await StorageLocation.find(fromLocationID, on: database) != nil else {
                throw Abort(.notFound, reason: "Source location not found")
            }

            guard try await StorageLocation.find(toLocationID, on: database) != nil else {
                throw Abort(.notFound, reason: "Destination location not found")
            }

            guard let source = try await BatchPlacement.query(on: database)
                .filter(\.$batch.$id == batchID)
                .filter(\.$storageLocation.$id == fromLocationID)
                .first()
            else {
                throw Abort(.conflict, reason: "Batch is not placed in the source location")
            }

            guard source.quantity >= quantity else {
                throw Abort(
                    .conflict,
                    reason: "Not enough quantity in source location. Available: \(source.quantity)"
                )
            }

            let destination = try await BatchPlacement.query(on: database)
                .filter(\.$batch.$id == batchID)
                .filter(\.$storageLocation.$id == toLocationID)
                .first()

            if let destination {
                destination.quantity += quantity
                try await destination.save(on: database)
            } else {
                let newPlacement = BatchPlacement(
                    batchID: batchID,
                    storageLocationID: toLocationID,
                    quantity: quantity
                )

                try await newPlacement.save(on: database)
            }

            source.quantity -= quantity

            if source.quantity == 0 {
                try await source.delete(on: database)
            } else {
                try await source.save(on: database)
            }

            let record = StockMovement(
                batchID: batchID,
                userID: userID,
                fromLocationID: fromLocationID,
                toLocationID: toLocationID,
                quantity: quantity,
                operationType: "move"
            )

            try await record.save(on: database)
            return record
        }
    }

    func createShipment(
        productID: UUID,
        quantity: Int,
        userID: UUID,
        on db: Database
    ) async throws -> [StockMovement] {
        guard quantity > 0 else {
            throw Abort(.badRequest, reason: "Quantity must be greater than zero")
        }

        return try await db.transaction { database in
            guard let sql = database as? any SQLDatabase else {
                throw Abort(.internalServerError, reason: "SQL database is required")
            }

            _ = try await sql.raw("""
                SELECT id FROM batches
                WHERE product_id = \(bind: productID)
                ORDER BY id
                FOR UPDATE
                """).all()

            guard try await Product.find(productID, on: database) != nil else {
                throw Abort(.notFound, reason: "Product not found")
            }

            let batches = try await Batch.query(on: database)
                .filter(\.$product.$id == productID)
                .all()

            let placements = try await BatchPlacement.query(on: database)
                .filter(\.$quantity > 0)
                .all()

            let placementsByBatch = Dictionary(
                grouping: placements,
                by: { $0.$batch.id }
            )

            let now = Date()
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = .autoupdatingCurrent
            let today = calendar.startOfDay(for: now)

            let eligibleBatches = batches
                .filter {
                    calendar.startOfDay(for: $0.expiresAt) >= today &&
                    $0.remainingQuantity > 0
                }
                .sorted {
                    if $0.expiresAt != $1.expiresAt {
                        return $0.expiresAt < $1.expiresAt
                    }
                    return $0.batchNumber < $1.batchNumber
                }

            var remainingToShip = quantity
            var picks: [(batch: Batch, placement: BatchPlacement, quantity: Int)] = []

            for batch in eligibleBatches {
                guard let batchID = batch.id else { continue }

                let batchPlacements = (placementsByBatch[batchID] ?? [])
                    .sorted {
                        $0.$storageLocation.id.uuidString <
                        $1.$storageLocation.id.uuidString
                    }

                let placedQuantity = batchPlacements.reduce(0) {
                    $0 + $1.quantity
                }

                var availableInBatch = min(
                    batch.remainingQuantity,
                    placedQuantity
                )

                for placement in batchPlacements where remainingToShip > 0 {
                    guard availableInBatch > 0 else { break }

                    let picked = min(
                        placement.quantity,
                        min(availableInBatch, remainingToShip)
                    )

                    guard picked > 0 else { continue }

                    picks.append(
                        (batch: batch, placement: placement, quantity: picked)
                    )

                    availableInBatch -= picked
                    remainingToShip -= picked
                }

                if remainingToShip == 0 {
                    break
                }
            }

            guard remainingToShip == 0 else {
                let available = quantity - remainingToShip
                throw Abort(
                    .conflict,
                    reason: "Not enough available non-expired stock. Available: \(available)"
                )
            }

            var shippedByBatch: [UUID: Int] = [:]

            for pick in picks {
                guard let batchID = pick.batch.id else {
                    throw Abort(.internalServerError, reason: "Batch ID is missing")
                }

                shippedByBatch[batchID, default: 0] += pick.quantity

                pick.placement.quantity -= pick.quantity

                if pick.placement.quantity == 0 {
                    try await pick.placement.delete(on: database)
                } else {
                    try await pick.placement.save(on: database)
                }
            }

            for batch in eligibleBatches {
                guard let batchID = batch.id,
                      let shipped = shippedByBatch[batchID] else {
                    continue
                }

                guard batch.remainingQuantity >= shipped else {
                    throw Abort(.conflict, reason: "Batch balance changed")
                }

                batch.remainingQuantity -= shipped
                try await batch.save(on: database)
            }

            var records: [StockMovement] = []

            for pick in picks {
                let record = StockMovement(
                    batchID: pick.batch.id!,
                    userID: userID,
                    fromLocationID: pick.placement.$storageLocation.id,
                    toLocationID: nil,
                    quantity: pick.quantity,
                    operationType: "shipment"
                )

                try await record.save(on: database)
                records.append(record)
            }

            return records
        }
    }
}
