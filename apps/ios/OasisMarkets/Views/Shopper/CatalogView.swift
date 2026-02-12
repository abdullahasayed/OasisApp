import SwiftUI

struct CatalogView: View {
    @EnvironmentObject private var apiClient: ApiClient
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = CatalogViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Fresh picks for pickup")
                    .font(.system(size: 22, weight: .bold, design: .default))
                    .foregroundStyle(Color.oasisInk)

                Text("Halal meats, produce, and everyday essentials.")
                    .font(.system(size: 14, weight: .regular, design: .default))
                    .foregroundStyle(Color.oasisMutedInk)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        Button {
                            viewModel.selectedCategory = nil
                            Task { await viewModel.load(apiClient: apiClient) }
                        } label: {
                            OasisCategoryPill(
                                title: "All",
                                isSelected: viewModel.selectedCategory == nil
                            )
                        }
                        .buttonStyle(.plain)

                        ForEach(ProductCategory.allCases) { category in
                            Button {
                                viewModel.selectedCategory = category
                                Task { await viewModel.load(apiClient: apiClient) }
                            } label: {
                                OasisCategoryPill(
                                    title: category.displayName,
                                    isSelected: viewModel.selectedCategory == category
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if viewModel.isLoading {
                    ProgressView("Loading catalog...")
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 32)
                        .oasisCard()
                } else if let error = viewModel.errorMessage {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Could not load items")
                            .font(.system(size: 16, weight: .semibold, design: .default))
                        Text(error)
                            .font(.system(size: 14, weight: .regular, design: .default))
                            .foregroundStyle(Color.oasisRed)
                    }
                    .oasisCard()
                } else if viewModel.products.isEmpty {
                    ContentUnavailableView(
                        "No items available",
                        systemImage: "basket",
                        description: Text("Try another category.")
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .oasisCard()
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.products) { product in
                            ProductCatalogCard(
                                product: product,
                                onAdd: {
                                    appState.addToCart(product: product, quantity: product.unit == .lb ? 1.0 : 1.0)
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
            await viewModel.load(apiClient: apiClient)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.86), value: viewModel.products.count)
        .animation(.easeInOut(duration: 0.2), value: viewModel.selectedCategory)
    }
}

private struct ProductCatalogCard: View {
    let product: Product
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: product.imageUrl) { phase in
                switch phase {
                case let .success(image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    ZStack {
                        LinearGradient(
                            colors: [
                                product.category.categoryTint.opacity(0.55),
                                product.category.categoryTint.opacity(0.22)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        Image(systemName: product.category.symbolName)
                            .font(.system(size: 20))
                            .foregroundStyle(.white)
                    }
                }
            }
            .frame(width: 82, height: 82)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(product.name)
                            .font(.system(size: 16, weight: .semibold, design: .default))
                            .foregroundStyle(Color.oasisInk)
                            .lineLimit(2)

                        Text(product.priceLabel)
                            .font(.system(size: 14, weight: .bold, design: .default))
                            .foregroundStyle(product.category.categoryTint)
                    }

                    Spacer(minLength: 8)

                    VStack(spacing: 8) {
                        Button("Add") {
                            onAdd()
                        }
                        .buttonStyle(OasisSecondaryButtonStyle())

                        NavigationLink {
                            ProductDetailView(product: product)
                        } label: {
                            Text("Details")
                        }
                        .buttonStyle(OasisSecondaryButtonStyle())
                    }
                }

                Text(product.description)
                    .font(.system(size: 13, weight: .regular, design: .default))
                    .foregroundStyle(Color.oasisMutedInk)
                    .lineLimit(2)

                HStack {
                    OasisStatusBadge(title: product.category.displayName, tint: product.category.categoryTint)
                    Spacer()
                    Text("Stock \(product.stockQuantity, specifier: "%.1f")")
                        .font(.system(size: 11, weight: .medium, design: .default))
                        .foregroundStyle(Color.oasisMutedInk)
                }
            }
        }
        .oasisCard()
    }
}
