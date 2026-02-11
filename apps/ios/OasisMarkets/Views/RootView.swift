import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var apiClient: ApiClient

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Picker("Mode", selection: Binding(
                    get: { appState.appMode == .shopper ? 0 : 1 },
                    set: { appState.appMode = $0 == 0 ? .shopper : .admin }
                )) {
                    Text("Shopper").tag(0)
                    Text("Admin").tag(1)
                }
                .pickerStyle(.segmented)

                if appState.appMode == .shopper {
                    ShopperShellView()
                        .environmentObject(apiClient)
                        .environmentObject(appState)
                } else {
                    if appState.adminAccessToken == nil {
                        AdminLoginView()
                    } else {
                        AdminDashboardView()
                    }
                }
            }
            .padding()
            .navigationTitle("Oasis Markets")
        }
    }
}
