import Fluent
import Vapor
import SQLKit

struct BatchPlacementService {
    func all(on db: Database) async throws -> [BatchPlacement] {
        try await BatchPlacement.query(on: db)
            .sort(\.$createdAt, .descending)
            .all()
    }

    func create(
        batchID: UUID,
        storageLocationID: UUID,
        quantity: Int,
        on db: Database
    ) async throws -> BatchPlacement {
        guard quantity > 0 else {
            throw Abort(.badRequest, reason: "Quantity must be greater than zero")
        }

        return try await db.transaction { transaction in
            guard let sql = transaction as? any SQLDatabase else {
                throw Abort(
                    .internalServerError,
                    reason: "SQL database is required"
                )
            }

            _ = try await sql.raw("""
                SELECT id
                FROM batches
                WHERE id = \(bind: batchID)
                FOR UPDATE
                """).all()

            guard let batch = try await Batch.find(batchID, on: transaction) else {
                throw Abort(.notFound, reason: "Batch not found")
            }

            guard try await StorageLocation.find(
                storageLocationID,
                on: transaction
            ) != nil else {
                throw Abort(.notFound, reason: "Storage location not found")
            }

            let existingPlacements = try await BatchPlacement.query(on: transaction)
                .filter(\.$batch.$id == batchID)
                .all()

            let alreadyPlaced = existingPlacements.reduce(0) {
                $0 + $1.quantity
            }

            let availableQuantity = batch.remainingQuantity - alreadyPlaced

            guard quantity <= max(0, availableQuantity) else {
                throw Abort(
                    .conflict,
                    reason: "Not enough unplaced quantity. Available: \(max(0, availableQuantity))"
                )
            }

            let duplicate = try await BatchPlacement.query(on: transaction)
                .filter(\.$batch.$id == batchID)
                .filter(\.$storageLocation.$id == storageLocationID)
                .first()

            guard duplicate == nil else {
                throw Abort(
                    .conflict,
                    reason: "This batch is already placed in this storage location"
                )
            }

            let placement = BatchPlacement(
                batchID: batchID,
                storageLocationID: storageLocationID,
                quantity: quantity
            )

            try await placement.save(on: transaction)
            return placement
        }
    }
}
