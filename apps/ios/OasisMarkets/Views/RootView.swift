import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var apiClient: ApiClient

    var body: some View {
        NavigationStack {
            ZStack {
                OasisBackgroundView()
                    .ignoresSafeArea()

                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .top) {
                            OasisWordmarkView()
                            Spacer()

                            VStack(alignment: .trailing, spacing: 6) {
                                if appState.appMode == .shopper {
                                    OasisStatusBadge(
                                        title: "Cart \(appState.cartItems.count)",
                                        tint: .oasisRoyalBlue
                                    )
                                } else {
                                    OasisStatusBadge(title: "Admin", tint: .oasisJungleGreen)
                                }

                                OasisStatusBadge(
                                    title: apiClient.isDemoMode ? "Demo Data" : "Live API",
                                    tint: apiClient.isDemoMode ? .oasisJungleGreen : .oasisRoyalBlue
                                )
                            }
                        }

                        Text("Halal meat pickup and fresh groceries in one seamless order flow.")
                            .font(.system(size: 13, weight: .medium, design: .default))
                            .foregroundStyle(Color.oasisMutedInk)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .oasisCard(prominence: 1.2)

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
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    HStack(spacing: 10) {
                        Image(systemName: apiClient.isDemoMode ? "shippingbox.fill" : "network")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(apiClient.isDemoMode ? Color.oasisJungleGreen : Color.oasisRoyalBlue)

                        Toggle(isOn: Binding(
                            get: { apiClient.isDemoMode },
                            set: {
                                let previous = apiClient.isDemoMode
                                apiClient.setDemoMode($0)

                                if previous != $0 {
                                    appState.adminAccessToken = nil
                                    appState.adminRefreshToken = nil
                                    appState.appMode = .shopper
                                }
                            }
                        )) {
                            Text("Use Demo Data (No Backend Required)")
                                .font(.system(size: 13, weight: .semibold, design: .default))
                                .foregroundStyle(Color.oasisInk)
                        }
                        .tint(.oasisJungleGreen)
                    }
                    .oasisCard()
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
        .animation(.easeInOut(duration: 0.22), value: appState.appMode)
        .animation(.easeInOut(duration: 0.22), value: apiClient.isDemoMode)
    }
}
