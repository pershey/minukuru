import Foundation

struct AppSettings: Codable, Hashable {
    var isHiraganaMode: Bool = false
    var isSkipAnsweredEnabled: Bool = false
    var isRealityModeEnabled: Bool = false

    init(
        isHiraganaMode: Bool = false,
        isSkipAnsweredEnabled: Bool = false,
        isRealityModeEnabled: Bool = false
    ) {
        self.isHiraganaMode = isHiraganaMode
        self.isSkipAnsweredEnabled = isSkipAnsweredEnabled
        self.isRealityModeEnabled = isRealityModeEnabled
    }
}
