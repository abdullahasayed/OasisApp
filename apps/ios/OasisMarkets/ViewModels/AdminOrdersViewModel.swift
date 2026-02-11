import Foundation

@MainActor
final class AdminOrdersViewModel: ObservableObject {
    @Published var selectedStatusFilter: OrderStatus? = nil
    @Published var orders: [AdminOrder] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

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
            _ = try await apiClient.fulfillOrder(accessToken: token, orderId: order.id)
            await load(apiClient: apiClient, token: token)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
