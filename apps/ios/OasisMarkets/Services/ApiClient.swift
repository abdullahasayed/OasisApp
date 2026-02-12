import Foundation

@MainActor
final class ApiClient: ObservableObject {
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    @Published private(set) var isDemoMode: Bool

    var baseURL: URL
    private let demoStore = DemoDataStore()

    init(baseURL: URL = URL(string: "http://localhost:4000")!, forceDemoMode: Bool? = nil) {
        self.baseURL = baseURL

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        if let forceDemoMode {
            self.isDemoMode = forceDemoMode
        } else if let envFlag = ProcessInfo.processInfo.environment["OASIS_DEMO_MODE"] {
            self.isDemoMode = ["1", "true", "yes"].contains(envFlag.lowercased())
        } else {
#if DEBUG
            self.isDemoMode = true
#else
            self.isDemoMode = false
#endif
        }
    }

    func setDemoMode(_ enabled: Bool) {
        isDemoMode = enabled
    }

    func fetchCatalog(category: ProductCategory?) async throws -> [Product] {
        if isDemoMode {
            return try await runDemo {
                demoStore.catalog(category: category)
            }
        }

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
        if isDemoMode {
            return try await runDemo {
                demoStore.pickupSlots(for: date)
            }
        }

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
        if isDemoMode {
            return try await runDemo {
                try demoStore.createOrder(payload: payload)
            }
        }

        var request = URLRequest(url: baseURL.appending(path: "/v1/orders"))
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(payload)
        return try await send(request)
    }

    func lookupOrder(orderNumber: String, phone: String) async throws -> LookupOrderResponse {
        if isDemoMode {
            return try await runDemo {
                try demoStore.lookup(orderNumber: orderNumber, phone: phone)
            }
        }

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
        if isDemoMode {
            return try await runDemo {
                try demoStore.adminLogin(email: email, password: password)
            }
        }

        var request = URLRequest(url: baseURL.appending(path: "/v1/admin/auth/login"))
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(AdminLoginRequest(email: email, password: password))
        return try await send(request)
    }

    func fetchAdminProducts(accessToken: String) async throws -> [Product] {
        if isDemoMode {
            return try await runDemo {
                _ = accessToken
                return demoStore.adminProducts()
            }
        }

        var request = URLRequest(url: baseURL.appending(path: "/v1/admin/products"))
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let response: AdminProductsResponse = try await send(request)
        return response.products
    }

    func updateProductStock(
        accessToken: String,
        productId: UUID,
        stockQuantity: Double
    ) async throws -> Product {
        if isDemoMode {
            return try await runDemo {
                _ = accessToken
                return try demoStore.updateStock(productId: productId, stockQuantity: stockQuantity)
            }
        }

        struct Payload: Codable {
            let stockQuantity: Double
        }

        var request = URLRequest(
            url: baseURL.appending(path: "/v1/admin/products/\(productId.uuidString)/stock")
        )
        request.httpMethod = "PATCH"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try encoder.encode(Payload(stockQuantity: stockQuantity))
        return try await send(request)
    }

    func fetchAdminOrders(accessToken: String, status: OrderStatus?) async throws -> [AdminOrder] {
        if isDemoMode {
            return try await runDemo {
                _ = accessToken
                return demoStore.adminOrders(status: status)
            }
        }

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
        if isDemoMode {
            _ = try await runDemo {
                _ = accessToken
                return try demoStore.updateOrderStatus(orderId: orderId, status: status)
            }
            return
        }

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

    func fulfillOrder(accessToken: String, orderId: UUID) async throws -> FulfillOrderResponse {
        if isDemoMode {
            return try await runDemo {
                _ = accessToken
                return try demoStore.fulfill(orderId: orderId)
            }
        }

        var request = URLRequest(url: baseURL.appending(path: "/v1/admin/orders/\(orderId.uuidString)/fulfill"))
        request.httpMethod = "POST"
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        return try await send(request)
    }

    func refundOrder(
        accessToken: String,
        orderId: UUID,
        amountCents: Int,
        reason: String
    ) async throws {
        if isDemoMode {
            _ = try await runDemo {
                _ = accessToken
                try demoStore.refund(orderId: orderId, amountCents: amountCents, reason: reason)
                return EmptyResponse()
            }
            return
        }

        struct Payload: Codable {
            let amountCents: Int
            let reason: String
        }

        var request = URLRequest(
            url: baseURL.appending(path: "/v1/admin/orders/\(orderId.uuidString)/refund")
        )
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try encoder.encode(Payload(amountCents: amountCents, reason: reason))

        let _: EmptyResponse = try await send(request)
    }

    private func runDemo<T>(_ work: () throws -> T) async throws -> T {
        try await Task.sleep(for: .milliseconds(120))
        do {
            return try work()
        } catch let error as DemoStoreError {
            throw ApiError.serverError(code: error.statusCode, message: error.localizedDescription)
        }
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

struct FulfillOrderResponse: Codable {
    let receiptUrl: URL
    let escposPayloadBase64: String
}

private struct EmptyResponse: Codable {}
