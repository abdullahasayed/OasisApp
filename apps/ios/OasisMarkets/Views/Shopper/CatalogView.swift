import SwiftUI

struct CatalogView: View {
    @EnvironmentObject private var apiClient: ApiClient
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = CatalogViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Category", selection: $viewModel.selectedCategory) {
                Text("All").tag(ProductCategory?.none)
                ForEach(ProductCategory.allCases) { category in
                    Text(category.displayName).tag(ProductCategory?.some(category))
                }
            }
            .pickerStyle(.menu)
            .onChange(of: viewModel.selectedCategory) { _ in
                Task { await viewModel.load(apiClient: apiClient) }
            }

            if viewModel.isLoading {
                ProgressView("Loading catalog...")
            } else if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundStyle(.red)
            } else {
                List(viewModel.products) { product in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(product.name)
                                    .font(.headline)
                                Text(product.priceLabel)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Add") {
                                let quantity = product.unit == .lb ? 1.0 : 1.0
                                appState.addToCart(product: product, quantity: quantity)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        Text(product.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(.plain)
            }
        }
        .task {
            await viewModel.load(apiClient: apiClient)
        }
    }
}
