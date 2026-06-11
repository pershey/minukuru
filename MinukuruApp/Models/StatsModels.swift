import Foundation

struct ModeProgressSummary: Identifiable {
    var id: GameMode { mode }
    let mode: GameMode
    let answeredCount: Int
    let totalCount: Int
    let perfectCount: Int

    var progressText: String {
        "\(answeredCount)/\(totalCount)問"
    }
}

struct RecentResultSummary: Identifiable {
    let id = UUID()
    let title: String
    let modeTitle: String
    let score: Int
    let answeredAt: Date
    let wasPerfect: Bool
}
