import Foundation

@MainActor
final class OrderLookupViewModel: ObservableObject {
    @Published var orderNumber = ""
    @Published var phone = ""
    @Published var result: LookupOrderResponse?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var activeRequestID: UUID?

    func lookup(apiClient: ApiClient) async {
        let normalizedOrderNumber = orderNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedPhone = phone.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalizedOrderNumber.isEmpty, !normalizedPhone.isEmpty else {
            result = nil
            errorMessage = "Order number and phone are required"
            return
        }

        let requestID = UUID()
        activeRequestID = requestID

        isLoading = true
        errorMessage = nil
        result = nil
        defer {
            if activeRequestID == requestID {
                isLoading = false
            }
        }

        do {
            let response = try await apiClient.lookupOrder(orderNumber: normalizedOrderNumber, phone: normalizedPhone)
            guard activeRequestID == requestID else { return }
            result = response
        } catch {
            guard activeRequestID == requestID else { return }
            errorMessage = error.localizedDescription
            result = nil
        }
    }
}
