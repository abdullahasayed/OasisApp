import SwiftUI

struct CheckoutView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var apiClient: ApiClient
    @StateObject private var viewModel = CheckoutViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Checkout")
                        .font(.system(size: 28, weight: .black, design: .default))
                        .foregroundStyle(Color.oasisInk)
                    Text("Pickup orders require full name and phone.")
                        .font(.system(size: 14, weight: .medium, design: .default))
                        .foregroundStyle(Color.oasisMutedInk)
                    HStack(spacing: 10) {
                        OasisStatusBadge(title: "\(appState.cartItems.count) Line Items", tint: .oasisRoyalBlue)
                        OasisStatusBadge(title: appState.estimatedCartTotalCents.usd, tint: .oasisJungleGreen)
                    }
                }
                .oasisCard(prominence: 1.2)

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
                .oasisCard(prominence: 1.05)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Pickup Slot")
                        .font(.system(size: 16, weight: .semibold, design: .default))

                    if viewModel.availableSlots.isEmpty {
                        Text("No available slots")
                            .font(.system(size: 14, weight: .medium, design: .default))
                            .foregroundStyle(Color.oasisMutedInk)
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(viewModel.selectedSlot?.displayLabel ?? "Select pickup window")
                                .font(.system(size: 13, weight: .semibold, design: .default))
                                .foregroundStyle(Color.oasisRoyalBlue)

                            ForEach(groupedSlots, id: \.dayKey) { dayGroup in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(dayGroup.dayTitle)
                                        .font(.system(size: 13, weight: .bold, design: .default))
                                        .foregroundStyle(Color.oasisMutedInk)

                                    ForEach(dayGroup.slots) { slot in
                                        Button {
                                            viewModel.selectedSlot = slot
                                        } label: {
                                            HStack {
                                                Text(slot.hourRangeLabel)
                                                    .font(.system(size: 14, weight: .semibold, design: .default))
                                                Spacer()
                                                if viewModel.selectedSlot?.id == slot.id {
                                                    Image(systemName: "checkmark.circle.fill")
                                                        .foregroundStyle(Color.oasisJungleGreen)
                                                }
                                            }
                                            .foregroundStyle(Color.oasisInk)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 10)
                                            .background(
                                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                    .fill(
                                                        viewModel.selectedSlot?.id == slot.id
                                                            ? Color.oasisJungleGreen.opacity(0.14)
                                                            : Color.white.opacity(0.86)
                                                    )
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                            .stroke(
                                                                viewModel.selectedSlot?.id == slot.id
                                                                    ? Color.oasisJungleGreen.opacity(0.35)
                                                                    : Color.oasisRoyalBlue.opacity(0.22),
                                                                lineWidth: 1
                                                            )
                                                    )
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                }
                .oasisCard(prominence: 1.05)

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
                        .oasisCard(prominence: 1.05)
                }

                if let order = viewModel.createdOrder {
                    VStack(alignment: .leading, spacing: 10) {
                        OasisStatusBadge(title: "Order Confirmed", tint: .oasisJungleGreen)

                        Text(order.orderNumber)
                            .font(.system(size: 34, weight: .black, design: .default))
                            .foregroundStyle(Color.oasisRed)

                        Text(viewModel.customerName.uppercased())
                            .font(.system(size: 20, weight: .bold, design: .default))
                            .foregroundStyle(Color.oasisInk)

                        Text("Estimated total: \(order.estimatedTotalCents.usd)")
                            .font(.system(size: 15, weight: .medium, design: .default))
                            .foregroundStyle(Color.oasisMutedInk)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .oasisCard(prominence: 1.25)
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

    private var groupedSlots: [(dayKey: String, dayTitle: String, slots: [PickupSlot])] {
        let grouped = Dictionary(grouping: viewModel.availableSlots) { $0.dayKey }
        return grouped.keys.sorted().map { key in
            (
                dayKey: key,
                dayTitle: OasisDateText.dayHeader(for: key),
                slots: grouped[key] ?? []
            )
        }
    }
}
