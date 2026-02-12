import SwiftUI

extension Color {
    static let oasisRed = Color(red: 0.92, green: 0.07, blue: 0.07)
    static let oasisJungleGreen = Color(red: 0.12, green: 0.50, blue: 0.35)
    static let oasisRoyalBlue = Color(red: 0.25, green: 0.41, blue: 0.88)
    static let oasisCream = Color(red: 0.97, green: 0.98, blue: 0.96)
    static let oasisPaper = Color.white
    static let oasisInk = Color(red: 0.10, green: 0.12, blue: 0.16)
    static let oasisMutedInk = Color(red: 0.37, green: 0.40, blue: 0.46)
}

struct OasisBackgroundView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.oasisCream, .white, Color.oasisRoyalBlue.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color.oasisRed.opacity(0.14))
                .frame(width: 280, height: 280)
                .blur(radius: 12)
                .offset(x: 140, y: -320)

            Circle()
                .fill(Color.oasisJungleGreen.opacity(0.16))
                .frame(width: 320, height: 320)
                .blur(radius: 14)
                .offset(x: -160, y: 280)

            RoundedRectangle(cornerRadius: 48, style: .continuous)
                .fill(Color.oasisRoyalBlue.opacity(0.10))
                .frame(width: 300, height: 140)
                .blur(radius: 10)
                .rotationEffect(.degrees(-15))
                .offset(x: 120, y: 340)
        }
    }
}

struct OasisCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.oasisPaper.opacity(0.94))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.oasisRoyalBlue.opacity(0.08), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
            )
    }
}

extension View {
    func oasisCard() -> some View {
        modifier(OasisCardModifier())
    }

    func oasisInputField() -> some View {
        padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.95))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.oasisRoyalBlue.opacity(0.18), lineWidth: 1)
                    )
            )
    }
}

struct OasisPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold, design: .default))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    colors: [.oasisRed, .oasisRoyalBlue],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.92 : 1)
    }
}

struct OasisSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold, design: .default))
            .foregroundStyle(Color.oasisInk)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.9))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.oasisRoyalBlue.opacity(0.22), lineWidth: 1)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct OasisCategoryPill: View {
    let title: String
    let isSelected: Bool

    var body: some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold, design: .default))
            .foregroundStyle(isSelected ? .white : Color.oasisInk)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(
                        isSelected
                            ? LinearGradient(
                                colors: [.oasisJungleGreen, .oasisRoyalBlue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            : LinearGradient(
                                colors: [Color.white.opacity(0.9), Color.white.opacity(0.9)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                    )
                    .overlay(
                        Capsule()
                            .stroke(
                                isSelected ? Color.clear : Color.oasisRoyalBlue.opacity(0.2),
                                lineWidth: 1
                            )
                    )
            )
    }
}

extension ProductCategory {
    var categoryTint: Color {
        switch self {
        case .halalMeat:
            return .oasisRed
        case .fruits:
            return .oasisRoyalBlue
        case .vegetables:
            return .oasisJungleGreen
        case .groceryOther:
            return .oasisRoyalBlue.opacity(0.75)
        }
    }

    var symbolName: String {
        switch self {
        case .halalMeat:
            return "fork.knife.circle.fill"
        case .fruits:
            return "apple.logo"
        case .vegetables:
            return "leaf.circle.fill"
        case .groceryOther:
            return "basket.fill"
        }
    }
}

extension OrderStatus {
    var statusTint: Color {
        switch self {
        case .placed:
            return .oasisRoyalBlue
        case .preparing:
            return .oasisJungleGreen
        case .ready:
            return .oasisJungleGreen
        case .fulfilled:
            return .oasisJungleGreen
        case .delayed:
            return .orange
        case .cancelled:
            return .oasisRed
        case .refunded:
            return .oasisRed
        }
    }
}

enum OasisDateText {
    private static let fullDateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private static let isoWithFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let isoStandard: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static func parseISO(_ value: String) -> Date? {
        isoWithFractional.date(from: value) ?? isoStandard.date(from: value)
    }

    static func pickupWindow(startISO: String, endISO: String) -> String {
        guard
            let start = parseISO(startISO),
            let end = parseISO(endISO)
        else {
            return "\(startISO) - \(endISO)"
        }

        return "\(fullDateTimeFormatter.string(from: start)) - \(fullDateTimeFormatter.string(from: end))"
    }

    static func pointInTime(_ value: String) -> String {
        guard let date = parseISO(value) else { return value }
        return fullDateTimeFormatter.string(from: date)
    }
}
