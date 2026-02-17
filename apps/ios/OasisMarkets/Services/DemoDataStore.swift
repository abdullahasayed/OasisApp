import Foundation

@MainActor
final class DemoDataStore {
    private struct PickupRange {
        var openHour: Int
        var closeHour: Int
    }

    private struct SlotSnapshot {
        let startIso: String
        let endIso: String
        let booked: Int
        let capacity: Int
        let available: Int
        let isUnavailable: Bool
    }

    private(set) var products: [Product]
    private var orders: [DemoOrderRecord]
    private var orderSequence: Int
    private var dayRanges: [String: PickupRange]
    private var unavailableSlots: Set<String>
    private var searchKeywordsByProductID: [UUID: [String]]

    private let taxRateBps = 825
    private let slotCapacity = 20
    private let slotDurationHours = 1
    private let leadTimeSeconds: TimeInterval = 60 * 60

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
        self.searchKeywordsByProductID = [
            UUID(uuidString: "11111111-1111-1111-1111-111111111111")!: ["lamb", "halal", "chops", "grill"],
            UUID(uuidString: "22222222-2222-2222-2222-222222222222")!: ["beef", "ground", "halal", "kofta"],
            UUID(uuidString: "33333333-3333-3333-3333-333333333333")!: ["dates", "medjool", "snack", "ramadan"],
            UUID(uuidString: "44444444-4444-4444-4444-444444444444")!: ["tomatoes", "roma", "produce", "fresh"],
            UUID(uuidString: "55555555-5555-5555-5555-555555555555")!: ["apples", "honeycrisp", "fruit", "sweet"]
        ]
        self.orderSequence = 42

        let seededOrderStart = calendar.date(byAdding: .hour, value: 2, to: now) ?? now
        let seededOrderEnd = calendar.date(byAdding: .hour, value: 1, to: seededOrderStart) ?? seededOrderStart

        self.orders = [
            DemoOrderRecord(
                id: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!,
                orderNumber: "OM-\(Self.dayStamp(from: now))-0041",
                customerName: "Sample Customer",
                customerPhone: "+15551234567",
                pickupSlotStartIso: Self.iso(seededOrderStart),
                pickupSlotEndIso: Self.iso(seededOrderEnd),
                requestedPickupSlotStartIso: Self.iso(seededOrderStart),
                requestedPickupSlotEndIso: Self.iso(seededOrderEnd),
                estimatedPickupStartIso: Self.iso(seededOrderStart),
                estimatedPickupEndIso: Self.iso(seededOrderEnd),
                totalDelayMinutes: 0,
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

        self.dayRanges = [:]
        self.unavailableSlots = []
    }

    func catalog(
        category: ProductCategory?,
        query: String? = nil,
        limit: Int = 100
    ) -> [Product] {
        let maxResults = max(1, min(200, limit))
        let visible = products.filter { $0.active && $0.stockQuantity > 0 }
        let normalizedQuery = (query ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        if normalizedQuery.isEmpty {
            let filtered = category == nil
                ? visible
                : visible.filter { $0.category == category }
            return Array(filtered.prefix(maxResults))
        }

        let ranked = visible
            .compactMap { product -> (product: Product, score: Double)? in
                let keywords = searchKeywordsByProductID[product.id] ?? []
                let score = searchScore(
                    query: normalizedQuery,
                    productName: product.name,
                    description: product.description,
                    keywords: keywords
                )
                return score > 0 ? (product, score) : nil
            }
            .sorted { lhs, rhs in
                if abs(lhs.score - rhs.score) > 0.0001 {
                    return lhs.score > rhs.score
                }
                return lhs.product.name.localizedCaseInsensitiveCompare(rhs.product.name) == .orderedAscending
            }
            .map(\.product)

        return Array(ranked.prefix(maxResults))
    }

    func pickupSlots(for date: Date) -> [PickupSlot] {
        let dateKey = Self.dayKey(from: date)
        let range = rangeFor(dateKey: dateKey)

        return buildSlotSnapshots(
            dateKey: dateKey,
            openHour: range.openHour,
            closeHour: range.closeHour,
            applyLeadTime: true
        ).map {
            PickupSlot(
                startIso: $0.startIso,
                endIso: $0.endIso,
                capacity: $0.capacity,
                available: $0.available
            )
        }
    }

    func createOrder(payload: CreateOrderRequest) throws -> CreateOrderResponse {
        guard !payload.customerName.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw DemoStoreError.invalidRequest("Full name is required")
        }

        guard let slotStart = Self.parseISO(payload.pickupSlotStartIso) else {
            throw DemoStoreError.invalidRequest("Invalid pickup slot")
        }

        let slotDateKey = Self.dayKey(from: slotStart)
        let range = rangeFor(dateKey: slotDateKey)
        let selectableSlots = buildSlotSnapshots(
            dateKey: slotDateKey,
            openHour: range.openHour,
            closeHour: range.closeHour,
            applyLeadTime: true
        )

        guard let selectedSlot = selectableSlots.first(where: { $0.startIso == payload.pickupSlotStartIso }) else {
            throw DemoStoreError.invalidRequest("Invalid pickup slot")
        }

        guard selectedSlot.available > 0 else {
            throw DemoStoreError.conflict("Pickup slot is full")
        }

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
            pickupSlotStartIso: selectedSlot.startIso,
            pickupSlotEndIso: selectedSlot.endIso,
            requestedPickupSlotStartIso: selectedSlot.startIso,
            requestedPickupSlotEndIso: selectedSlot.endIso,
            estimatedPickupStartIso: selectedSlot.startIso,
            estimatedPickupEndIso: selectedSlot.endIso,
            totalDelayMinutes: 0,
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

    func delayOrder(orderId: UUID, delayMinutes: Int) throws -> AdminOrder {
        guard [10, 30, 60, 90].contains(delayMinutes) else {
            throw DemoStoreError.invalidRequest("Delay minutes must be 10, 30, 60, or 90")
        }

        guard let index = orders.firstIndex(where: { $0.id == orderId }) else {
            throw DemoStoreError.notFound("Order not found")
        }

        if orders[index].status == .cancelled || orders[index].status == .refunded {
            throw DemoStoreError.conflict("Order cannot be delayed")
        }

        orders[index].status = .delayed
        orders[index].totalDelayMinutes += delayMinutes

        let slotShiftHours: Int
        if delayMinutes == 60 {
            slotShiftHours = 1
        } else if delayMinutes == 90 {
            slotShiftHours = 2
        } else {
            slotShiftHours = 0
        }

        if slotShiftHours > 0,
           let currentStart = Self.parseISO(orders[index].pickupSlotStartIso),
           let currentEnd = Self.parseISO(orders[index].pickupSlotEndIso) {
            orders[index].pickupSlotStartIso = Self.iso(currentStart.addingTimeInterval(TimeInterval(slotShiftHours * 3600)))
            orders[index].pickupSlotEndIso = Self.iso(currentEnd.addingTimeInterval(TimeInterval(slotShiftHours * 3600)))
        }

        if let requestedStart = Self.parseISO(orders[index].requestedPickupSlotStartIso) {
            let estimatedStart = requestedStart.addingTimeInterval(TimeInterval(orders[index].totalDelayMinutes * 60))
            let estimatedEnd = estimatedStart.addingTimeInterval(TimeInterval(slotDurationHours * 3600))
            orders[index].estimatedPickupStartIso = Self.iso(estimatedStart)
            orders[index].estimatedPickupEndIso = Self.iso(estimatedEnd)
        }

        return orders[index].adminOrder
    }

    func adminPickupAvailability() -> [AdminPickupDay] {
        allowedDateKeys().map { dateKey in
            let range = rangeFor(dateKey: dateKey)
            let slots = buildSlotSnapshots(
                dateKey: dateKey,
                openHour: range.openHour,
                closeHour: range.closeHour,
                applyLeadTime: false
            )

            return AdminPickupDay(
                date: dateKey,
                openHour: range.openHour,
                closeHour: range.closeHour,
                slots: slots.map {
                    AdminPickupSlot(
                        startIso: $0.startIso,
                        endIso: $0.endIso,
                        capacity: $0.capacity,
                        booked: $0.booked,
                        available: $0.available,
                        isUnavailable: $0.isUnavailable
                    )
                }
            )
        }
    }

    func updatePickupRange(date: String, openHour: Int, closeHour: Int) throws {
        guard allowedDateKeys().contains(date) else {
            throw DemoStoreError.invalidRequest("Date must be today or tomorrow")
        }
        guard openHour >= 0, closeHour <= 24, closeHour > openHour else {
            throw DemoStoreError.invalidRequest("Invalid pickup range")
        }

        dayRanges[date] = PickupRange(openHour: openHour, closeHour: closeHour)
    }

    func toggleSlotUnavailable(slotStartIso: String, unavailable: Bool) throws {
        guard let slotStart = Self.parseISO(slotStartIso) else {
            throw DemoStoreError.invalidRequest("Invalid slot")
        }

        let dateKey = Self.dayKey(from: slotStart)
        guard allowedDateKeys().contains(dateKey) else {
            throw DemoStoreError.invalidRequest("Slot must be for today or tomorrow")
        }

        if unavailable {
            unavailableSlots.insert(slotStartIso)
        } else {
            unavailableSlots.remove(slotStartIso)
        }
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

    private func allowedDateKeys() -> [String] {
        let today = Self.dayKey(from: Date())
        let tomorrow = Self.dayKey(from: Date().addingTimeInterval(24 * 60 * 60))
        return [today, tomorrow]
    }

    private func rangeFor(dateKey: String) -> PickupRange {
        dayRanges[dateKey] ?? PickupRange(openHour: 9, closeHour: 20)
    }

    private func buildSlotSnapshots(
        dateKey: String,
        openHour: Int,
        closeHour: Int,
        applyLeadTime: Bool
    ) -> [SlotSnapshot] {
        guard let dayStart = Self.dateFromKey(dateKey) else {
            return []
        }

        let open = dayStart.addingTimeInterval(TimeInterval(openHour * 3600))
        let close = dayStart.addingTimeInterval(TimeInterval(closeHour * 3600))
        let leadCutoff = Date().addingTimeInterval(leadTimeSeconds)

        var snapshots: [SlotSnapshot] = []
        var cursor = open

        while cursor < close {
            let next = cursor.addingTimeInterval(TimeInterval(slotDurationHours * 3600))
            if !applyLeadTime || cursor >= leadCutoff {
                let startIso = Self.iso(cursor)
                let endIso = Self.iso(next)
                let bookedCount = orders.filter {
                    $0.pickupSlotStartIso == startIso &&
                        $0.status != .cancelled &&
                        $0.status != .refunded
                }.count
                let isUnavailable = unavailableSlots.contains(startIso)
                let available = isUnavailable ? 0 : max(0, slotCapacity - bookedCount)

                snapshots.append(
                    SlotSnapshot(
                        startIso: startIso,
                        endIso: endIso,
                        booked: bookedCount,
                        capacity: slotCapacity,
                        available: available,
                        isUnavailable: isUnavailable
                    )
                )
            }
            cursor = next
        }

        return snapshots
    }

    private static func normalizePhone(_ value: String) -> String {
        value.filter { $0.isNumber || $0 == "+" }
    }

    private func searchScore(
        query: String,
        productName: String,
        description: String,
        keywords: [String]
    ) -> Double {
        let normalizedName = productName.lowercased()
        let normalizedDescription = description.lowercased()
        let normalizedKeywords = keywords.map { $0.lowercased() }
        let keywordsText = normalizedKeywords.joined(separator: " ")
        let queryTokens = query
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
            .filter { !$0.isEmpty }

        var score = 0.0
        if normalizedName == query {
            score += 14
        }
        if normalizedName.contains(query) {
            score += 7
        }
        if keywordsText.contains(query) {
            score += 9
        }
        if normalizedDescription.contains(query) {
            score += 3
        }

        for token in queryTokens {
            if normalizedName.hasPrefix(token) {
                score += 3
            } else if normalizedName.contains(token) {
                score += 1.6
            }

            if keywordsText.contains(token) {
                score += 2.8
            }

            if normalizedDescription.contains(token) {
                score += 0.9
            }
        }

        score += trigramSimilarity(query, normalizedName) * 4.0
        score += trigramSimilarity(query, keywordsText) * 4.5
        score += trigramSimilarity(query, normalizedDescription) * 1.5

        return score
    }

    private func trigramSimilarity(_ left: String, _ right: String) -> Double {
        let leftTrigrams = trigrams(for: left)
        let rightTrigrams = trigrams(for: right)
        if leftTrigrams.isEmpty || rightTrigrams.isEmpty {
            return 0
        }

        let intersection = leftTrigrams.intersection(rightTrigrams).count
        let union = leftTrigrams.union(rightTrigrams).count
        if union == 0 {
            return 0
        }

        return Double(intersection) / Double(union)
    }

    private func trigrams(for value: String) -> Set<String> {
        let normalized = value
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.isEmpty {
            return []
        }

        let padded = "  \(normalized)  "
        guard padded.count >= 3 else {
            return [padded]
        }

        let chars = Array(padded)
        var results = Set<String>()
        for index in 0..<(chars.count - 2) {
            let trigram = String(chars[index...index + 2])
            results.insert(trigram)
        }
        return results
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

    private static func dayKey(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func dateFromKey(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)
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
    var pickupSlotStartIso: String
    var pickupSlotEndIso: String
    let requestedPickupSlotStartIso: String
    let requestedPickupSlotEndIso: String
    var estimatedPickupStartIso: String
    var estimatedPickupEndIso: String
    var totalDelayMinutes: Int
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
            estimatedPickupStartIso: estimatedPickupStartIso,
            estimatedPickupEndIso: estimatedPickupEndIso,
            totalDelayMinutes: totalDelayMinutes,
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
            estimatedPickupStartIso: estimatedPickupStartIso,
            estimatedPickupEndIso: estimatedPickupEndIso,
            totalDelayMinutes: totalDelayMinutes,
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
