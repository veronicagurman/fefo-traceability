import Vapor

struct BusinessAnalyticsController {
    func index(req: Request) async throws -> BusinessAnalyticsResponse {
        try await BusinessAnalyticsService().calculate(on: req.db)
    }
}
