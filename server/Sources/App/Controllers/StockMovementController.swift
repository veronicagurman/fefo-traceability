import Vapor

struct CreateStockMovementRequest: Content {
    let batchID: UUID
    let fromLocationID: UUID
    let toLocationID: UUID
    let quantity: Int
}

struct StockMovementResponse: Content {
    let id: UUID
    let batchID: UUID
    let userID: UUID?
    let userEmail: String?
    let fromLocationID: UUID?
    let toLocationID: UUID?
    let quantity: Int
    let operationType: String
    let createdAt: Date

    init(movement: StockMovement, userEmail: String? = nil) throws {
        guard let id = movement.id else {
            throw Abort(.internalServerError, reason: "Movement ID is missing")
        }

        self.id = id
        self.batchID = movement.$batch.id
        self.userID = movement.$user.id
        self.userEmail = userEmail
        self.fromLocationID = movement.$fromLocation.id
        self.toLocationID = movement.$toLocation.id
        self.quantity = movement.quantity
        self.operationType = movement.operationType
        self.createdAt = movement.createdAt
    }
}

struct StockMovementController {
    private let service = StockMovementService()

    func index(req: Request) async throws -> [StockMovementResponse] {
        let movements = try await service.all(on: req.db)
        let usersByID = try await service.usersByID(on: req.db)

        return try movements.map { movement in
            let user = movement.$user.id.flatMap { usersByID[$0] }

            return try StockMovementResponse(
                movement: movement,
                userEmail: user?.email
            )
        }
    }

    func create(req: Request) async throws -> Response {
        let input = try req.content.decode(CreateStockMovementRequest.self)

        guard let currentUser = req.auth.get(AppUser.self),
              let currentUserID = currentUser.id else {
            throw Abort(.unauthorized, reason: "Authentication required")
        }

        let movement = try await service.create(
            batchID: input.batchID,
            fromLocationID: input.fromLocationID,
            toLocationID: input.toLocationID,
            quantity: input.quantity,
            userID: currentUserID,
            on: req.db
        )

        let response = try StockMovementResponse(
            movement: movement,
            userEmail: currentUser.email
        )

        return try await response.encodeResponse(status: .created, for: req)
    }
}
