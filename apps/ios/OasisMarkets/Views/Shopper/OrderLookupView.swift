import SwiftUI

struct OrderLookupView: View {
    @EnvironmentObject private var apiClient: ApiClient
    @StateObject private var viewModel = OrderLookupViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Track Your Pickup")
                        .font(.system(size: 24, weight: .black, design: .default))
                        .foregroundStyle(Color.oasisInk)
                    Text("Enter order number and phone to check your live status.")
                        .font(.system(size: 14, weight: .medium, design: .default))
                        .foregroundStyle(Color.oasisMutedInk)
                }
                .oasisCard(prominence: 1.2)

                VStack(alignment: .leading, spacing: 10) {
                    TextField("Order Number", text: $viewModel.orderNumber)
                        .textInputAutocapitalization(.characters)
                        .oasisInputField()

                    TextField("Phone", text: $viewModel.phone)
                        .keyboardType(.phonePad)
                        .oasisInputField()

                    Button {
                        Task { await viewModel.lookup(apiClient: apiClient) }
                    } label: {
                        Text("Find Order")
                    }
                    .buttonStyle(OasisPrimaryButtonStyle())
                }
                .oasisCard(prominence: 1.05)

                if let result = viewModel.result {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(result.orderNumber)
                                .font(.system(size: 28, weight: .black, design: .default))
                                .foregroundStyle(Color.oasisRed)
                            Spacer()
                            OasisStatusBadge(title: result.status.displayName, tint: result.status.statusTint)
                        }

                        Text(result.customerName.uppercased())
                            .font(.system(size: 18, weight: .bold, design: .default))
                            .foregroundStyle(Color.oasisInk)

                        Text(result.pickupWindowLabel)
                            .font(.system(size: 14, weight: .medium, design: .default))
                            .foregroundStyle(Color.oasisMutedInk)

                        Divider()

                        Text("Estimated total: \(result.estimatedTotalCents.usd)")
                            .font(.system(size: 14, weight: .semibold, design: .default))
                        if let finalTotal = result.finalTotalCents {
                            Text("Final total: \(finalTotal.usd)")
                                .font(.system(size: 14, weight: .semibold, design: .default))
                                .foregroundStyle(Color.oasisRoyalBlue)
                        }

                        if let receipt = result.receiptUrl {
                            Link("Open Receipt", destination: receipt)
                                .font(.system(size: 14, weight: .semibold, design: .default))
                                .foregroundStyle(Color.oasisRoyalBlue)
                        }
                    }
                    .oasisCard(prominence: 1.2)
                }

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.system(size: 14, weight: .semibold, design: .default))
                        .foregroundStyle(Color.oasisRed)
                        .oasisCard(prominence: 1.05)
                }
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .animation(.easeInOut(duration: 0.22), value: viewModel.result?.id)
        .animation(.easeInOut(duration: 0.22), value: viewModel.errorMessage)
    }
}
