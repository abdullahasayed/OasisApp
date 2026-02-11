import SwiftUI

struct AdminOrdersView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var apiClient: ApiClient
    @StateObject private var viewModel = AdminOrdersViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Filter", selection: $viewModel.selectedStatusFilter) {
                Text("All").tag(OrderStatus?.none)
                ForEach(OrderStatus.allCases, id: \.rawValue) { status in
                    Text(status.displayName).tag(OrderStatus?.some(status))
                }
            }
            .pickerStyle(.menu)
            .onChange(of: viewModel.selectedStatusFilter) { _ in
                Task {
                    await viewModel.load(apiClient: apiClient, token: appState.adminAccessToken)
                }
            }

            if viewModel.isLoading {
                ProgressView("Loading orders...")
            } else if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundStyle(.red)
            } else {
                List(viewModel.orders) { order in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(order.orderNumber)
                            .font(.headline)
                        Text(order.customerName.uppercased())
                            .font(.subheadline)
                        Text("Status: \(order.status.displayName)")
                            .font(.caption)
                        Text("Estimated: \(order.estimatedTotalCents.usd)")
                            .font(.caption)

                        HStack {
                            Button("Preparing") {
                                Task {
                                    await viewModel.transition(
                                        order: order,
                                        to: .preparing,
                                        apiClient: apiClient,
                                        token: appState.adminAccessToken
                                    )
                                }
                            }
                            .buttonStyle(.bordered)

                            Button("Ready") {
                                Task {
                                    await viewModel.transition(
                                        order: order,
                                        to: .ready,
                                        apiClient: apiClient,
                                        token: appState.adminAccessToken
                                    )
                                }
                            }
                            .buttonStyle(.bordered)

                            Button("Fulfill") {
                                Task {
                                    await viewModel.fulfill(
                                        order: order,
                                        apiClient: apiClient,
                                        token: appState.adminAccessToken
                                    )
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }

                        HStack {
                            Button("Delay") {
                                Task {
                                    await viewModel.transition(
                                        order: order,
                                        to: .delayed,
                                        apiClient: apiClient,
                                        token: appState.adminAccessToken
                                    )
                                }
                            }
                            .buttonStyle(.bordered)

                            Button("Cancel") {
                                Task {
                                    await viewModel.transition(
                                        order: order,
                                        to: .cancelled,
                                        apiClient: apiClient,
                                        token: appState.adminAccessToken
                                    )
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(.plain)
            }
        }
        .task {
            await viewModel.load(apiClient: apiClient, token: appState.adminAccessToken)
        }
    }
}
