import Foundation
import Combine

enum MovementMetric: String, CaseIterable, Identifiable {
    case operations = "Операции"
    case quantity = "Единицы"

    var id: String { rawValue }
}

struct ZoneSegment: Identifiable {
    let zone: String
    let category: String
    let quantity: Int
    var id: String { zone + category }
}

struct ParetoPoint: Identifiable {
    let rank: Int
    let cumulative: Double
    var id: Int { rank }
}

@MainActor
final class BusinessAnalyticsViewModel: ObservableObject {
    @Published var movementMetric: MovementMetric = .operations

    private let repository: any FEFORepository

    init(repository: any FEFORepository) {
        self.repository = repository
    }

    var data: BusinessAnalyticsResponse? {
        repository.business
    }

    var zoneSegments: [ZoneSegment] {
        guard let data else { return [] }

        return data.zones.flatMap { zone -> [ZoneSegment] in
            let normal = max(0, zone.quantity - zone.expiredQuantity - zone.atRiskQuantity)

            return [
                ZoneSegment(zone: zone.zone, category: "Просрочено", quantity: zone.expiredQuantity),
                ZoneSegment(zone: zone.zone, category: "До 7 дней", quantity: zone.atRiskQuantity),
                ZoneSegment(zone: zone.zone, category: "В норме", quantity: normal)
            ]
        }
    }

    var topABC: [BizABCItem] {
        Array((data?.abc ?? []).prefix(12))
    }

    var paretoPoints: [ParetoPoint] {
        (data?.abc ?? []).enumerated().map { index, item in
            ParetoPoint(rank: index + 1, cumulative: item.cumulativePercent)
        }
    }

    func refresh() async {
        await repository.refresh()
    }
}
