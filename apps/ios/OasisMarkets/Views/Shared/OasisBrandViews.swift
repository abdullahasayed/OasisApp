import SwiftUI

struct OasisWordmarkView: View {
    var compact: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 2 : 4) {
            Text("OASIS")
                .font(.system(size: compact ? 26 : 36, weight: .black, design: .default))
                .kerning(1.8)
                .foregroundStyle(Color.oasisRed)

            HStack(spacing: 6) {
                Text("International")
                    .foregroundStyle(Color.oasisJungleGreen)
                Text("Market")
                    .foregroundStyle(Color.oasisRoyalBlue)
            }
            .font(.system(size: compact ? 14 : 16, weight: .semibold, design: .default))
        }
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
                                colors: [.oasisRed, .oasisRoyalBlue],
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
        }
        .buttonStyle(.plain)
    }
}

struct OasisStatusBadge: View {
    let title: String
    let tint: Color

    var body: some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold, design: .default))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(tint.opacity(0.12))
            )
    }
}
