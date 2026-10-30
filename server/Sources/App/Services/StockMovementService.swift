import Fluent
import Vapor

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
}
