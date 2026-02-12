import Foundation

@MainActor
final class DemoDataStore {
    private(set) var products: [Product]
    private var orders: [DemoOrderRecord]
    private var orderSequence: Int

    private let taxRateBps = 825

    init(now: Date = Date()) {
        let calendar = Calendar(identifier: .gregorian)
        let createdAt = calendar.date(byAdding: .day, value: -2, to: now) ?? now

        let seededProducts: [Product] = [
            Product(
                id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
                name: "Halal Lamb Chops",
                description: "Fresh halal-cut lamb chops, ideal for grilling.",
                category: .halalMeat,
                unit: .lb,
                priceCents: 1899,
                stockQuantity: 42,
                imageUrl: Self.demoImageURL(path: "photo-1607623814075-e51df1bdc82f"),
                imageKey: "demo/lamb.jpg",
                active: true,
                createdAt: createdAt,
                updatedAt: createdAt
            ),
            Product(
                id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
                name: "Halal Ground Beef",
                description: "Lean halal ground beef for kofta, burgers, and sauces.",
                category: .halalMeat,
                unit: .lb,
                priceCents: 1299,
                stockQuantity: 60,
                imageUrl: Self.demoImageURL(path: "photo-1625944228740-f4b0f9f7b4cc"),
                imageKey: "demo/beef.jpg",
                active: true,
                createdAt: createdAt,
                updatedAt: createdAt
            ),
            Product(
                id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
                name: "Medjool Dates",
                description: "Premium soft Medjool dates.",
                category: .groceryOther,
                unit: .each,
                priceCents: 799,
                stockQuantity: 120,
                imageUrl: Self.demoImageURL(path: "photo-1603048297172-c92544798d5a"),
                imageKey: "demo/dates.jpg",
                active: true,
                createdAt: createdAt,
                updatedAt: createdAt
            ),
            Product(
                id: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
                name: "Roma Tomatoes",
                description: "Fresh produce delivered daily.",
                category: .vegetables,
                unit: .lb,
                priceCents: 249,
                stockQuantity: 85,
                imageUrl: Self.demoImageURL(path: "photo-1592924357228-91a4daadcfea"),
                imageKey: "demo/tomatoes.jpg",
                active: true,
                createdAt: createdAt,
                updatedAt: createdAt
            ),
            Product(
                id: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!,
                name: "Honeycrisp Apples",
                description: "Sweet and crisp apples, sold by weight.",
                category: .fruits,
                unit: .lb,
                priceCents: 399,
                stockQuantity: 110,
                imageUrl: Self.demoImageURL(path: "photo-1568702846914-96b305d2aaeb"),
                imageKey: "demo/apples.jpg",
                active: true,
                createdAt: createdAt,
                updatedAt: createdAt
            )
        ]

        self.products = seededProducts.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        self.orderSequence = 42

        let seededOrderStart = calendar.date(byAdding: .hour, value: 2, to: now) ?? now
        let seededOrderEnd = calendar.date(byAdding: .minute, value: 30, to: seededOrderStart) ?? seededOrderStart

        self.orders = [
            DemoOrderRecord(
                id: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!,
                orderNumber: "OM-\(Self.dayStamp(from: now))-0041",
                customerName: "Sample Customer",
                customerPhone: "+15551234567",
                pickupSlotStartIso: Self.iso(seededOrderStart),
                pickupSlotEndIso: Self.iso(seededOrderEnd),
                status: .preparing,
                paymentStatus: .paidEstimated,
                estimatedSubtotalCents: 3898,
                estimatedTaxCents: 322,
                estimatedTotalCents: 4220,
                finalSubtotalCents: nil,
                finalTaxCents: nil,
                finalTotalCents: nil,
                refundedCents: 0,
                receiptURL: nil,
                createdAt: now
            )
        ]
    }

    func catalog(category: ProductCategory?) -> [Product] {
        let visible = products.filter { $0.active && $0.stockQuantity > 0 }
        guard let category else { return visible }
        return visible.filter { $0.category == category }
    }

    func pickupSlots(for date: Date) -> [PickupSlot] {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        let open = calendar.date(byAdding: .hour, value: 9, to: dayStart) ?? date
        let close = calendar.date(byAdding: .hour, value: 20, to: dayStart) ?? date

        let now = Date()
        let leadCutoff = now.addingTimeInterval(60 * 60)

        var slots: [PickupSlot] = []
        var cursor = open

        while cursor < close {
            let next = cursor.addingTimeInterval(30 * 60)
            if cursor >= leadCutoff {
                let startIso = Self.iso(cursor)
                let endIso = Self.iso(next)
                let bookedCount = orders.filter {
                    $0.pickupSlotStartIso == startIso &&
                        $0.status != .cancelled &&
                        $0.status != .refunded
                }.count
                let capacity = 20
                slots.append(
                    PickupSlot(
                        startIso: startIso,
                        endIso: endIso,
                        capacity: capacity,
                        available: max(0, capacity - bookedCount)
                    )
                )
            }
            cursor = next
        }

        return slots
    }

    func createOrder(payload: CreateOrderRequest) throws -> CreateOrderResponse {
        guard !payload.customerName.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw DemoStoreError.invalidRequest("Full name is required")
        }

        let start = Self.parseISO(payload.pickupSlotStartIso)
        let end = (start ?? Date()).addingTimeInterval(30 * 60)

        var subtotal = 0

        for item in payload.items {
            guard let productIndex = products.firstIndex(where: { $0.id == item.productId }) else {
                throw DemoStoreError.invalidRequest("Product not found")
            }

            var product = products[productIndex]
            let quantity = product.unit == .lb ? (item.estimatedWeightLb ?? item.quantity) : item.quantity
            if quantity <= 0 {
                throw DemoStoreError.invalidRequest("Quantity must be greater than zero")
            }

            if product.stockQuantity < quantity {
                throw DemoStoreError.conflict("Insufficient stock for \(product.name)")
            }

            product = Product(
                id: product.id,
                name: product.name,
                description: product.description,
                category: product.category,
                unit: product.unit,
                priceCents: product.priceCents,
                stockQuantity: max(0, product.stockQuantity - quantity),
                imageUrl: product.imageUrl,
                imageKey: product.imageKey,
                active: product.active,
                createdAt: product.createdAt,
                updatedAt: Date()
            )

            products[productIndex] = product
            subtotal += Int((Double(product.priceCents) * quantity).rounded())
        }

        let tax = Int((Double(subtotal) * Double(taxRateBps) / 10000.0).rounded())
        let total = subtotal + tax

        orderSequence += 1
        let orderNumber = "OM-\(Self.dayStamp(from: Date()))-\(String(orderSequence).paddedLeft(to: 4))"
        let normalizedPhone = Self.normalizePhone(payload.customerPhone)

        let record = DemoOrderRecord(
            id: UUID(),
            orderNumber: orderNumber,
            customerName: payload.customerName,
            customerPhone: normalizedPhone,
            pickupSlotStartIso: payload.pickupSlotStartIso,
            pickupSlotEndIso: Self.iso(end),
            status: .placed,
            paymentStatus: .paidEstimated,
            estimatedSubtotalCents: subtotal,
            estimatedTaxCents: tax,
            estimatedTotalCents: total,
            finalSubtotalCents: nil,
            finalTaxCents: nil,
            finalTotalCents: nil,
            refundedCents: 0,
            receiptURL: nil,
            createdAt: Date()
        )

        orders.insert(record, at: 0)

        return CreateOrderResponse(
            orderId: record.id,
            orderNumber: record.orderNumber,
            paymentClientSecret: "demo_client_secret_\(record.id.uuidString.replacingOccurrences(of: "-", with: ""))",
            estimatedTotalCents: record.estimatedTotalCents,
            status: record.status
        )
    }

    func lookup(orderNumber: String, phone: String) throws -> LookupOrderResponse {
        let normalizedPhone = Self.normalizePhone(phone)
        guard let order = orders.first(where: {
            $0.orderNumber.caseInsensitiveCompare(orderNumber) == .orderedSame &&
                Self.normalizePhone($0.customerPhone) == normalizedPhone
        }) else {
            throw DemoStoreError.notFound("Order not found")
        }

        return order.lookupResponse
    }

    func adminLogin(email: String, password: String) throws -> AdminLoginResponse {
        let validEmail = "admin@oasis.local"
        let validPassword = "OasisAdmin123!"

        if email.caseInsensitiveCompare(validEmail) == .orderedSame && password == validPassword {
            return AdminLoginResponse(
                accessToken: "demo_access_token",
                refreshToken: "demo_refresh_token",
                role: "superadmin"
            )
        }

        throw DemoStoreError.unauthorized("Use admin@oasis.local / OasisAdmin123!")
    }

    func adminProducts() -> [Product] {
        products.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func updateStock(productId: UUID, stockQuantity: Double) throws -> Product {
        guard let index = products.firstIndex(where: { $0.id == productId }) else {
            throw DemoStoreError.notFound("Product not found")
        }

        let current = products[index]
        let updated = Product(
            id: current.id,
            name: current.name,
            description: current.description,
            category: current.category,
            unit: current.unit,
            priceCents: current.priceCents,
            stockQuantity: max(0, stockQuantity),
            imageUrl: current.imageUrl,
            imageKey: current.imageKey,
            active: current.active,
            createdAt: current.createdAt,
            updatedAt: Date()
        )

        products[index] = updated
        return updated
    }

    func adminOrders(status: OrderStatus?) -> [AdminOrder] {
        let list = status == nil ? orders : orders.filter { $0.status == status }
        return list.sorted { $0.createdAt > $1.createdAt }.map { $0.adminOrder }
    }

    func updateOrderStatus(orderId: UUID, status: OrderStatus) throws -> AdminOrder {
        guard let index = orders.firstIndex(where: { $0.id == orderId }) else {
            throw DemoStoreError.notFound("Order not found")
        }

        orders[index].status = status
        if status == .refunded {
            orders[index].paymentStatus = .fullyRefunded
        }
        return orders[index].adminOrder
    }

    func fulfill(orderId: UUID) throws -> FulfillOrderResponse {
        guard let index = orders.firstIndex(where: { $0.id == orderId }) else {
            throw DemoStoreError.notFound("Order not found")
        }

        orders[index].status = .fulfilled

        if orders[index].finalTotalCents == nil {
            orders[index].finalSubtotalCents = orders[index].estimatedSubtotalCents
            orders[index].finalTaxCents = orders[index].estimatedTaxCents
            orders[index].finalTotalCents = orders[index].estimatedTotalCents
        }

        let receiptURL = URL(string: "https://example.com/oasis/receipts/\(orders[index].orderNumber).pdf")!
        orders[index].receiptURL = receiptURL

        let escpos = Data("ORDER \(orders[index].orderNumber)\n\(orders[index].customerName)".utf8)
            .base64EncodedString()

        return FulfillOrderResponse(receiptUrl: receiptURL, escposPayloadBase64: escpos)
    }

    func refund(orderId: UUID, amountCents: Int, reason: String) throws {
        guard let index = orders.firstIndex(where: { $0.id == orderId }) else {
            throw DemoStoreError.notFound("Order not found")
        }

        guard amountCents > 0 else {
            throw DemoStoreError.invalidRequest("Refund must be greater than zero")
        }

        let total = orders[index].finalTotalCents ?? orders[index].estimatedTotalCents
        let refundable = max(0, total - orders[index].refundedCents)
        guard refundable > 0 else {
            throw DemoStoreError.conflict("No refundable amount remaining")
        }

        let actualRefund = min(amountCents, refundable)
        _ = reason
        orders[index].refundedCents += actualRefund

        if orders[index].refundedCents >= total {
            orders[index].paymentStatus = .fullyRefunded
            orders[index].status = .refunded
        } else {
            orders[index].paymentStatus = .partiallyRefunded
        }
    }

    private static func normalizePhone(_ value: String) -> String {
        value.filter { $0.isNumber || $0 == "+" }
    }

    private static func iso(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }

    private static func parseISO(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: value)
    }

    private static func dayStamp(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyyMMdd"
        return formatter.string(from: date)
    }

    private static func demoImageURL(path: String) -> URL {
        URL(
            string: "https://images.unsplash.com/\(path)?auto=format&fit=crop&w=720&q=70"
        )!
    }
}

private struct DemoOrderRecord {
    let id: UUID
    let orderNumber: String
    let customerName: String
    let customerPhone: String
    let pickupSlotStartIso: String
    let pickupSlotEndIso: String
    var status: OrderStatus
    var paymentStatus: PaymentStatus
    let estimatedSubtotalCents: Int
    let estimatedTaxCents: Int
    let estimatedTotalCents: Int
    var finalSubtotalCents: Int?
    var finalTaxCents: Int?
    var finalTotalCents: Int?
    var refundedCents: Int
    var receiptURL: URL?
    let createdAt: Date

    var lookupResponse: LookupOrderResponse {
        LookupOrderResponse(
            id: id,
            orderNumber: orderNumber,
            customerName: customerName,
            customerPhone: customerPhone,
            pickupSlotStartIso: pickupSlotStartIso,
            pickupSlotEndIso: pickupSlotEndIso,
            status: status,
            paymentStatus: paymentStatus,
            estimatedSubtotalCents: estimatedSubtotalCents,
            estimatedTaxCents: estimatedTaxCents,
            estimatedTotalCents: estimatedTotalCents,
            finalSubtotalCents: finalSubtotalCents,
            finalTaxCents: finalTaxCents,
            finalTotalCents: finalTotalCents,
            receiptUrl: receiptURL
        )
    }

    var adminOrder: AdminOrder {
        AdminOrder(
            id: id,
            orderNumber: orderNumber,
            customerName: customerName,
            customerPhone: customerPhone,
            pickupSlotStartIso: pickupSlotStartIso,
            pickupSlotEndIso: pickupSlotEndIso,
            status: status,
            paymentStatus: paymentStatus,
            estimatedSubtotalCents: estimatedSubtotalCents,
            estimatedTaxCents: estimatedTaxCents,
            estimatedTotalCents: estimatedTotalCents,
            finalSubtotalCents: finalSubtotalCents,
            finalTaxCents: finalTaxCents,
            finalTotalCents: finalTotalCents
        )
    }
}

enum DemoStoreError: LocalizedError {
    case notFound(String)
    case invalidRequest(String)
    case conflict(String)
    case unauthorized(String)

    var errorDescription: String? {
        switch self {
        case let .notFound(message),
            let .invalidRequest(message),
            let .conflict(message),
            let .unauthorized(message):
            return message
        }
    }

    var statusCode: Int {
        switch self {
        case .notFound:
            return 404
        case .invalidRequest:
            return 400
        case .conflict:
            return 409
        case .unauthorized:
            return 401
        }
    }
}

private extension String {
    func paddedLeft(to length: Int) -> String {
        if count >= length { return self }
        return String(repeating: "0", count: length - count) + self
    }
}
