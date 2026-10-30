import Foundation
import Combine

@MainActor
final class ContentViewModel: ObservableObject {
    @Published var email = "test@fefo.local"
    @Published var password = ""
    @Published var selectedTab = 0
    @Published var expiryFilter = "Все позиции"

    let expiryFilters = [
        "Все позиции",
        "Истекают за 7 дней",
        "Просроченные"
    ]

    private let repository: any FEFORepository

    init(repository: any FEFORepository) {
        self.repository = repository
    }

    func login() async {
        await repository.login(email: email, password: password)
    }

    func refresh() async {
        await repository.refresh()
    }

    func filteredItems(_ items: [FEFOItem]) -> [FEFOItem] {
        switch expiryFilter {
        case "Истекают за 7 дней":
            return items.filter {
                !$0.isExpired
                    && $0.daysUntilExpiration >= 0
                    && $0.daysUntilExpiration <= 7
            }

        case "Просроченные":
            return items.filter { $0.isExpired }

        default:
            return items
        }
    }
}
