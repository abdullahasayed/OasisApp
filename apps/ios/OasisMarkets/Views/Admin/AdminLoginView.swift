import SwiftUI

struct AdminLoginView: View {
    @EnvironmentObject private var apiClient: ApiClient
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = AdminAuthViewModel()

    var body: some View {
        VStack(spacing: 14) {
            OasisWordmarkView(compact: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("Administrator Console")
                .font(.system(size: 20, weight: .bold, design: .default))
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 10) {
                TextField("Email", text: $viewModel.email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .oasisInputField()

                SecureField("Password", text: $viewModel.password)
                    .oasisInputField()

                Button {
                    Task { await viewModel.login(apiClient: apiClient, appState: appState) }
                } label: {
                    if viewModel.isLoading {
                        ProgressView()
                            .tint(.white)
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Login")
                    }
                }
                .buttonStyle(OasisPrimaryButtonStyle())
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.system(size: 14, weight: .semibold, design: .default))
                    .foregroundStyle(Color.oasisRed)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .oasisCard()
    }
}
