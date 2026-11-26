
import Foundation
import Combine

struct LoginResponse: Decodable {
    let token: String?
    let accessToken: String?
    var accessTokenValue: String { token ?? accessToken ?? "" }
}

struct AnalyticsResponse: Decodable {
    let totalProducts: Int
    let totalBatches: Int
    let totalQuantity: Int
    let expiredPositions: Int
    let expiringWithinSevenDays: Int
    let activeLocations: Int
    let recentMovements: Int
}

struct FEFOItem: Decodable, Identifiable {
    let batchID: UUID
    let batchNumber: String
    let productID: UUID
    let productName: String
    let sku: String
    let storageLocationID: UUID
    let quantity: Int
    let expiresAt: Date
    let daysUntilExpiration: Int
    let isExpired: Bool

    var id: String {
        "\(batchID.uuidString)-\(storageLocationID.uuidString)"
    }
}

struct FEFOResponse: Decodable {
    let generatedAt: Date
    let totalPositions: Int
    let totalQuantity: Int
    let expiredPositions: Int
    let expiringWithinSevenDays: Int
    let items: [FEFOItem]
}

struct LocationItem: Decodable, Identifiable {
    let id: UUID
    let code: String
    let zone: String
    let details: String
}

struct StockMovementItem: Decodable, Identifiable {
    let id: UUID
    let batchID: UUID
    let userID: UUID?
    let userEmail: String?
    let fromLocationID: UUID?
    let toLocationID: UUID?
    let quantity: Int
    let operationType: String
    let createdAt: Date
}

enum APIError: LocalizedError {
    case invalidResponse
    case server(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Не удалось прочитать ответ сервера."
        case .server(let message):
            return message
        }
    }
}

@MainActor
final class APIService: ObservableObject {
    @Published var token: String?
    @Published var analytics: AnalyticsResponse?
    @Published var fefo: FEFOResponse?
    @Published var locations: [LocationItem] = []
    @Published var movements: [StockMovementItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var business: BusinessAnalyticsResponse?

    private let baseURL = URL(string: "http://127.0.0.1:8080/api")!

    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    func login(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let url = baseURL.appendingPathComponent("auth/login")
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: [
                "email": email,
                "password": password
            ])

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let http = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            guard (200..<300).contains(http.statusCode) else {
                throw APIError.server(
                    (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["reason"] as? String
                    ?? "Ошибка входа: HTTP \(http.statusCode)"
                )
            }

            let result = try decoder.decode(LoginResponse.self, from: data)

            guard !result.accessTokenValue.isEmpty else {
                throw APIError.server("Сервер не вернул токен авторизации.")
            }

            token = result.accessTokenValue
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refresh() async {
        guard let token else { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            async let analyticsRequest: AnalyticsResponse =
                get("analytics", token: token)
            async let fefoRequest: FEFOResponse =
                get("fefo", token: token)
            async let locationsRequest: [LocationItem] =
                get("storage-locations", token: token)
            async let movementsRequest: [StockMovementItem] =
                get("stock-movements", token: token)
            async let businessRequest: BusinessAnalyticsResponse =
                get("analytics/business", token: token)

            let (newAnalytics, newFEFO, newLocations, newMovements, newBusiness) =
                try await (
                    analyticsRequest,
                    fefoRequest,
                    locationsRequest,
                    movementsRequest,
                    businessRequest
                )

            analytics = newAnalytics
            fefo = newFEFO
            locations = newLocations
            movements = newMovements
            business = newBusiness
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func moveStock(
        batchID: UUID,
        fromLocationID: UUID,
        toLocationID: UUID,
        quantity: Int
    ) async throws {
        guard let token else {
            throw APIError.server("Сначала войдите в систему.")
        }

        guard quantity > 0 else {
            throw APIError.server("Количество должно быть больше нуля.")
        }

        guard fromLocationID != toLocationID else {
            throw APIError.server("Выберите разные ячейки.")
        }

        let url = baseURL.appendingPathComponent("stock-movements")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "batchID": batchID.uuidString,
            "fromLocationID": fromLocationID.uuidString,
            "toLocationID": toLocationID.uuidString,
            "quantity": quantity
        ])

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200..<300).contains(http.statusCode) else {
            let message =
                (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["reason"] as? String
                ?? "Не удалось переместить товар: HTTP \(http.statusCode)"
            throw APIError.server(message)
        }

        await refresh()
    }

    private func get<T: Decodable>(
        _ path: String,
        token: String
    ) async throws -> T {
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.setValue(
            "Bearer \(token)",
            forHTTPHeaderField: "Authorization"
        )

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200..<300).contains(http.statusCode) else {
            throw APIError.server(
                "Ошибка API \(path): HTTP \(http.statusCode)"
            )
        }

        return try decoder.decode(T.self, from: data)
    }
}
