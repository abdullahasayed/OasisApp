import SwiftUI

struct CartView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if appState.cartItems.isEmpty {
                ContentUnavailableView("Your cart is empty", systemImage: "cart")
            } else {
                List {
                    ForEach(appState.cartItems) { item in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(item.product.name)
                                Text("Qty/Weight: \(item.quantity, specifier: "%.2f")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(Int((Double(item.product.priceCents) * item.quantity).rounded()).usd)
                                .fontWeight(.semibold)
                        }
                    }
                    .onDelete { indexSet in
                        indexSet.map { appState.cartItems[$0] }.forEach(appState.removeFromCart)
                    }
                }
                .listStyle(.plain)

                Text("Estimated total: \(appState.estimatedCartTotalCents.usd)")
                    .font(.headline)

                NavigationLink("Checkout") {
                    CheckoutView()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}
