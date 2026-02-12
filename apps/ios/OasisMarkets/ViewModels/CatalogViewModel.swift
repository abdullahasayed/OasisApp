import Foundation

@MainActor
final class CatalogViewModel: ObservableObject {
    @Published var selectedCategory: ProductCategory? = nil
    @Published var products: [Product] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var activeRequestID: UUID?
    private var lastLoadedCategory: ProductCategory?
    private var hasLoaded = false

    func load(apiClient: ApiClient, force: Bool = false) async {
        if !force, hasLoaded, lastLoadedCategory == selectedCategory {
            return
        }

        let requestID = UUID()
        activeRequestID = requestID
        isLoading = true
        errorMessage = nil

        do {
            let fetched = try await apiClient.fetchCatalog(category: selectedCategory)
            guard activeRequestID == requestID else { return }
            products = fetched
            hasLoaded = true
            lastLoadedCategory = selectedCategory
        } catch {
            guard activeRequestID == requestID else { return }
            errorMessage = error.localizedDescription
        }

        guard activeRequestID == requestID else { return }
        isLoading = false
    }
}
