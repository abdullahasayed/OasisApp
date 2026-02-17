import Foundation

@MainActor
final class CatalogViewModel: ObservableObject {
    @Published var selectedCategory: ProductCategory? = nil
    @Published var searchQuery = ""
    @Published var products: [Product] = []
    @Published var isLoading = false
    @Published var isSearching = false
    @Published var errorMessage: String?

    private var activeRequestID: UUID?
    private var searchDebounceTask: Task<Void, Never>?
    private var lastLoadedCategory: ProductCategory?
    private var lastLoadedQuery = ""
    private var hasLoaded = false
    private var rawSearchProducts: [Product] = []

    deinit {
        searchDebounceTask?.cancel()
    }

    func load(apiClient: ApiClient, force: Bool = false) async {
        let query = normalizedSearchQuery
        if !force,
           hasLoaded,
           lastLoadedCategory == selectedCategory,
           lastLoadedQuery == query {
            return
        }

        let requestID = UUID()
        activeRequestID = requestID
        isLoading = true
        isSearching = !query.isEmpty
        errorMessage = nil

        do {
            let fetched = try await apiClient.fetchCatalog(
                category: query.isEmpty ? selectedCategory : nil,
                query: query.isEmpty ? nil : query,
                limit: 100
            )
            guard activeRequestID == requestID else { return }
            if query.isEmpty {
                rawSearchProducts = []
                products = fetched
            } else {
                rawSearchProducts = fetched
                products = filteredSearchProducts()
            }
            hasLoaded = true
            lastLoadedCategory = selectedCategory
            lastLoadedQuery = query
        } catch {
            guard activeRequestID == requestID else { return }
            errorMessage = error.localizedDescription
        }

        guard activeRequestID == requestID else { return }
        isLoading = false
        isSearching = false
    }

    func updateCategory(_ category: ProductCategory?, apiClient: ApiClient) {
        selectedCategory = category
        if normalizedSearchQuery.isEmpty {
            Task {
                await load(apiClient: apiClient)
            }
            return
        }

        if !rawSearchProducts.isEmpty {
            products = filteredSearchProducts()
            lastLoadedCategory = category
            return
        }

        Task {
            await load(apiClient: apiClient, force: true)
        }
    }

    func updateSearchQuery(_ query: String, apiClient: ApiClient) {
        searchQuery = query
        searchDebounceTask?.cancel()

        let normalized = normalizedSearchQuery
        if normalized.isEmpty {
            rawSearchProducts = []
            Task {
                await load(apiClient: apiClient, force: true)
            }
            return
        }

        isSearching = true
        searchDebounceTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            guard let self else { return }
            await self.load(apiClient: apiClient, force: true)
        }
    }

    private var normalizedSearchQuery: String {
        searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func filteredSearchProducts() -> [Product] {
        guard let category = selectedCategory else {
            return rawSearchProducts
        }
        return rawSearchProducts.filter { $0.category == category }
    }
}
