import Foundation

enum ProductCategory: String, Codable, CaseIterable, Identifiable {
    case halalMeat = "halal_meat"
    case fruits
    case vegetables
    case groceryOther = "grocery_other"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .halalMeat:
            return "Halal Meat"
        case .fruits:
            return "Fruits"
        case .vegetables:
            return "Vegetables"
        case .groceryOther:
            return "Other Groceries"
        }
    }
}

enum ProductUnit: String, Codable {
    case each
    case lb

    var displayName: String {
        switch self {
        case .each:
            return "each"
        case .lb:
            return "lb"
        }
    }
}

enum OrderStatus: String, Codable, CaseIterable {
    case placed
    case preparing
    case ready
    case fulfilled
    case delayed
    case cancelled
    case refunded

    var displayName: String {
        rawValue.capitalized
    }
}

enum PaymentStatus: String, Codable {
    case pending
    case paidEstimated = "paid_estimated"
    case partiallyRefunded = "partially_refunded"
    case fullyRefunded = "fully_refunded"
}

struct Product: Codable, Identifiable {
    let id: UUID
    let name: String
    let description: String
    let category: ProductCategory
    let unit: ProductUnit
    let priceCents: Int
    let stockQuantity: Double
    let imageUrl: URL
    let imageKey: String
    let active: Bool
    let createdAt: Date
    let updatedAt: Date

    var priceLabel: String {
        let value = Double(priceCents) / 100.0
        if unit == .lb {
            return String(format: "$%.2f/lb", value)
        }
        return String(format: "$%.2f", value)
    }
}

struct CatalogResponse: Codable {
    let products: [Product]
}

struct PickupSlot: Codable, Identifiable {
    var id: String { startIso }
    let startIso: String
    let endIso: String
    let capacity: Int
    let available: Int

    var displayLabel: String {
        OasisDateText.pickupWindow(startISO: startIso, endISO: endIso)
    }

    var hourRangeLabel: String {
        OasisDateText.hourRange(startISO: startIso, endISO: endIso)
    }

    var dayKey: String {
        OasisDateText.dayKey(startISO: startIso)
    }
}

struct PickupSlotsResponse: Codable {
    let slots: [PickupSlot]
}

struct CreateOrderItemRequest: Codable {
    let productId: UUID
    let quantity: Double
    let estimatedWeightLb: Double?
}

struct CreateOrderRequest: Codable {
    let customerName: String
    let customerPhone: String
    let pickupSlotStartIso: String
    let items: [CreateOrderItemRequest]
}

struct CreateOrderResponse: Codable {
    let orderId: UUID
    let orderNumber: String
    let paymentClientSecret: String
    let estimatedTotalCents: Int
    let status: OrderStatus
}

struct LookupOrderResponse: Codable {
    let id: UUID
    let orderNumber: String
    let customerName: String
    let customerPhone: String
    let pickupSlotStartIso: String
    let pickupSlotEndIso: String
    let estimatedPickupStartIso: String
    let estimatedPickupEndIso: String
    let totalDelayMinutes: Int
    let status: OrderStatus
    let paymentStatus: PaymentStatus
    let estimatedSubtotalCents: Int
    let estimatedTaxCents: Int
    let estimatedTotalCents: Int
    let finalSubtotalCents: Int?
    let finalTaxCents: Int?
    let finalTotalCents: Int?
    let receiptUrl: URL?

    var pickupWindowLabel: String {
        OasisDateText.pickupWindow(startISO: pickupSlotStartIso, endISO: pickupSlotEndIso)
    }

    var estimatedPickupWindowLabel: String {
        OasisDateText.pickupWindow(startISO: estimatedPickupStartIso, endISO: estimatedPickupEndIso)
    }
}

struct CartItem: Identifiable {
    var id: UUID { product.id }
    let product: Product
    var quantity: Double

    var lineTotalCents: Int {
        Int((Double(product.priceCents) * quantity).rounded())
    }
}

struct AdminLoginRequest: Codable {
    let email: String
    let password: String
}

struct AdminLoginResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let role: String
}

struct AdminOrderListResponse: Codable {
    let orders: [AdminOrder]
}

struct AdminOrder: Codable, Identifiable {
    let id: UUID
    let orderNumber: String
    let customerName: String
    let customerPhone: String
    let pickupSlotStartIso: String
    let pickupSlotEndIso: String
    let estimatedPickupStartIso: String
    let estimatedPickupEndIso: String
    let totalDelayMinutes: Int
    let status: OrderStatus
    let paymentStatus: PaymentStatus
    let estimatedSubtotalCents: Int
    let estimatedTaxCents: Int
    let estimatedTotalCents: Int
    let finalSubtotalCents: Int?
    let finalTaxCents: Int?
    let finalTotalCents: Int?

    var pickupWindowLabel: String {
        OasisDateText.pickupWindow(startISO: pickupSlotStartIso, endISO: pickupSlotEndIso)
    }

    var estimatedPickupWindowLabel: String {
        OasisDateText.pickupWindow(startISO: estimatedPickupStartIso, endISO: estimatedPickupEndIso)
    }
}

struct AdminProductsResponse: Codable {
    let products: [Product]
}

struct DelayOrderRequest: Codable {
    let delayMinutes: Int
}

struct AdminPickupAvailabilityResponse: Codable {
    let days: [AdminPickupDay]
}

struct AdminPickupDay: Codable, Identifiable {
    var id: String { date }
    let date: String
    let openHour: Int
    let closeHour: Int
    let slots: [AdminPickupSlot]

    var title: String {
        OasisDateText.dayHeader(for: date)
    }
}

struct AdminPickupSlot: Codable, Identifiable {
    var id: String { startIso }
    let startIso: String
    let endIso: String
    let capacity: Int
    let booked: Int
    let available: Int
    let isUnavailable: Bool

    var hourRangeLabel: String {
        OasisDateText.hourRange(startISO: startIso, endISO: endIso)
    }
}

struct UpdatePickupDayRangeRequest: Codable {
    let openHour: Int
    let closeHour: Int
}

struct TogglePickupSlotUnavailableRequest: Codable {
    let unavailable: Bool
}

extension Int {
    var usd: String {
        String(format: "$%.2f", Double(self) / 100.0)
    }
}
