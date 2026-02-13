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

            AdminPickupAvailabilityView()
                .tabItem {
                    Label("Pickup", systemImage: "clock.badge.checkmark")
                }
        }
        .toolbarBackground(Color.white.opacity(0.95), for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarColorScheme(.light, for: .tabBar)
        .tint(.oasisRoyalBlue)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    appState.adminAccessToken = nil
                    appState.adminRefreshToken = nil
                    appState.appMode = .shopper
                } label: {
                    Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                }
                .font(.system(size: 14, weight: .semibold, design: .default))
                .foregroundStyle(Color.oasisRed)
            }
        }
    }
}
