import SwiftUI

struct ShopperShellView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        TabView {
            CatalogView()
                .tabItem {
                    Label("Items", systemImage: "cart")
                }

            CartView()
                .badge(appState.cartItems.count)
                .tabItem {
                    Label("Cart", systemImage: "cart.fill")
                }

            OrderLookupView()
                .tabItem {
                    Label("Track", systemImage: "clock.arrow.circlepath")
                }
        }
    }
}
