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
                    AdminInventoryRow(
                        product: product,
                        onSave: { value in
                            Task {
                                await viewModel.updateStock(
                                    for: product,
                                    stockQuantity: value,
                                    apiClient: apiClient,
                                    token: appState.adminAccessToken
                                )
                            }
                        }
                    )
                }
                .listStyle(.plain)
            }
        }
        .task {
            await viewModel.load(apiClient: apiClient, token: appState.adminAccessToken)
        }
    }
}

private struct AdminInventoryRow: View {
    let product: Product
    let onSave: (Double) -> Void

    @State private var stockValueText: String

    init(product: Product, onSave: @escaping (Double) -> Void) {
        self.product = product
        self.onSave = onSave
        _stockValueText = State(initialValue: String(format: "%.2f", product.stockQuantity))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(product.name)
                .font(.headline)
            Text(product.priceLabel)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                TextField("Stock", text: $stockValueText)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.decimalPad)

                Button("Update") {
                    if let value = Double(stockValueText) {
                        onSave(value)
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.vertical, 4)
    }
}
