import XCTest

final class PatchworkUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }

    func testAuthFlowEntry() throws {
        let getStarted = app.buttons["Auth.getStartedButton"]
        XCTAssertTrue(getStarted.waitForExistence(timeout: 5))
        getStarted.tap()

        let skipButton = app.buttons["Auth.onboardingSkipButton"]
        XCTAssertTrue(skipButton.waitForExistence(timeout: 5))
        skipButton.tap()

        let emailSignIn = app.buttons["Auth.emailSignInButton"]
        XCTAssertTrue(emailSignIn.waitForExistence(timeout: 5))
        emailSignIn.tap()

        let emailField = app.textFields["Auth.emailField"]
        XCTAssertTrue(emailField.waitForExistence(timeout: 5))
    }

    func testAccessibilitySelectorsPresent() throws {
        XCTAssertTrue(app.buttons["Auth.getStartedButton"].waitForExistence(timeout: 5))
        app.buttons["Auth.getStartedButton"].tap()

        XCTAssertTrue(app.buttons["Auth.onboardingSkipButton"].waitForExistence(timeout: 5))
        app.buttons["Auth.onboardingSkipButton"].tap()

        XCTAssertTrue(app.buttons["Auth.emailSignInButton"].waitForExistence(timeout: 5))
        app.buttons["Auth.emailSignInButton"].tap()

        XCTAssertTrue(app.textFields["Auth.emailField"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Auth.sendCodeButton"].exists)
    }

    func testCaptureScreenshotsForParityReview() throws {
        let screenshotDir = URL(fileURLWithPath: "/tmp/patchwork-parity", isDirectory: true)
        try? FileManager.default.createDirectory(at: screenshotDir, withIntermediateDirectories: true)

        XCTAssertTrue(app.buttons["Auth.getStartedButton"].waitForExistence(timeout: 5))
        saveScreenshot(named: "ios-auth-splash")

        app.buttons["Auth.getStartedButton"].tap()
        XCTAssertTrue(app.buttons["Auth.onboardingContinueButton"].waitForExistence(timeout: 5))
        saveScreenshot(named: "ios-auth-onboarding-1")

        app.buttons["Auth.onboardingContinueButton"].tap()
        XCTAssertTrue(app.buttons["Auth.onboardingContinueButton"].waitForExistence(timeout: 5))
        saveScreenshot(named: "ios-auth-onboarding-2")

        XCTAssertTrue(app.buttons["Auth.onboardingSkipButton"].waitForExistence(timeout: 5))
        app.buttons["Auth.onboardingSkipButton"].tap()

        XCTAssertTrue(app.buttons["Auth.emailSignInButton"].waitForExistence(timeout: 5))
        saveScreenshot(named: "ios-auth-signin")
        app.buttons["Auth.emailSignInButton"].tap()

        XCTAssertTrue(app.textFields["Auth.emailField"].waitForExistence(timeout: 5))
        saveScreenshot(named: "ios-auth-email-entry")
    }

    private func saveScreenshot(named name: String) {
        let image = XCUIScreen.main.screenshot().image
        guard let data = image.pngData() else { return }
        let path = "/tmp/patchwork-parity/\(name).png"
        try? data.write(to: URL(fileURLWithPath: path), options: .atomic)
    }
}
