import SwiftUI

struct ShopperShellView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        TabView {
            CatalogView()
                .tabItem {
                    Label("Items", systemImage: "basket.fill")
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
        .toolbarBackground(Color.white.opacity(0.92), for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }
}
