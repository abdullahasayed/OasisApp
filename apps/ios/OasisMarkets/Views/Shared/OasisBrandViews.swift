import SwiftUI

struct OasisWordmarkView: View {
    var compact: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 2 : 4) {
            Text("OASIS")
                .font(.system(size: compact ? 26 : 36, weight: .black, design: .default))
                .kerning(compact ? 1.6 : 2.1)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.oasisRed, .oasisRed.opacity(0.8), .oasisRoyalBlue.opacity(0.86)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

            HStack(spacing: 6) {
                Text("International")
                    .foregroundStyle(Color.oasisJungleGreen)
                Text("Market")
                    .foregroundStyle(Color.oasisRoyalBlue)
            }
            .font(.system(size: compact ? 14 : 16, weight: .semibold, design: .default))
        }
        .padding(.vertical, compact ? 2 : 0)
        .textCase(.none)
    }
}

struct OasisModeToggle: View {
    let isShopperMode: Bool
    let onSelect: (AppMode) -> Void

    var body: some View {
        HStack(spacing: 10) {
            modeButton(
                title: "Shopper",
                symbol: "bag.fill",
                mode: .shopper,
                isSelected: isShopperMode
            )

            modeButton(
                title: "Admin",
                symbol: "person.crop.rectangle.stack.fill",
                mode: .admin,
                isSelected: !isShopperMode
            )
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.82))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.oasisRoyalBlue.opacity(0.20), lineWidth: 1)
                )
        )
    }

    private func modeButton(
        title: String,
        symbol: String,
        mode: AppMode,
        isSelected: Bool
    ) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                onSelect(mode)
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                Text(title)
            }
            .font(.system(size: 14, weight: .semibold, design: .default))
            .foregroundStyle(isSelected ? Color.white : Color.oasisInk)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        isSelected
                            ? LinearGradient(
                                colors: [.oasisRed, .oasisRoyalBlue, .oasisJungleGreen.opacity(0.85)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            : LinearGradient(
                                colors: [Color.white.opacity(0.86), Color.white.opacity(0.86)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                    )
            )
            .shadow(
                color: isSelected ? Color.oasisRoyalBlue.opacity(0.22) : Color.clear,
                radius: 8,
                x: 0,
                y: 4
            )
        }
        .buttonStyle(.plain)
    }
}

struct OasisStatusBadge: View {
    let title: String
    let tint: Color

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(tint)
                .frame(width: 7, height: 7)
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .default))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(tint.opacity(0.12))
                .overlay(
                    Capsule()
                        .stroke(tint.opacity(0.18), lineWidth: 1)
                )
        )
    }
}
