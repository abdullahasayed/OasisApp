import SwiftUI

struct AdminInventoryView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var apiClient: ApiClient
    @StateObject private var viewModel = AdminInventoryViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Inventory Management")
                        .font(.system(size: 24, weight: .black, design: .default))
                        .foregroundStyle(Color.oasisInk)
                    Text("Keep stock accurate for shopper pickup ordering.")
                        .font(.system(size: 14, weight: .medium, design: .default))
                        .foregroundStyle(Color.oasisMutedInk)
                    OasisStatusBadge(title: "\(viewModel.products.count) Active Products", tint: .oasisRoyalBlue)
                }
                .oasisCard(prominence: 1.2)

                if viewModel.isLoading {
                    ProgressView("Loading inventory...")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 30)
                        .oasisCard(prominence: 1.05)
                } else if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.system(size: 14, weight: .semibold, design: .default))
                        .foregroundStyle(Color.oasisRed)
                        .oasisCard(prominence: 1.05)
                } else if viewModel.products.isEmpty {
                    ContentUnavailableView(
                        "No products",
                        systemImage: "shippingbox",
                        description: Text("Add products from the admin API.")
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .oasisCard(prominence: 1.05)
                } else {
                    LazyVStack(spacing: 14) {
                        ForEach(viewModel.products) { product in
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
                    }
                }
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 20)
        }
        .scrollIndicators(.hidden)
        .task {
            await viewModel.load(apiClient: apiClient, token: appState.adminAccessToken)
        }
        .animation(.easeInOut(duration: 0.22), value: viewModel.products.count)
        .animation(.easeInOut(duration: 0.22), value: viewModel.errorMessage)
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
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                OasisRemoteImage(url: product.imageUrl) {
                    ZStack {
                        LinearGradient(
                            colors: [
                                product.category.categoryTint.opacity(0.55),
                                product.category.categoryTint.opacity(0.20)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        Image(systemName: product.category.symbolName)
                            .font(.system(size: 18))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(product.name)
                        .font(.system(size: 16, weight: .semibold, design: .default))
                        .foregroundStyle(Color.oasisInk)
                    Text(product.priceLabel)
                        .font(.system(size: 14, weight: .bold, design: .default))
                        .foregroundStyle(product.category.categoryTint)
                }

                Spacer()
                OasisStatusBadge(title: product.category.displayName, tint: product.category.categoryTint)
            }

            TextField("Stock", text: $stockValueText)
                .keyboardType(.decimalPad)
                .oasisInputField()

            Button("Update Stock") {
                if let value = Double(stockValueText) {
                    onSave(value)
                }
            }
            .buttonStyle(OasisPrimaryButtonStyle())
        }
        .oasisCard(prominence: 1.08)
    }
}
