import Foundation

@MainActor
final class APIRepository: FEFORepository {
    private let apiService: APIService

    init(apiService: APIService) {
        self.apiService = apiService
    }

    var token: String? {
        apiService.token
    }

    var analytics: AnalyticsResponse? {
        apiService.analytics
    }

    var fefo: FEFOResponse? {
        apiService.fefo
    }

    var locations: [LocationItem] {
        apiService.locations
    }

    var movements: [StockMovementItem] {
        apiService.movements
    }

    var isLoading: Bool {
        apiService.isLoading
    }

    var errorMessage: String? {
        apiService.errorMessage
    }

    func login(email: String, password: String) async {
        await apiService.login(email: email, password: password)
    }

    func refresh() async {
        await apiService.refresh()
    }

    func moveStock(
        batchID: UUID,
        fromLocationID: UUID,
        toLocationID: UUID,
        quantity: Int
    ) async throws {
        try await apiService.moveStock(
            batchID: batchID,
            fromLocationID: fromLocationID,
            toLocationID: toLocationID,
            quantity: quantity
        )
    }
}
