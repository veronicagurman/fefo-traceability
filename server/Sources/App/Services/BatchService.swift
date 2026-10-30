import Fluent
import Vapor

struct BatchService {
    func all(on db: Database) async throws -> [Batch] {
        try await Batch.query(on: db)
            .sort(\.$expiresAt)
            .all()
    }

    func create(
        productID: UUID,
        batchNumber: String,
        quantity: Int,
        receivedAt: Date,
        expiresAt: Date,
        on db: Database
    ) async throws -> Batch {
        guard quantity > 0 else {
            throw Abort(.badRequest, reason: "Quantity must be greater than zero")
        }

        guard expiresAt > receivedAt else {
            throw Abort(.badRequest, reason: "Expiration must be after receipt")
        }

        guard try await Product.find(productID, on: db) != nil else {
            throw Abort(.notFound, reason: "Product not found")
        }

        let batch = Batch(
            productID: productID,
            batchNumber: batchNumber,
            quantity: quantity,
            receivedAt: receivedAt,
            expiresAt: expiresAt
        )

        try await batch.save(on: db)
        return batch
    }
}
