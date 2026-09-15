import XCTest

final class LearningFlowUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTestingResetState"]
        app.launch()
    }

    func testExampleExplanationAndResumeFlow() throws {
        let startButton = app.buttons["はじめる"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 5))
        startButton.tap()

        let recommendedPractice = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "おすすめの練習")
        ).firstMatch
        XCTAssertTrue(recommendedPractice.waitForExistence(timeout: 5))
        recommendedPractice.tap()

        let exampleAnswer = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "お手本の答えを見る")
        ).firstMatch
        XCTAssertTrue(exampleAnswer.waitForExistence(timeout: 5))
        let readButton = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "読み上げる")).firstMatch
        XCTAssertTrue(readButton.exists)
        readButton.tap()
        let stopButton = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "停止")).firstMatch
        XCTAssertTrue(stopButton.waitForExistence(timeout: 5))
        stopButton.tap()
        XCTAssertTrue(
            app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "もう一度聞く"))
                .firstMatch
                .waitForExistence(timeout: 5)
        )
        exampleAnswer.tap()

        XCTAssertTrue(app.staticTexts["元の文章"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["1. どこに注目する？"].exists)
        XCTAssertTrue(app.staticTexts["2. なぜ気をつける？"].exists)
        XCTAssertTrue(app.staticTexts["3. 次にどうする？"].exists)
        keepScreenshot(named: "learning-result")

        let nextButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "同じテーマの次へ")
        ).firstMatch
        XCTAssertTrue(nextButton.exists)
        nextButton.tap()

        XCTAssertTrue(app.staticTexts["ステップ1 文章を読む"].waitForExistence(timeout: 5))
        app.terminate()
        app.launchArguments = []
        app.launch()
        XCTAssertTrue(app.buttons["はじめる"].waitForExistence(timeout: 5))
        app.buttons["はじめる"].tap()

        let resumeButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "続きから")
        ).firstMatch
        XCTAssertTrue(resumeButton.waitForExistence(timeout: 5))
        resumeButton.tap()
        XCTAssertTrue(app.staticTexts["ステップ1 文章を読む"].waitForExistence(timeout: 5))
        keepScreenshot(named: "resumed-question")
    }

    private func keepScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
