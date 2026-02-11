import Foundation

@MainActor
final class CatalogViewModel: ObservableObject {
    @Published var selectedCategory: ProductCategory? = nil
    @Published var products: [Product] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func load(apiClient: ApiClient) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            products = try await apiClient.fetchCatalog(category: selectedCategory)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
