import Foundation

@MainActor
final class AdminAuthViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var isLoading = false
    @Published var errorMessage: String?

    func login(apiClient: ApiClient, appState: AppState) async {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Email and password are required"
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response = try await apiClient.adminLogin(email: email, password: password)
            appState.adminAccessToken = response.accessToken
            appState.adminRefreshToken = response.refreshToken
            appState.appMode = .admin
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
