import SwiftUI
import Combine

struct MovementDay: Identifiable {
    let date: Date
    let quantity: Int
    let operations: Int

    var id: Date { date }
}

@MainActor
final class AnalyticsExtrasViewModel: ObservableObject {
    @Published var selectedZone = "Все зоны"
    @Published var reportFilter = "Все позиции"
    @Published var exportMessage: String?
    @Published var showingMoveSheet = false

    private let repository: any FEFORepository

    init(repository: any FEFORepository) {
        self.repository = repository
    }

    var zones: [String] {
        ["Все зоны"] + Array(Set(repository.locations.map(\.zone))).sorted()
    }

    var filteredLocations: [LocationItem] {
        repository.locations
            .filter {
                selectedZone == "Все зоны" || $0.zone == selectedZone
            }
            .sorted {
                $0.code.localizedStandardCompare($1.code) == .orderedAscending
            }
    }

    var filteredFEFOItems: [FEFOItem] {
        let items = repository.fefo?.items ?? []

        return items.filter { item in
            switch reportFilter {
            case "Просроченные":
                return item.isExpired
            case "Скоро истекают":
                return !item.isExpired
                    && item.daysUntilExpiration >= 0
                    && item.daysUntilExpiration <= 7
            case "Без просрочки":
                return !item.isExpired
                    && item.daysUntilExpiration > 7
            default:
                return true
            }
        }
    }

    var movementDays: [MovementDay] {
        let calendar = Calendar.current

        let grouped = Dictionary(grouping: repository.movements) {
            calendar.startOfDay(for: $0.createdAt)
        }

        return grouped.map { date, movements in
            MovementDay(
                date: date,
                quantity: movements.reduce(0) { $0 + $1.quantity },
                operations: movements.count
            )
        }
        .sorted { $0.date < $1.date }
    }

    var totalMovementQuantity: Int {
        repository.movements.reduce(0) { $0 + $1.quantity }
    }

    var movementOperationsCount: Int {
        repository.movements.count
    }

    var recentMovements: [StockMovementItem] {
        Array(
            repository.movements.sorted {
                $0.createdAt > $1.createdAt
            }
            .prefix(30)
        )
    }

    func items(in locationID: UUID) -> [FEFOItem] {
        (repository.fefo?.items ?? [])
            .filter { $0.storageLocationID == locationID }
            .sorted { $0.expiresAt < $1.expiresAt }
    }

    func locationName(_ id: UUID?) -> String {
        guard let id else {
            return "—"
        }

        return repository.locations.first { $0.id == id }?.code
            ?? String(id.uuidString.prefix(8))
    }

    func refresh() async {
        await repository.refresh()
    }

    func exportSucceeded(fileName: String) {
        exportMessage = "Отчёт сохранён: \(fileName)"
    }

    func exportFailed(error: Error) {
        exportMessage = "Ошибка экспорта: \(error.localizedDescription)"
    }
}
