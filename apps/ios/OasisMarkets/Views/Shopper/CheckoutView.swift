import SwiftUI

struct CheckoutView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var apiClient: ApiClient
    @StateObject private var viewModel = CheckoutViewModel()

    var body: some View {
        Form {
            Section("Customer") {
                TextField("Full Name", text: $viewModel.customerName)
                TextField("Phone", text: $viewModel.customerPhone)
                    .keyboardType(.phonePad)
            }

            Section("Pickup Slot") {
                if viewModel.availableSlots.isEmpty {
                    Text("No available slots")
                        .foregroundStyle(.secondary)
                } else {
                    Picker("Select Slot", selection: $viewModel.selectedSlot) {
                        ForEach(viewModel.availableSlots) { slot in
                            Text("\(slot.startIso) (\(slot.available) available)")
                                .tag(PickupSlot?.some(slot))
                        }
                    }
                }
            }

            Section {
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
                    } else {
                        Text("Place Pickup Order")
                    }
                }
                .disabled(viewModel.isSubmitting || appState.cartItems.isEmpty)
            }

            if let error = viewModel.errorMessage {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                }
            }

            if let order = viewModel.createdOrder {
                Section("Order Confirmed") {
                    Text(order.orderNumber)
                        .font(.largeTitle.bold())
                    Text(viewModel.customerName.uppercased())
                        .font(.title2)
                    Text("Estimated total: \(order.estimatedTotalCents.usd)")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Checkout")
        .task {
            await viewModel.loadSlots(apiClient: apiClient)
        }
    }
}
