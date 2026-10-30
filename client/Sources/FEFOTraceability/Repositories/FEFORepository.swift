import Foundation

@MainActor
protocol FEFORepository {
    var token: String? { get }
    var analytics: AnalyticsResponse? { get }
    var fefo: FEFOResponse? { get }
    var locations: [LocationItem] { get }
    var movements: [StockMovementItem] { get }
    var isLoading: Bool { get }
    var errorMessage: String? { get }

    func login(email: String, password: String) async
    func refresh() async

    func moveStock(
        batchID: UUID,
        fromLocationID: UUID,
        toLocationID: UUID,
        quantity: Int
    ) async throws
}
