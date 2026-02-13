import SwiftUI

struct CatalogView: View {
    @EnvironmentObject private var apiClient: ApiClient
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = CatalogViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                CatalogHeroCard(
                    productCount: viewModel.products.count,
                    selectedCategory: viewModel.selectedCategory
                )

                VStack(alignment: .leading, spacing: 10) {
                    Text("Browse Categories")
                        .font(.system(size: 13, weight: .semibold, design: .default))
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
                }
                .oasisCard()

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
                    LazyVStack(spacing: 14) {
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
            .padding(.bottom, 26)
        }
        .scrollIndicators(.hidden)
        .task {
            await viewModel.load(apiClient: apiClient)
            prefetchTopImages()
        }
        .onChange(of: apiClient.isDemoMode) {
            Task {
                await viewModel.load(apiClient: apiClient, force: true)
                prefetchTopImages()
            }
        }
        .onChange(of: viewModel.products.map(\.id)) {
            prefetchTopImages()
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.86), value: viewModel.products.count)
        .animation(.easeInOut(duration: 0.2), value: viewModel.selectedCategory)
    }

    private func prefetchTopImages() {
        ImageLoader.prefetch(urls: Array(viewModel.products.prefix(10)).map(\.imageUrl))
    }
}

private struct CatalogHeroCard: View {
    let productCount: Int
    let selectedCategory: ProductCategory?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Fresh picks for pickup")
                        .font(.system(size: 24, weight: .black, design: .default))
                        .foregroundStyle(Color.oasisInk)

                    Text("Halal meats, produce, and everyday essentials.")
                        .font(.system(size: 14, weight: .medium, design: .default))
                        .foregroundStyle(Color.oasisMutedInk)
                }

                Spacer(minLength: 8)

                ZStack {
                    Circle()
                        .fill(Color.oasisRoyalBlue.opacity(0.14))
                        .frame(width: 64, height: 64)
                    Image(systemName: "basket.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color.oasisRoyalBlue)
                }
            }

            HStack(spacing: 12) {
                OasisStatusBadge(title: "\(productCount) Items", tint: .oasisJungleGreen)
                OasisStatusBadge(
                    title: selectedCategory?.displayName ?? "All Categories",
                    tint: selectedCategory?.categoryTint ?? .oasisRoyalBlue
                )
            }
        }
        .oasisCard(prominence: 1.2)
    }
}

private struct ProductCatalogCard: View {
    let product: Product
    let onAdd: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            OasisRemoteImage(url: product.imageUrl) {
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
            .frame(width: 92, height: 96)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                Text(product.name)
                    .font(.system(size: 17, weight: .bold, design: .default))
                    .foregroundStyle(Color.oasisInk)
                    .lineLimit(2)

                Text(product.priceLabel)
                    .font(.system(size: 14, weight: .bold, design: .default))
                    .foregroundStyle(product.category.categoryTint)

                Text(product.description)
                    .font(.system(size: 13, weight: .regular, design: .default))
                    .foregroundStyle(Color.oasisMutedInk)
                    .lineLimit(2)

                HStack(alignment: .center) {
                    OasisStatusBadge(title: product.category.displayName, tint: product.category.categoryTint)
                    Spacer()
                    Text("Stock \(product.stockQuantity, specifier: "%.1f")")
                        .font(.system(size: 11, weight: .semibold, design: .default))
                        .foregroundStyle(product.stockQuantity > 5 ? Color.oasisJungleGreen : Color.oasisRed)
                }

                HStack(spacing: 8) {
                    Button("Add", action: onAdd)
                        .buttonStyle(OasisSecondaryButtonStyle())
                    NavigationLink {
                        ProductDetailView(product: product)
                    } label: {
                        Text("Details")
                    }
                    .buttonStyle(OasisSecondaryButtonStyle())
                }
            }
        }
        .oasisCard(prominence: 1.1)
    }
}
