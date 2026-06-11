import SwiftUI

enum MinukuruTheme {
    static let background = LinearGradient(
        colors: [Color(red: 0.98, green: 0.96, blue: 0.92), Color(red: 0.96, green: 0.91, blue: 0.82)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let card = Color.white.opacity(0.94)
    static let panel = Color(red: 0.99, green: 0.97, blue: 0.94)
    static let primary = Color(red: 0.46, green: 0.27, blue: 0.10)
    static let accent = Color(red: 0.89, green: 0.67, blue: 0.20)
    static let accentSoft = Color(red: 0.98, green: 0.91, blue: 0.73)
    static let success = Color(red: 0.28, green: 0.54, blue: 0.30)
    static let muted = Color(red: 0.44, green: 0.36, blue: 0.28)
    static let stroke = Color(red: 0.86, green: 0.77, blue: 0.62)
}
