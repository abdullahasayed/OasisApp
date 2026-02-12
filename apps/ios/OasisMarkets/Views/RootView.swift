import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationStack {
            ZStack {
                OasisBackgroundView()
                    .ignoresSafeArea()

                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top) {
                        OasisWordmarkView()
                        Spacer()

                        if appState.appMode == .shopper {
                            OasisStatusBadge(
                                title: "Cart \(appState.cartItems.count)",
                                tint: .oasisRoyalBlue
                            )
                        } else {
                            OasisStatusBadge(title: "Admin", tint: .oasisJungleGreen)
                        }
                    }
                    .padding(.horizontal, 4)

                    OasisModeToggle(
                        isShopperMode: appState.appMode == .shopper,
                        onSelect: { mode in
                            appState.appMode = mode
                        }
                    )

                    Group {
                        if appState.appMode == .shopper {
                            ShopperShellView()
                        } else if appState.adminAccessToken == nil {
                            AdminLoginView()
                        } else {
                            AdminDashboardView()
                        }
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding(16)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Oasis International Market")
                        .font(.system(size: 17, weight: .semibold, design: .default))
                        .foregroundStyle(Color.oasisInk)
                }
            }
        }
        .tint(.oasisRoyalBlue)
    }
}
