import Foundation

@MainActor
final class AdminInventoryViewModel: ObservableObject {
    @Published var products: [Product] = []
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
            products = try await apiClient.fetchAdminProducts(accessToken: token)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateStock(
        for product: Product,
        stockQuantity: Double,
        apiClient: ApiClient,
        token: String?
    ) async {
        guard let token else {
            errorMessage = "Missing admin token"
            return
        }

        do {
            let updated = try await apiClient.updateProductStock(
                accessToken: token,
                productId: product.id,
                stockQuantity: stockQuantity
            )
            if let index = products.firstIndex(where: { $0.id == updated.id }) {
                products[index] = updated
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
