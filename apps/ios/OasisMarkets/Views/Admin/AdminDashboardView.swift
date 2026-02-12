import SwiftUI

struct AdminDashboardView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        TabView {
            AdminInventoryView()
                .tabItem {
                    Label("Inventory", systemImage: "shippingbox.fill")
                }

            AdminOrdersView()
                .tabItem {
                    Label("Orders", systemImage: "list.bullet.rectangle.portrait.fill")
                }
        }
        .toolbarBackground(Color.white.opacity(0.92), for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Sign Out") {
                    appState.adminAccessToken = nil
                    appState.adminRefreshToken = nil
                    appState.appMode = .shopper
                }
                .font(.system(size: 14, weight: .semibold, design: .default))
                .foregroundStyle(Color.oasisRed)
            }
        }
    }
}
