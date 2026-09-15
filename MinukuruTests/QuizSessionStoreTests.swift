import XCTest
@testable import Minukuru

final class QuizSessionStoreTests: XCTestCase {
    func testSnapshotRoundTripPreservesCurrentStepAndHelpUse() {
        let defaults = UserDefaults(suiteName: "MinukuruSessionTests-\(UUID().uuidString)")!
        let store = UserDefaultsQuizSessionStore(defaults: defaults)
        let snapshot = QuizSessionSnapshot(
            questionID: "core-child-practice-pause-01",
            phase: .reason,
            selectedSegmentIDs: ["s2"],
            selectedReasonTags: [.urgency],
            selectedChoiceID: nil,
            hintUsed: true,
            attemptNumber: 2,
            updatedAt: Date(timeIntervalSince1970: 1_800_000_000)
        )

        store.save(snapshot: snapshot)

        XCTAssertEqual(store.loadSnapshot(), snapshot)

        store.clearSnapshot()
        XCTAssertNil(store.loadSnapshot())
    }
}
