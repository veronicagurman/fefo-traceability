import Foundation

struct BizKPI: Decodable {
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

struct BizInsight: Decodable, Identifiable {
    let level: String
    let text: String
    var id: String { level + text }
}

struct BizBucket: Decodable, Identifiable {
    let order: Int
    let label: String
    let quantity: Int
    let positions: Int
    var id: Int { order }
}

struct BizWeek: Decodable, Identifiable {
    let fromDay: Int
    let toDay: Int
    let quantity: Int
    let positions: Int
    var id: Int { fromDay }
}

struct BizZone: Decodable, Identifiable {
    let zone: String
    let quantity: Int
    let locations: Int
    let occupiedLocations: Int
    let expiredQuantity: Int
    let atRiskQuantity: Int
    var id: String { zone }
}

struct BizABCItem: Decodable, Identifiable {
    let productName: String
    let sku: String
    let quantity: Int
    let sharePercent: Double
    let cumulativePercent: Double
    let abcClass: String
    var id: String { sku + productName }
}

struct BizABCClass: Decodable, Identifiable {
    let abcClass: String
    let products: Int
    let quantity: Int
    let sharePercent: Double
    var id: String { abcClass }
}

struct BizProductRisk: Decodable, Identifiable {
    let productName: String
    let sku: String
    let quantity: Int
    let batches: Int
    let expiredQuantity: Int
    let atRiskQuantity: Int
    let nearestDaysLeft: Int?
    var id: String { sku + productName }
}

struct BizDayStat: Decodable, Identifiable {
    let date: Date
    let operations: Int
    let quantity: Int
    var id: Date { date }
}

struct BizUserStat: Decodable, Identifiable {
    let user: String
    let operations: Int
    let quantity: Int
    var id: String { user }
}

struct BizRouteStat: Decodable, Identifiable {
    let route: String
    let operations: Int
    let quantity: Int
    var id: String { route }
}

struct BusinessAnalyticsResponse: Decodable {
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
