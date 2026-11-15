import XCTest

final class LearningFlowUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTestingResetState"]
        app.launch()
    }

    func testStarterExplanationAndResumeFlow() throws {
        let startButton = app.buttons["はじめる"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 5))
        startButton.tap()

        let recommendedPractice = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "おすすめの練習")
        ).firstMatch
        XCTAssertTrue(recommendedPractice.waitForExistence(timeout: 5))
        recommendedPractice.tap()

        XCTAssertTrue(app.staticTexts["広告と注文の条件"].waitForExistence(timeout: 5))
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
        tapAfterScrolling(app.buttons["送料込みで合計980円。次の請求はない。"])
        tapAfterScrolling(app.buttons["答えを見る"])

        XCTAssertTrue(app.staticTexts["元の文章"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["1. どこに注目する？"].exists)
        XCTAssertTrue(app.staticTexts["2. なぜ気をつける？"].exists)
        XCTAssertTrue(app.staticTexts["3. 次にどうする？"].exists)
        keepScreenshot(named: "learning-result")

        let feedback = app.buttons["question-feedback"]
        for _ in 0..<4 where !feedback.isHittable { app.swipeUp() }
        XCTAssertTrue(feedback.isHittable)
        feedback.tap()
        XCTAssertTrue(app.navigationBars["気づいたことを伝える"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "問題ID:")).firstMatch.exists)
        keepScreenshot(named: "question-feedback-preview")
        app.buttons["閉じる"].tap()

        let nextButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "次の練習へ")
        ).firstMatch
        tapAfterScrolling(nextButton)

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
        tapAfterScrolling(resumeButton)
        XCTAssertTrue(app.staticTexts["ステップ1 文章を読む"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["お試し価格の続き"].exists)
        keepScreenshot(named: "resumed-question")
    }

    func testStarterShowsThreeDecisionsWithoutAds() throws {
        app.buttons["はじめる"].tap()
        let practice = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "おすすめの練習")).firstMatch
        XCTAssertTrue(practice.waitForExistence(timeout: 5))
        practice.tap()

        XCTAssertTrue(app.staticTexts["広告と注文の条件"].waitForExistence(timeout: 5))
        keepScreenshot(named: "store-01-question")
        tapAfterScrolling(app.buttons["送料込みで合計980円。次の請求はない。"])
        tapAfterScrolling(app.buttons["答えを見る"])
        XCTAssertTrue(app.staticTexts["答えが合っています"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.otherElements["result-ad-slot"].exists)
        tapAfterScrolling(app.buttons["次の練習へ"])

        XCTAssertTrue(app.staticTexts["お試し価格の続き"].waitForExistence(timeout: 5))
        tapAfterScrolling(app.buttons["次の請求について書いていないので、まだ分からない。"])
        tapAfterScrolling(app.buttons["答えを見る"])
        XCTAssertTrue(app.staticTexts["答えが合っています"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.otherElements["result-ad-slot"].exists)
        tapAfterScrolling(app.buttons["次の練習へ"])

        XCTAssertTrue(app.staticTexts["注文画面と広告の違い"].waitForExistence(timeout: 5))
        tapAfterScrolling(app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "次の商品は自動では届きません")).firstMatch)
        tapAfterScrolling(app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "商品は毎月自動で届きます")).firstMatch)
        XCTAssertTrue(app.staticTexts["選択数 2個"].exists)
        keepScreenshot(named: "store-02-evidence")
        tapAfterScrolling(app.buttons["答えを見る"])
        XCTAssertTrue(app.staticTexts["答えが合っています"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.otherElements["result-ad-slot"].exists)
        let explanation = app.staticTexts["3. 次にどうする？"]
        for _ in 0..<6 where !explanation.isHittable || explanation.frame.maxY > app.frame.maxY - 100 {
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.67))
            let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.46))
            start.press(forDuration: 0.06, thenDragTo: end)
        }
        XCTAssertTrue(explanation.isHittable)
        keepScreenshot(named: "store-03-explanation")
    }

    private func tapAfterScrolling(_ element: XCUIElement) {
        func comfortablyVisible() -> Bool {
            element.isHittable && element.frame.midY > app.frame.minY + 84
                && element.frame.midY < app.frame.maxY - 64
        }
        for _ in 0..<6 where !comfortablyVisible() {
            let shouldScrollBack = element.exists && element.frame.midY < app.frame.minY + 84
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: shouldScrollBack ? 0.45 : 0.70))
            let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: shouldScrollBack ? 0.70 : 0.45))
            start.press(forDuration: 0.07, thenDragTo: end)
        }
        XCTAssertTrue(comfortablyVisible(), "表示できない操作: \(element.description)")
        element.tap()
    }

    private func keepScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
