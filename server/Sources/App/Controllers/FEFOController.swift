import Vapor

struct FEFOItem: Content {
    let batchID: UUID
    let batchNumber: String
    let productID: UUID
    let productName: String
    let sku: String
    let storageLocationID: UUID
    let quantity: Int
    let expiresAt: Date
    let daysUntilExpiration: Int
    let isExpired: Bool
}

struct FEFOResponse: Content {
    let generatedAt: Date
    let totalPositions: Int
    let totalQuantity: Int
    let expiredPositions: Int
    let expiringWithinSevenDays: Int
    let items: [FEFOItem]
}

struct FEFOController {
    private let service = FEFOService()

    func index(req: Request) async throws -> FEFOResponse {
        try await service.calculate(on: req.db)
    }
}
