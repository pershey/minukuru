import XCTest
@testable import Minukuru

final class QuestionFeedbackTests: XCTestCase {
    func testMailPreservesJapaneseAndDoesNotInjectQueryFields() throws {
        let report = QuestionFeedback(questionID: "sample-1", contentRevision: 2, kind: .answer,
                                      note: "どちらも正しい？ &subject=別の件名\nもう一度確認してほしい", appVersion: "1.1", build: "13")
        let url = try XCTUnwrap(report.mailURL)
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        XCTAssertEqual(components.scheme, "mailto")
        XCTAssertEqual(components.path, QuestionFeedback.recipient)
        XCTAssertEqual(components.queryItems?.count, 2)
        XCTAssertEqual(components.queryItems?.first(where: { $0.name == "body" })?.value, report.message)
        XCTAssertTrue(report.message.contains("問題ID: sample-1"))
        XCTAssertTrue(report.message.contains("問題の版: 2"))
    }

    func testBlankNoteCanStillReportTheQuestionAndVersion() {
        let report = QuestionFeedback(questionID: "sample-2", contentRevision: 1, kind: .reading,
                                      note: "   \n", appVersion: "1.1", build: "13")
        XCTAssertTrue(report.message.contains("文字や読み方について"))
        XCTAssertTrue(report.message.contains("アプリ: 1.1 (13)"))
    }
}
