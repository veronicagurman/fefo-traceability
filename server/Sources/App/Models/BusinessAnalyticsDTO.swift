import Vapor

struct BizKPI: Content, Sendable {
    let totalQuantity: Int
    let totalPositions: Int
    let expiredQuantity: Int
    let atRiskQuantity: Int
    let expiredSharePercent: Double
    let atRiskSharePercent: Double
    let avgShelfLifeLeftPercent: Double
    let unplacedQuantity: Int
    let totalLocations: Int
    let occupiedLocations: Int
    let occupancyPercent: Double
    let movementsLast30Days: Int
    let movedQuantityLast30Days: Int
}

struct BizInsight: Content, Sendable {
    let level: String
    let text: String
}

struct BizBucket: Content, Sendable {
    let order: Int
    let label: String
    let quantity: Int
    let positions: Int
}

struct BizWeek: Content, Sendable {
    let fromDay: Int
    let toDay: Int
    let quantity: Int
    let positions: Int
}

struct BizZone: Content, Sendable {
    let zone: String
    let quantity: Int
    let locations: Int
    let occupiedLocations: Int
    let expiredQuantity: Int
    let atRiskQuantity: Int
}

struct BizABCItem: Content, Sendable {
    let productName: String
    let sku: String
    let quantity: Int
    let sharePercent: Double
    let cumulativePercent: Double
    let abcClass: String
}

struct BizABCClass: Content, Sendable {
    let abcClass: String
    let products: Int
    let quantity: Int
    let sharePercent: Double
}

struct BizProductRisk: Content, Sendable {
    let productName: String
    let sku: String
    let quantity: Int
    let batches: Int
    let expiredQuantity: Int
    let atRiskQuantity: Int
    let nearestDaysLeft: Int?
}

struct BizDayStat: Content, Sendable {
    let date: Date
    let operations: Int
    let quantity: Int
}

struct BizUserStat: Content, Sendable {
    let user: String
    let operations: Int
    let quantity: Int
}

struct BizRouteStat: Content, Sendable {
    let route: String
    let operations: Int
    let quantity: Int
}

struct BusinessAnalyticsResponse: Content, Sendable {
    let generatedAt: Date
    let kpi: BizKPI
    let insights: [BizInsight]
    let expiryBuckets: [BizBucket]
    let shelfLifeBuckets: [BizBucket]
    let expiryTimeline: [BizWeek]
    let zones: [BizZone]
    let abc: [BizABCItem]
    let abcSummary: [BizABCClass]
    let productRisks: [BizProductRisk]
    let movementsByDay: [BizDayStat]
    let topUsers: [BizUserStat]
    let topRoutes: [BizRouteStat]
}
