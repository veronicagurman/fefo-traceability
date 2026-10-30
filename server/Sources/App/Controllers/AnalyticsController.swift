import Vapor

struct AnalyticsResponse: Content {
    let generatedAt: Date
    let totalProducts: Int
    let totalBatches: Int
    let totalQuantity: Int
    let expiredPositions: Int
    let expiringWithinSevenDays: Int
    let activeLocations: Int
    let recentMovements: Int
}

struct AnalyticsController {
    private let service = AnalyticsService()

    func index(req: Request) async throws -> AnalyticsResponse {
        try await service.calculate(on: req.db)
    }
}
