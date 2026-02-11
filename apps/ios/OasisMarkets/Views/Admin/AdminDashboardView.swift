import SwiftUI

struct AdminDashboardView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        TabView {
            AdminInventoryView()
                .tabItem {
                    Label("Inventory", systemImage: "shippingbox")
                }

            AdminOrdersView()
                .tabItem {
                    Label("Orders", systemImage: "list.bullet.rectangle")
                }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Sign Out") {
                    appState.adminAccessToken = nil
                    appState.adminRefreshToken = nil
                    appState.appMode = .shopper
                }
            }
        }
    }
}
