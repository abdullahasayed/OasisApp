import SwiftUI

struct AdminLoginView: View {
    @EnvironmentObject private var apiClient: ApiClient
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = AdminAuthViewModel()

    var body: some View {
        Form {
            Section("Administrator Login") {
                TextField("Email", text: $viewModel.email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)

                SecureField("Password", text: $viewModel.password)

                Button {
                    Task { await viewModel.login(apiClient: apiClient, appState: appState) }
                } label: {
                    if viewModel.isLoading {
                        ProgressView()
                    } else {
                        Text("Login")
                    }
                }
            }

            if let error = viewModel.errorMessage {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                }
            }
        }
    }
}
