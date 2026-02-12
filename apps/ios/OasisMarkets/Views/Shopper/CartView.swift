import SwiftUI

struct CartView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            if appState.cartItems.isEmpty {
                ContentUnavailableView(
                    "Your cart is empty",
                    systemImage: "cart",
                    description: Text("Add groceries to start your pickup order.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(appState.cartItems) { item in
                            HStack(alignment: .top, spacing: 12) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(item.product.name)
                                        .font(.system(size: 16, weight: .semibold, design: .default))
                                        .foregroundStyle(Color.oasisInk)

                                    Text("\(item.quantity, specifier: item.product.unit == .lb ? "%.2f" : "%.0f") \(item.product.unit.displayName)")
                                        .font(.system(size: 13, weight: .medium, design: .default))
                                        .foregroundStyle(Color.oasisMutedInk)

                                    OasisStatusBadge(
                                        title: item.product.category.displayName,
                                        tint: item.product.category.categoryTint
                                    )
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 8) {
                                    Text(item.lineTotalCents.usd)
                                        .font(.system(size: 16, weight: .bold, design: .default))
                                        .foregroundStyle(Color.oasisJungleGreen)

                                    Button {
                                        appState.removeFromCart(item: item)
                                    } label: {
                                        Label("Remove", systemImage: "trash")
                                    }
                                    .buttonStyle(OasisSecondaryButtonStyle())
                                }
                            }
                            .oasisCard()
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Estimated Cart Total")
                                .font(.system(size: 14, weight: .medium, design: .default))
                                .foregroundStyle(Color.oasisMutedInk)
                            Text(appState.estimatedCartTotalCents.usd)
                                .font(.system(size: 28, weight: .black, design: .default))
                                .foregroundStyle(Color.oasisInk)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .oasisCard()
                    }
                    .padding(.horizontal, 4)
                    .padding(.bottom, 110)
                }
                .scrollIndicators(.hidden)
                .safeAreaInset(edge: .bottom) {
                    NavigationLink {
                        CheckoutView()
                    } label: {
                        Text("Continue to Checkout")
                    }
                    .buttonStyle(OasisPrimaryButtonStyle())
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(.thinMaterial)
                }
            }
        }
    }
}
