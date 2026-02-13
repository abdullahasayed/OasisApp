import SwiftUI

struct ProductDetailView: View {
    @EnvironmentObject private var appState: AppState

    let product: Product
    @State private var quantity: Double = 1

    private var stepSize: Double {
        product.unit == .lb ? 0.25 : 1
    }

    private var lineTotalCents: Int {
        Int((Double(product.priceCents) * quantity).rounded())
    }

    private var stockLabel: String {
        String(format: "%.1f in stock", product.stockQuantity)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                OasisRemoteImage(url: product.imageUrl) {
                    ZStack {
                        LinearGradient(
                            colors: [
                                product.category.categoryTint.opacity(0.6),
                                product.category.categoryTint.opacity(0.24)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        Image(systemName: product.category.symbolName)
                            .font(.system(size: 48))
                            .foregroundStyle(.white)
                    }
                }
                .frame(height: 270)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(alignment: .bottomLeading) {
                    OasisStatusBadge(title: product.category.displayName, tint: product.category.categoryTint)
                        .padding(12)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(product.name)
                        .font(.system(size: 28, weight: .black, design: .default))
                        .foregroundStyle(Color.oasisInk)
                    Text(product.description)
                        .font(.system(size: 15, weight: .medium, design: .default))
                        .foregroundStyle(Color.oasisMutedInk)
                    HStack {
                        OasisStatusBadge(title: stockLabel, tint: .oasisJungleGreen)
                        Spacer()
                        Text(product.priceLabel)
                            .font(.system(size: 19, weight: .bold, design: .default))
                            .foregroundStyle(product.category.categoryTint)
                    }
                }
                .oasisCard(prominence: 1.15)

                VStack(alignment: .leading, spacing: 10) {
                    Text(product.unit == .lb ? "Estimated Weight" : "Quantity")
                        .font(.system(size: 16, weight: .semibold, design: .default))
                        .foregroundStyle(Color.oasisInk)

                    HStack {
                        Button {
                            quantity = max(stepSize, quantity - stepSize)
                        } label: {
                            Image(systemName: "minus")
                                .font(.system(size: 13, weight: .bold))
                                .frame(width: 34, height: 34)
                        }
                        .buttonStyle(OasisSecondaryButtonStyle())

                        Spacer()

                        Text("\(quantity, specifier: product.unit == .lb ? "%.2f" : "%.0f") \(product.unit.displayName)")
                            .font(.system(size: 18, weight: .bold, design: .default))
                            .foregroundStyle(Color.oasisInk)

                        Spacer()

                        Button {
                            quantity += stepSize
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 13, weight: .bold))
                                .frame(width: 34, height: 34)
                        }
                        .buttonStyle(OasisSecondaryButtonStyle())
                    }

                    Text("Estimated line total: \(lineTotalCents.usd)")
                        .font(.system(size: 14, weight: .semibold, design: .default))
                        .foregroundStyle(Color.oasisJungleGreen)
                }
                .oasisCard(prominence: 1.1)

                Button {
                    appState.addToCart(product: product, quantity: quantity)
                } label: {
                    Text("Add to Cart")
                }
                .buttonStyle(OasisPrimaryButtonStyle())
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
        .navigationTitle(product.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
