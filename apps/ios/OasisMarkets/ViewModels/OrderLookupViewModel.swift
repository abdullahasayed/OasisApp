import Foundation

@MainActor
final class OrderLookupViewModel: ObservableObject {
    @Published var orderNumber = ""
    @Published var phone = ""
    @Published var result: LookupOrderResponse?
    @Published var isLoading = false
    @Published var errorMessage: String?

    func lookup(apiClient: ApiClient) async {
        guard !orderNumber.isEmpty, !phone.isEmpty else {
            errorMessage = "Order number and phone are required"
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            result = try await apiClient.lookupOrder(orderNumber: orderNumber, phone: phone)
        } catch {
            errorMessage = error.localizedDescription
            result = nil
        }
    }
}
