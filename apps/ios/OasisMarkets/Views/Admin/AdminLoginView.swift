import SwiftUI

struct AdminLoginView: View {
    @EnvironmentObject private var apiClient: ApiClient
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = AdminAuthViewModel()

    var body: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                OasisWordmarkView(compact: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("Administrator Console")
                    .font(.system(size: 20, weight: .black, design: .default))
                    .foregroundStyle(Color.oasisInk)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Manage inventory, order lifecycle, fulfillment, and refunds.")
                    .font(.system(size: 13, weight: .medium, design: .default))
                    .foregroundStyle(Color.oasisMutedInk)
            }
            .oasisCard(prominence: 1.15)

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

                if apiClient.isDemoMode {
                    Text("Demo login: admin@oasis.local / OasisAdmin123!")
                        .font(.system(size: 12, weight: .medium, design: .default))
                        .foregroundStyle(Color.oasisMutedInk)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .oasisCard(prominence: 1.05)

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.system(size: 14, weight: .semibold, design: .default))
                    .foregroundStyle(Color.oasisRed)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .oasisCard()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
