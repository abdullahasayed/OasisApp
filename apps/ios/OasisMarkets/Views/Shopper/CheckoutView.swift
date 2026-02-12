import SwiftUI

struct CheckoutView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var apiClient: ApiClient
    @StateObject private var viewModel = CheckoutViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Checkout")
                    .font(.system(size: 26, weight: .black, design: .default))
                    .foregroundStyle(Color.oasisInk)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Customer Details")
                        .font(.system(size: 16, weight: .semibold, design: .default))

                    TextField("Full Name", text: $viewModel.customerName)
                        .textInputAutocapitalization(.words)
                        .oasisInputField()

                    TextField("Phone", text: $viewModel.customerPhone)
                        .keyboardType(.phonePad)
                        .oasisInputField()
                }
                .oasisCard()

                VStack(alignment: .leading, spacing: 10) {
                    Text("Pickup Slot")
                        .font(.system(size: 16, weight: .semibold, design: .default))

                    if viewModel.availableSlots.isEmpty {
                        Text("No available slots")
                            .font(.system(size: 14, weight: .medium, design: .default))
                            .foregroundStyle(Color.oasisMutedInk)
                    } else {
                        Menu {
                            ForEach(viewModel.availableSlots) { slot in
                                Button(slot.displayLabel) {
                                    viewModel.selectedSlot = slot
                                }
                            }
                        } label: {
                            HStack {
                                Text(viewModel.selectedSlot?.displayLabel ?? "Select pickup window")
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                                Spacer()
                                Image(systemName: "chevron.down")
                            }
                            .font(.system(size: 14, weight: .medium, design: .default))
                            .foregroundStyle(Color.oasisInk)
                            .oasisInputField()
                        }
                    }
                }
                .oasisCard()

                Button {
                    Task {
                        await viewModel.submitOrder(apiClient: apiClient, cartItems: appState.cartItems)
                        if viewModel.createdOrder != nil {
                            appState.clearCart()
                        }
                    }
                } label: {
                    if viewModel.isSubmitting {
                        ProgressView()
                            .tint(.white)
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Place Pickup Order")
                    }
                }
                .buttonStyle(OasisPrimaryButtonStyle())
                .disabled(viewModel.isSubmitting || appState.cartItems.isEmpty)

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.system(size: 14, weight: .semibold, design: .default))
                        .foregroundStyle(Color.oasisRed)
                        .oasisCard()
                }

                if let order = viewModel.createdOrder {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Order Confirmed")
                            .font(.system(size: 16, weight: .semibold, design: .default))
                            .foregroundStyle(Color.oasisJungleGreen)

                        Text(order.orderNumber)
                            .font(.system(size: 32, weight: .black, design: .default))
                            .foregroundStyle(Color.oasisInk)

                        Text(viewModel.customerName.uppercased())
                            .font(.system(size: 20, weight: .bold, design: .default))

                        Text("Estimated total: \(order.estimatedTotalCents.usd)")
                            .font(.system(size: 15, weight: .medium, design: .default))
                            .foregroundStyle(Color.oasisMutedInk)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .oasisCard()
                }
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .task {
            await viewModel.loadSlots(apiClient: apiClient)
        }
        .navigationBarTitleDisplayMode(.inline)
        .animation(.easeInOut(duration: 0.22), value: viewModel.createdOrder?.orderId)
        .animation(.easeInOut(duration: 0.22), value: viewModel.errorMessage)
    }
}
