import SwiftUI

@main
struct OasisMarketsApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var apiClient = ApiClient()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(apiClient)
        }
    }
}
