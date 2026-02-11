import SwiftUI

struct AdminInventoryView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var apiClient: ApiClient
    @StateObject private var viewModel = AdminInventoryViewModel()

    var body: some View {
        VStack {
            if viewModel.isLoading {
                ProgressView("Loading inventory...")
            } else if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundStyle(.red)
            } else {
                List(viewModel.products) { product in
                    VStack(alignment: .leading) {
                        Text(product.name)
                            .font(.headline)
                        Text("Stock: \(product.stockQuantity, specifier: "%.2f")")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(product.priceLabel)
                            .font(.caption)
                    }
                }
                .listStyle(.plain)
            }
        }
        .task {
            await viewModel.load(apiClient: apiClient, token: appState.adminAccessToken)
        }
    }
}
