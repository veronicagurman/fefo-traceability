import Vapor

struct CreateBatchRequest: Content {
    let productID: UUID
    let batchNumber: String
    let quantity: Int
    let receivedAt: Date
    let expiresAt: Date
}

struct BatchResponse: Content {
    let id: UUID
    let productID: UUID
    let batchNumber: String
    let quantity: Int
    let receivedAt: Date
    let expiresAt: Date

    init(batch: Batch) throws {
        guard let id = batch.id else {
            throw Abort(.internalServerError, reason: "Batch ID is missing")
        }

        self.id = id
        self.productID = batch.$product.id
        self.batchNumber = batch.batchNumber
        self.quantity = batch.quantity
        self.receivedAt = batch.receivedAt
        self.expiresAt = batch.expiresAt
    }
}

struct BatchController {
    private let service = BatchService()

    func index(req: Request) async throws -> [BatchResponse] {
        let batches = try await service.all(on: req.db)
        return try batches.map { try BatchResponse(batch: $0) }
    }

    func create(req: Request) async throws -> Response {
        let input = try req.content.decode(CreateBatchRequest.self)

        let batch = try await service.create(
            productID: input.productID,
            batchNumber: input.batchNumber,
            quantity: input.quantity,
            receivedAt: input.receivedAt,
            expiresAt: input.expiresAt,
            on: req.db
        )

        let response = try BatchResponse(batch: batch)
        return try await response.encodeResponse(status: .created, for: req)
    }
}
