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
    private var activeSlotsRequestID: UUID?

    init(paymentClient: PaymentClient = StripePaymentClient()) {
        self.paymentClient = paymentClient
    }

    func loadSlots(apiClient: ApiClient, date: Date = Date()) async {
        let requestID = UUID()
        activeSlotsRequestID = requestID
        errorMessage = nil
        do {
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: date) ?? date
            async let todaySlots = apiClient.fetchPickupSlots(date: date)
            async let tomorrowSlots = apiClient.fetchPickupSlots(date: tomorrow)

            let slots = try await (todaySlots + tomorrowSlots)
                .filter { $0.available > 0 }
                .sorted {
                    guard
                        let lhs = OasisDateText.parseISO($0.startIso),
                        let rhs = OasisDateText.parseISO($1.startIso)
                    else {
                        return $0.startIso < $1.startIso
                    }
                    return lhs < rhs
                }
            guard activeSlotsRequestID == requestID else { return }
            availableSlots = slots

            if let current = selectedSlot,
               !availableSlots.contains(where: { $0.id == current.id }) {
                selectedSlot = availableSlots.first
            } else if selectedSlot == nil {
                selectedSlot = availableSlots.first
            }
        } catch {
            guard activeSlotsRequestID == requestID else { return }
            errorMessage = error.localizedDescription
        }
    }

    func submitOrder(apiClient: ApiClient, cartItems: [CartItem]) async {
        let normalizedName = customerName.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedPhone = customerPhone.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalizedName.isEmpty else {
            createdOrder = nil
            errorMessage = "Full name is required"
            return
        }

        guard !normalizedPhone.isEmpty else {
            createdOrder = nil
            errorMessage = "Phone number is required"
            return
        }

        guard let selectedSlot else {
            createdOrder = nil
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
            customerName: normalizedName,
            customerPhone: normalizedPhone,
            pickupSlotStartIso: selectedSlot.startIso,
            items: lineItems
        )

        isSubmitting = true
        errorMessage = nil
        createdOrder = nil
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
