import Foundation
import SwiftUI

@MainActor
final class AdminInventoryViewModel: ObservableObject {
    @Published var products: [Product] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published private(set) var recentlyUpdatedProductIDs: Set<UUID> = []

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
            withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
                _ = recentlyUpdatedProductIDs.insert(updated.id)
            }
            Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(1200))
                await MainActor.run {
                    withAnimation(.easeOut(duration: 0.2)) {
                        _ = self?.recentlyUpdatedProductIDs.remove(updated.id)
                    }
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
