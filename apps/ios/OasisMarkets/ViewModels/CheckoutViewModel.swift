import Foundation

@MainActor
final class CheckoutViewModel: ObservableObject {
    @Published var customerName = ""
    @Published var customerPhone = ""
    @Published var selectedSlot: PickupSlot?
    @Published var availableSlots: [PickupSlot] = []
    @Published var isSubmitting = false
    @Published var errorMessage: String?
    @Published var createdOrder: CreateOrderResponse?

    private let paymentClient: PaymentClient

    init(paymentClient: PaymentClient = StripePaymentClient()) {
        self.paymentClient = paymentClient
    }

    func loadSlots(apiClient: ApiClient, date: Date = Date()) async {
        errorMessage = nil
        do {
            availableSlots = try await apiClient.fetchPickupSlots(date: date).filter { $0.available > 0 }
            if selectedSlot == nil {
                selectedSlot = availableSlots.first
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func submitOrder(apiClient: ApiClient, cartItems: [CartItem]) async {
        guard !customerName.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Full name is required"
            return
        }

        guard !customerPhone.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Phone number is required"
            return
        }

        guard let selectedSlot else {
            errorMessage = "Select a pickup slot"
            return
        }

        let lineItems = cartItems.map { item in
            CreateOrderItemRequest(
                productId: item.product.id,
                quantity: item.quantity,
                estimatedWeightLb: item.product.unit == .lb ? item.quantity : nil
            )
        }

        let payload = CreateOrderRequest(
            customerName: customerName,
            customerPhone: customerPhone,
            pickupSlotStartIso: selectedSlot.startIso,
            items: lineItems
        )

        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        do {
            let order = try await apiClient.createOrder(payload)
            try await paymentClient.prepareCheckout(clientSecret: order.paymentClientSecret)
            try await paymentClient.completeCheckout()
            createdOrder = order
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
