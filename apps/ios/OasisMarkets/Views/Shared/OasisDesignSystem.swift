import SwiftUI

extension Color {
    static let oasisRed = Color(red: 0.91, green: 0.08, blue: 0.08)
    static let oasisJungleGreen = Color(red: 0.06, green: 0.46, blue: 0.35)
    static let oasisRoyalBlue = Color(red: 0.25, green: 0.41, blue: 0.88)
    static let oasisCream = Color(red: 0.96, green: 0.97, blue: 0.95)
    static let oasisPaper = Color(red: 0.995, green: 0.997, blue: 1.0)
    static let oasisPaperTint = Color(red: 0.95, green: 0.97, blue: 1.0)
    static let oasisInk = Color(red: 0.08, green: 0.11, blue: 0.16)
    static let oasisMutedInk = Color(red: 0.34, green: 0.39, blue: 0.47)
}

struct OasisBackgroundView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.oasisCream,
                    Color.oasisPaper,
                    Color.oasisPaperTint.opacity(0.9)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            Circle()
                .fill(Color.oasisRed.opacity(0.17))
                .frame(width: 320, height: 320)
                .blur(radius: 22)
                .offset(x: 150, y: -330)

            Circle()
                .fill(Color.oasisJungleGreen.opacity(0.18))
                .frame(width: 350, height: 350)
                .blur(radius: 22)
                .offset(x: -170, y: 290)

            RoundedRectangle(cornerRadius: 48, style: .continuous)
                .fill(Color.oasisRoyalBlue.opacity(0.16))
                .frame(width: 340, height: 160)
                .blur(radius: 20)
                .rotationEffect(.degrees(-13))
                .offset(x: 130, y: 360)

            RoundedRectangle(cornerRadius: 42, style: .continuous)
                .fill(Color.oasisRoyalBlue.opacity(0.08))
                .frame(width: 300, height: 120)
                .blur(radius: 16)
                .rotationEffect(.degrees(8))
                .offset(x: -160, y: -300)
        }
    }
}

struct OasisCardModifier: ViewModifier {
    let prominence: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.oasisPaper.opacity(0.98),
                                Color.white.opacity(0.95)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.oasisRoyalBlue.opacity(0.20 * prominence),
                                        Color.oasisJungleGreen.opacity(0.12 * prominence),
                                        Color.oasisRed.opacity(0.08 * prominence)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: Color.black.opacity(0.07), radius: 16, x: 0, y: 9)
                    .shadow(color: Color.oasisRoyalBlue.opacity(0.08), radius: 22, x: 0, y: 12)
            )
    }
}

extension View {
    func oasisCard(prominence: CGFloat = 1) -> some View {
        modifier(OasisCardModifier(prominence: prominence))
    }

    func oasisInputField() -> some View {
        padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.98), Color.oasisPaperTint.opacity(0.45)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.oasisRoyalBlue.opacity(0.26), lineWidth: 1)
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
                    colors: [.oasisRed, .oasisRoyalBlue, .oasisJungleGreen],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.oasisRoyalBlue.opacity(0.35), radius: 10, x: 0, y: 5)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.90 : 1)
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
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.95), Color.oasisPaperTint.opacity(0.45)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.oasisRoyalBlue.opacity(0.26), lineWidth: 1)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
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
                                colors: [.oasisJungleGreen, .oasisRoyalBlue, .oasisRed.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            : LinearGradient(
                                colors: [
                                    Color.white.opacity(0.95),
                                    Color.oasisPaperTint.opacity(0.5)
                                ],
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
            .shadow(
                color: isSelected ? Color.oasisRoyalBlue.opacity(0.25) : Color.clear,
                radius: 6,
                x: 0,
                y: 3
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

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()

    private static let dayKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let dateInputFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let dayHeaderFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateStyle = .full
        formatter.timeStyle = .none
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

    static func hourRange(startISO: String, endISO: String) -> String {
        guard
            let start = parseISO(startISO),
            let end = parseISO(endISO)
        else {
            return "\(startISO) - \(endISO)"
        }

        return "\(timeFormatter.string(from: start)) - \(timeFormatter.string(from: end))"
    }

    static func dayKey(startISO: String) -> String {
        guard let date = parseISO(startISO) else { return startISO }
        return dayKeyFormatter.string(from: date)
    }

    static func dayHeader(for date: String) -> String {
        guard let day = dateInputFormatter.date(from: date) else {
            return date
        }

        let calendar = Calendar.current
        if calendar.isDateInToday(day) {
            return "Today"
        }
        if calendar.isDateInTomorrow(day) {
            return "Tomorrow"
        }
        return dayHeaderFormatter.string(from: day)
    }
}
