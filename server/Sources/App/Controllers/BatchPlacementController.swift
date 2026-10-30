import Fluent
import Vapor

struct CreateBatchPlacementRequest: Content {
    let batchID: UUID
    let storageLocationID: UUID
    let quantity: Int
}

struct BatchPlacementResponse: Content {
    let id: UUID
    let batchID: UUID
    let storageLocationID: UUID
    let quantity: Int
    let createdAt: Date

    init(placement: BatchPlacement) throws {
        guard let id = placement.id else {
            throw Abort(.internalServerError, reason: "Placement ID is missing")
        }

        self.id = id
        self.batchID = placement.$batch.id
        self.storageLocationID = placement.$storageLocation.id
        self.quantity = placement.quantity
        self.createdAt = placement.createdAt
    }
}

struct BatchPlacementController {
    private let service = BatchPlacementService()

    func index(req: Request) async throws -> [BatchPlacementResponse] {
        let placements = try await service.all(on: req.db)

        return try placements.map {
            try BatchPlacementResponse(placement: $0)
        }
    }

    func create(req: Request) async throws -> Response {
        let input = try req.content.decode(CreateBatchPlacementRequest.self)

        let placement = try await service.create(
            batchID: input.batchID,
            storageLocationID: input.storageLocationID,
            quantity: input.quantity,
            on: req.db
        )

        let response = try BatchPlacementResponse(placement: placement)
        return try await response.encodeResponse(status: .created, for: req)
    }
}
