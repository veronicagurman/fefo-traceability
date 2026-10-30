import Fluent
import Vapor

struct AnalyticsService {
    func calculate(on db: Database) async throws -> AnalyticsResponse {
        let products = try await Product.query(on: db).all()
        let batches = try await Batch.query(on: db).all()

        let placements = try await BatchPlacement.query(on: db)
            .filter(\.$quantity > 0)
            .all()

        let movements = try await StockMovement.query(on: db).all()

        let batchesByID = Dictionary(
            uniqueKeysWithValues: batches.compactMap { batch in
                batch.id.map { ($0, batch) }
            }
        )

        let now = Date()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .autoupdatingCurrent
        let today = calendar.startOfDay(for: now)

        var expired = 0
        var expiring = 0

        for placement in placements {
            guard let batch = batchesByID[placement.$batch.id] else {
                continue
            }

            let expirationDay = calendar.startOfDay(for: batch.expiresAt)
            let daysUntilExpiration = calendar.dateComponents(
                [.day],
                from: today,
                to: expirationDay
            ).day ?? 0

            if expirationDay < today {
                expired += 1
            } else if daysUntilExpiration >= 0 && daysUntilExpiration <= 7 {
                expiring += 1
            }
        }

        return AnalyticsResponse(
            generatedAt: now,
            totalProducts: products.count,
            totalBatches: batches.count,
            totalQuantity: placements.reduce(0) { $0 + $1.quantity },
            expiredPositions: expired,
            expiringWithinSevenDays: expiring,
            activeLocations: Set(placements.map { $0.$storageLocation.id }).count,
            recentMovements: movements.count
        )
    }
}
