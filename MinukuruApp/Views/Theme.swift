import SwiftUI

enum MinukuruTheme {
    static let background = LinearGradient(
        colors: [
            Color(red: 1.00, green: 0.97, blue: 0.95),
            Color(red: 0.98, green: 0.95, blue: 0.91),
            Color(red: 0.94, green: 0.97, blue: 0.95)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let card = Color.white.opacity(0.94)
    static let panel = Color(red: 0.98, green: 0.96, blue: 0.92)
    static let primary = Color(red: 0.09, green: 0.20, blue: 0.36)
    static let accent = Color(red: 1.00, green: 0.42, blue: 0.34)
    static let accentSoft = Color(red: 1.00, green: 0.90, blue: 0.86)
    static let success = Color(red: 0.25, green: 0.53, blue: 0.39)
    static let muted = Color(red: 0.33, green: 0.40, blue: 0.50)
    static let stroke = Color(red: 0.85, green: 0.87, blue: 0.91)

    static func modeAccent(_ mode: GameMode) -> Color {
        switch mode {
        case .explanationSnipe:
            return Color(red: 0.93, green: 0.50, blue: 0.31)
        case .newsPoison:
            return Color(red: 0.16, green: 0.39, blue: 0.70)
        case .scamAdChecker:
            return Color(red: 0.97, green: 0.42, blue: 0.34)
        case .profileHunter:
            return Color(red: 0.41, green: 0.45, blue: 0.76)
        case .conspiracyTrap:
            return Color(red: 0.27, green: 0.57, blue: 0.52)
        }
    }

    static func modeSoft(_ mode: GameMode) -> Color {
        switch mode {
        case .explanationSnipe:
            return Color(red: 0.99, green: 0.93, blue: 0.86)
        case .newsPoison:
            return Color(red: 0.89, green: 0.94, blue: 0.99)
        case .scamAdChecker:
            return Color(red: 0.99, green: 0.90, blue: 0.88)
        case .profileHunter:
            return Color(red: 0.91, green: 0.92, blue: 0.99)
        case .conspiracyTrap:
            return Color(red: 0.89, green: 0.96, blue: 0.93)
        }
    }
}
