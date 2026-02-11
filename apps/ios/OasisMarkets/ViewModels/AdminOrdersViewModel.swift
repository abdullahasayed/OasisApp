import Foundation

@MainActor
final class AdminOrdersViewModel: ObservableObject {
    @Published var selectedStatusFilter: OrderStatus? = nil
    @Published var orders: [AdminOrder] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastReceiptURL: URL?

    private let printerClient: ReceiptPrinterClient

    init(printerClient: ReceiptPrinterClient = EpsonWiredReceiptPrinterClient()) {
        self.printerClient = printerClient
    }

    func load(apiClient: ApiClient, token: String?) async {
        guard let token else {
            errorMessage = "Missing admin token"
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            orders = try await apiClient.fetchAdminOrders(accessToken: token, status: selectedStatusFilter)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func transition(order: AdminOrder, to status: OrderStatus, apiClient: ApiClient, token: String?) async {
        guard let token else {
            errorMessage = "Missing admin token"
            return
        }

        do {
            try await apiClient.updateOrderStatus(accessToken: token, orderId: order.id, status: status)
            await load(apiClient: apiClient, token: token)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func fulfill(order: AdminOrder, apiClient: ApiClient, token: String?) async {
        guard let token else {
            errorMessage = "Missing admin token"
            return
        }

        do {
            let response = try await apiClient.fulfillOrder(accessToken: token, orderId: order.id)
            lastReceiptURL = response.receiptUrl
            do {
                try await printerClient.printEscPosPayload(response.escposPayloadBase64)
            } catch {
                // Keep fulfillment successful even if local printer action fails.
                errorMessage = "Fulfilled, but printer action failed: \(error.localizedDescription)"
            }
            await load(apiClient: apiClient, token: token)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refund(order: AdminOrder, apiClient: ApiClient, token: String?) async {
        guard let token else {
            errorMessage = "Missing admin token"
            return
        }

        let amount = order.finalTotalCents ?? order.estimatedTotalCents
        guard amount > 0 else {
            errorMessage = "No refundable amount"
            return
        }

        do {
            try await apiClient.refundOrder(
                accessToken: token,
                orderId: order.id,
                amountCents: amount,
                reason: "Admin requested refund"
            )
            await load(apiClient: apiClient, token: token)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
