import SwiftUI

struct AdminPickupAvailabilityView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var apiClient: ApiClient
    @StateObject private var viewModel = AdminPickupAvailabilityViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Pickup Availability")
                        .font(.system(size: 24, weight: .black, design: .default))
                        .foregroundStyle(Color.oasisInk)
                    Text("Manage hour ranges and block individual slots for today and tomorrow.")
                        .font(.system(size: 14, weight: .medium, design: .default))
                        .foregroundStyle(Color.oasisMutedInk)
                }
                .oasisCard(prominence: 1.2)

                if viewModel.isLoading {
                    ProgressView("Loading pickup availability...")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 30)
                        .oasisCard(prominence: 1.05)
                } else if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.system(size: 14, weight: .semibold, design: .default))
                        .foregroundStyle(Color.oasisRed)
                        .oasisCard(prominence: 1.05)
                } else {
                    LazyVStack(spacing: 14) {
                        ForEach(viewModel.days) { day in
                            PickupDayCard(
                                day: day,
                                isSaving: viewModel.isSaving,
                                onUpdateRange: { openHour, closeHour in
                                    Task {
                                        await viewModel.updateRange(
                                            date: day.date,
                                            openHour: openHour,
                                            closeHour: closeHour,
                                            apiClient: apiClient,
                                            token: appState.adminAccessToken
                                        )
                                    }
                                },
                                onToggleSlot: { slot in
                                    Task {
                                        await viewModel.toggleSlot(
                                            slotStartIso: slot.startIso,
                                            unavailable: !slot.isUnavailable,
                                            apiClient: apiClient,
                                            token: appState.adminAccessToken
                                        )
                                    }
                                }
                            )
                        }
                    }
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

private struct PickupDayCard: View {
    let day: AdminPickupDay
    let isSaving: Bool
    let onUpdateRange: (Int, Int) -> Void
    let onToggleSlot: (AdminPickupSlot) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(day.title)
                    .font(.system(size: 18, weight: .bold, design: .default))
                    .foregroundStyle(Color.oasisInk)
                Spacer()
                OasisStatusBadge(
                    title: "\(day.slots.filter { !$0.isUnavailable }.count) Active Slots",
                    tint: .oasisRoyalBlue
                )
            }

            HStack(spacing: 10) {
                hourMenu(
                    title: "Open",
                    value: day.openHour,
                    options: Array(0...23),
                    action: { newOpen in
                        if newOpen < day.closeHour {
                            onUpdateRange(newOpen, day.closeHour)
                        }
                    }
                )

                hourMenu(
                    title: "Close",
                    value: day.closeHour,
                    options: Array((day.openHour + 1)...24),
                    action: { newClose in
                        onUpdateRange(day.openHour, newClose)
                    }
                )
            }

            if isSaving {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 6)
            }

            VStack(spacing: 8) {
                ForEach(day.slots) { slot in
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(slot.hourRangeLabel)
                                .font(.system(size: 14, weight: .semibold, design: .default))
                                .foregroundStyle(Color.oasisInk)
                            Text("Booked \(slot.booked)/\(slot.capacity) • Available \(slot.available)")
                                .font(.system(size: 12, weight: .medium, design: .default))
                                .foregroundStyle(Color.oasisMutedInk)
                        }

                        Spacer()

                        Button {
                            onToggleSlot(slot)
                        } label: {
                            Text(slot.isUnavailable ? "Unblock" : "Block")
                        }
                        .buttonStyle(OasisSecondaryButtonStyle())

                        Image(systemName: slot.isUnavailable ? "xmark.octagon.fill" : "checkmark.circle.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(slot.isUnavailable ? Color.oasisRed : Color.oasisJungleGreen)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(
                                slot.isUnavailable
                                    ? Color.oasisRed.opacity(0.06)
                                    : Color.oasisJungleGreen.opacity(0.06)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(
                                        slot.isUnavailable
                                            ? Color.oasisRed.opacity(0.22)
                                            : Color.oasisJungleGreen.opacity(0.22),
                                        lineWidth: 1
                                    )
                            )
                    )
                }
            }
        }
        .oasisCard(prominence: 1.1)
    }

    private func hourMenu(
        title: String,
        value: Int,
        options: [Int],
        action: @escaping (Int) -> Void
    ) -> some View {
        Menu {
            ForEach(options, id: \.self) { hour in
                Button("\(hourLabel(hour))") {
                    action(hour)
                }
            }
        } label: {
            HStack {
                Text("\(title): \(hourLabel(value))")
                    .font(.system(size: 13, weight: .semibold, design: .default))
                    .foregroundStyle(Color.oasisInk)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.oasisMutedInk)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.oasisRoyalBlue.opacity(0.25), lineWidth: 1)
                    )
            )
        }
    }

    private func hourLabel(_ hour: Int) -> String {
        let normalized = hour % 24
        let suffix = normalized >= 12 ? "PM" : "AM"
        let hour12 = normalized % 12 == 0 ? 12 : normalized % 12
        return "\(hour12):00 \(suffix)"
    }
}
