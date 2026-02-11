import Foundation

@MainActor
final class ApiClient: ObservableObject {
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    var baseURL: URL

    init(baseURL: URL = URL(string: "http://localhost:4000")!) {
        self.baseURL = baseURL

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
    }

    func fetchCatalog(category: ProductCategory?) async throws -> [Product] {
        var components = URLComponents(
            url: baseURL.appending(path: "/v1/catalog"),
            resolvingAgainstBaseURL: false
        )!
        if let category {
            components.queryItems = [URLQueryItem(name: "category", value: category.rawValue)]
        }

        let request = URLRequest(url: components.url!)
        let response: CatalogResponse = try await send(request)
        return response.products
    }

    func fetchPickupSlots(date: Date) async throws -> [PickupSlot] {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        let dateString = formatter.string(from: date)

        var components = URLComponents(
            url: baseURL.appending(path: "/v1/pickup-slots"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [URLQueryItem(name: "date", value: dateString)]

        let request = URLRequest(url: components.url!)
        let response: PickupSlotsResponse = try await send(request)
        return response.slots
    }

    func createOrder(_ payload: CreateOrderRequest) async throws -> CreateOrderResponse {
        var request = URLRequest(url: baseURL.appending(path: "/v1/orders"))
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(payload)
        return try await send(request)
    }

    func lookupOrder(orderNumber: String, phone: String) async throws -> LookupOrderResponse {
        var components = URLComponents(
            url: baseURL.appending(path: "/v1/orders/lookup"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "orderNumber", value: orderNumber),
            URLQueryItem(name: "phone", value: phone)
        ]
        let request = URLRequest(url: components.url!)
        return try await send(request)
    }

    func adminLogin(email: String, password: String) async throws -> AdminLoginResponse {
        var request = URLRequest(url: baseURL.appending(path: "/v1/admin/auth/login"))
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(AdminLoginRequest(email: email, password: password))
        return try await send(request)
    }

    func fetchAdminProducts(accessToken: String) async throws -> [Product] {
        var request = URLRequest(url: baseURL.appending(path: "/v1/admin/products"))
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let response: AdminProductsResponse = try await send(request)
        return response.products
    }

    func fetchAdminOrders(accessToken: String, status: OrderStatus?) async throws -> [AdminOrder] {
        var components = URLComponents(
            url: baseURL.appending(path: "/v1/admin/orders"),
            resolvingAgainstBaseURL: false
        )!
        if let status {
            components.queryItems = [URLQueryItem(name: "status", value: status.rawValue)]
        }

        var request = URLRequest(url: components.url!)
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let response: AdminOrderListResponse = try await send(request)
        return response.orders
    }

    func updateOrderStatus(accessToken: String, orderId: UUID, status: OrderStatus) async throws {
        struct Payload: Codable {
            let status: String
        }

        var request = URLRequest(url: baseURL.appending(path: "/v1/admin/orders/\(orderId.uuidString)/status"))
        request.httpMethod = "PATCH"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try encoder.encode(Payload(status: status.rawValue))

        let _: AdminOrder = try await send(request)
    }

    func fulfillOrder(accessToken: String, orderId: UUID) async throws -> URL {
        struct Response: Codable {
            let receiptUrl: URL
            let escposPayloadBase64: String
        }

        var request = URLRequest(url: baseURL.appending(path: "/v1/admin/orders/\(orderId.uuidString)/fulfill"))
        request.httpMethod = "POST"
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let response: Response = try await send(request)
        return response.receiptUrl
    }

    private func send<Response: Decodable>(_ request: URLRequest) async throws -> Response {
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw ApiError.invalidResponse
        }

        guard (200..<300).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown API error"
            throw ApiError.serverError(code: http.statusCode, message: message)
        }

        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw ApiError.decodingFailed(error.localizedDescription)
        }
    }
}

enum ApiError: LocalizedError {
    case invalidResponse
    case serverError(code: Int, message: String)
    case decodingFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid server response"
        case let .serverError(code, message):
            return "Server error (\(code)): \(message)"
        case let .decodingFailed(message):
            return "Response decoding failed: \(message)"
        }
    }
}
