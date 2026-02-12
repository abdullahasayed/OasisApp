import SwiftUI

struct AdminOrdersView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var apiClient: ApiClient
    @StateObject private var viewModel = AdminOrdersViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Order Operations")
                    .font(.system(size: 22, weight: .bold, design: .default))
                    .foregroundStyle(Color.oasisInk)

                Menu {
                    Button("All") {
                        viewModel.selectedStatusFilter = nil
                        Task { await viewModel.load(apiClient: apiClient, token: appState.adminAccessToken) }
                    }

                    ForEach(OrderStatus.allCases, id: \.rawValue) { status in
                        Button(status.displayName) {
                            viewModel.selectedStatusFilter = status
                            Task { await viewModel.load(apiClient: apiClient, token: appState.adminAccessToken) }
                        }
                    }
                } label: {
                    HStack {
                        Text(viewModel.selectedStatusFilter?.displayName ?? "All statuses")
                        Spacer()
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                    .font(.system(size: 14, weight: .semibold, design: .default))
                    .foregroundStyle(Color.oasisInk)
                    .oasisInputField()
                }

                if viewModel.isLoading {
                    ProgressView("Loading orders...")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 30)
                        .oasisCard()
                } else if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.system(size: 14, weight: .semibold, design: .default))
                        .foregroundStyle(Color.oasisRed)
                        .oasisCard()
                } else if viewModel.orders.isEmpty {
                    ContentUnavailableView(
                        "No orders",
                        systemImage: "tray",
                        description: Text("Orders will appear here once customers checkout.")
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .oasisCard()
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.orders) { order in
                            AdminOrderCard(
                                order: order,
                                onTransition: { status in
                                    Task {
                                        await viewModel.transition(
                                            order: order,
                                            to: status,
                                            apiClient: apiClient,
                                            token: appState.adminAccessToken
                                        )
                                    }
                                },
                                onFulfill: {
                                    Task {
                                        await viewModel.fulfill(
                                            order: order,
                                            apiClient: apiClient,
                                            token: appState.adminAccessToken
                                        )
                                    }
                                },
                                onRefund: {
                                    Task {
                                        await viewModel.refund(
                                            order: order,
                                            apiClient: apiClient,
                                            token: appState.adminAccessToken
                                        )
                                    }
                                }
                            )
                        }
                    }
                }

                if let receiptURL = viewModel.lastReceiptURL {
                    Link("Open Latest Receipt", destination: receiptURL)
                        .font(.system(size: 14, weight: .semibold, design: .default))
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 20)
        }
        .scrollIndicators(.hidden)
        .task {
            await viewModel.load(apiClient: apiClient, token: appState.adminAccessToken)
        }
    }
}

private struct AdminOrderCard: View {
    let order: AdminOrder
    let onTransition: (OrderStatus) -> Void
    let onFulfill: () -> Void
    let onRefund: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(order.orderNumber)
                        .font(.system(size: 20, weight: .black, design: .default))
                        .foregroundStyle(Color.oasisInk)
                    Text(order.customerName.uppercased())
                        .font(.system(size: 13, weight: .bold, design: .default))
                        .foregroundStyle(Color.oasisMutedInk)
                }
                Spacer()
                OasisStatusBadge(title: order.status.displayName, tint: order.status.statusTint)
            }

            Text(order.pickupWindowLabel)
                .font(.system(size: 13, weight: .medium, design: .default))
                .foregroundStyle(Color.oasisMutedInk)

            HStack {
                Text("Estimated")
                    .font(.system(size: 12, weight: .medium, design: .default))
                    .foregroundStyle(Color.oasisMutedInk)
                Spacer()
                Text(order.estimatedTotalCents.usd)
                    .font(.system(size: 14, weight: .bold, design: .default))
                    .foregroundStyle(Color.oasisJungleGreen)
            }

            if let finalTotal = order.finalTotalCents {
                HStack {
                    Text("Final")
                        .font(.system(size: 12, weight: .medium, design: .default))
                        .foregroundStyle(Color.oasisMutedInk)
                    Spacer()
                    Text(finalTotal.usd)
                        .font(.system(size: 14, weight: .bold, design: .default))
                        .foregroundStyle(Color.oasisRoyalBlue)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    actionButton("Preparing") { onTransition(.preparing) }
                    actionButton("Ready") { onTransition(.ready) }
                    actionButton("Delay") { onTransition(.delayed) }
                    actionButton("Cancel") { onTransition(.cancelled) }
                    actionButton("Fulfill") { onFulfill() }
                    actionButton("Refund") { onRefund() }
                }
            }
        }
        .oasisCard()
    }

    private func actionButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(OasisSecondaryButtonStyle())
    }
}
