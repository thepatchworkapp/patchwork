import Foundation
import XCTest

final class PatchworkUITests: XCTestCase {
    private let testConvexCloudURL = "https://aware-meerkat-572.convex.cloud"
    private let testConvexSiteURL = "https://aware-meerkat-572.convex.site"
    private lazy var convexSiteURL = URL(string: testConvexSiteURL)!
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "PATCHWORK_UI_RESET_SESSION"]
        app.launchEnvironment["PATCHWORK_UI_RESET_SESSION_TOKEN"] = UUID().uuidString
        app.launchEnvironment["PATCHWORK_CONVEX_CLOUD_URL"] = testConvexCloudURL
        app.launchEnvironment["PATCHWORK_CONVEX_SITE_URL"] = testConvexSiteURL
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

    func testCreateAccountEntryRoutesToEmailFlow() throws {
        let getStarted = app.buttons["Auth.getStartedButton"]
        XCTAssertTrue(getStarted.waitForExistence(timeout: 5))
        getStarted.tap()

        let skipButton = app.buttons["Auth.onboardingSkipButton"]
        XCTAssertTrue(skipButton.waitForExistence(timeout: 5))
        skipButton.tap()

        let createAccountButton = app.buttons["Auth.createAccountButton"]
        XCTAssertTrue(createAccountButton.waitForExistence(timeout: 5))
        createAccountButton.tap()

        XCTAssertTrue(app.staticTexts["Create Account"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.textFields["Auth.emailField"].waitForExistence(timeout: 5))
    }

    func testAccessibilitySelectorsPresent() throws {
        XCTAssertTrue(app.buttons["Auth.getStartedButton"].waitForExistence(timeout: 5))
        app.buttons["Auth.getStartedButton"].tap()

        XCTAssertTrue(app.buttons["Auth.onboardingSkipButton"].waitForExistence(timeout: 5))
        app.buttons["Auth.onboardingSkipButton"].tap()

        XCTAssertTrue(app.buttons["Auth.emailSignInButton"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Auth.createAccountButton"].exists)
        app.buttons["Auth.emailSignInButton"].tap()

        XCTAssertTrue(app.textFields["Auth.emailField"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Auth.sendCodeButton"].exists)
    }

    func testAppReviewShortcutSignsInWithoutOTP() throws {
        launchToEmailEntry()

        let emailField = app.textFields["Auth.emailField"]
        replaceText(in: emailField, with: "review@apple.com")
        app.buttons["Auth.sendCodeButton"].tap()

        XCTAssertFalse(app.textFields["Auth.codeField.0"].waitForExistence(timeout: 3))
        dismissLocationPromptIfNeeded()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 20))
        XCTAssertTrue(tabButton(named: "Profile").exists)
    }

    func testInvalidOTPResetsCodeFieldsAndShowsActionableError() throws {
        let email = uniqueTestEmail(prefix: "ios-invalid-otp")
        cleanupTestData(for: email)

        launchToEmailEntry()

        let emailField = app.textFields["Auth.emailField"]
        replaceText(in: emailField, with: email)
        app.buttons["Auth.sendCodeButton"].tap()

        let firstCodeField = app.textFields["Auth.codeField.0"]
        XCTAssertTrue(firstCodeField.waitForExistence(timeout: 30))

        let validOTP = testOTP(for: email)
        let invalidOTP = validOTP == "000000" ? "111111" : "000000"
        enterOTP(invalidOTP)

        let otpFailureMessage = identifiedElement("Auth.otpFailureMessage")
        XCTAssertTrue(otpFailureMessage.waitForExistence(timeout: 15))
        XCTAssertTrue(otpFailureMessage.label.contains("That code didn't work"))

        for index in 0 ..< 6 {
            XCTAssertTrue(isEmptyTextField(app.textFields["Auth.codeField.\(index)"]))
        }

        app.typeText("1")
        XCTAssertEqual(textFieldValue(app.textFields["Auth.codeField.0"]), "1")
        XCTAssertTrue(isEmptyTextField(app.textFields["Auth.codeField.1"]))
    }

    func testEmailAuthCompletesProfileSetup() throws {
        let email = uniqueTestEmail(prefix: "ios-auth")
        cleanupTestData(for: email)

        launchToEmailEntry()
        completeEmailAuth(email: email)
        completeProfileSetup(name: "iOS Auth Tester", city: "Toronto", province: "ON", finishWithNotificationsAllow: true)

        XCTAssertTrue(tabButton(named: "Seek").waitForExistence(timeout: 10))
        XCTAssertTrue(tabButton(named: "Seek").isSelected)
        XCTAssertTrue(tabButton(named: "Messages").exists)
        XCTAssertFalse(app.textFields["TaskerOnboarding1.displayNameField"].exists)
        XCTAssertFalse(app.staticTexts["Tasker Setup"].exists)
    }

    func testFirstSignupIgnoresStaleTaskerOnboardingRoute() throws {
        app.terminate()
        app.launchArguments.append("PATCHWORK_UI_STALE_TASKER_ROUTE")
        app.launchEnvironment["PATCHWORK_UI_RESET_SESSION_TOKEN"] = UUID().uuidString
        app.launch()

        let email = uniqueTestEmail(prefix: "ios-stale-tasker-route")
        cleanupTestData(for: email)

        launchToEmailEntry()
        completeEmailAuth(email: email)
        completeProfileSetup(name: "Fresh Seeker", city: "Toronto", province: "ON", finishWithNotificationsAllow: true)

        XCTAssertTrue(tabButton(named: "Seek").waitForExistence(timeout: 10))
        XCTAssertTrue(tabButton(named: "Seek").isSelected)
        XCTAssertFalse(app.textFields["TaskerOnboarding1.displayNameField"].exists)
        XCTAssertFalse(app.staticTexts["Tasker Setup"].exists)
    }

    func testFirstSignupProfileSetupLandsOnSeekWithoutTaskerOnboarding() throws {
        let email = uniqueTestEmail(prefix: "ios-first-signup-routing")
        cleanupTestData(for: email)

        launchToEmailEntry()
        completeEmailAuth(email: email)
        completeProfileSetup(name: "First Signup Seeker", city: "Toronto", province: "ON")

        let seekTab = tabButton(named: "Seek")
        XCTAssertTrue(seekTab.waitForExistence(timeout: 10))
        XCTAssertTrue(seekTab.isSelected)
        XCTAssertTrue(app.buttons["Home.radiusButton"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.textFields["ProfileSetup.nameField"].exists)
        XCTAssertFalse(app.textFields["TaskerOnboarding1.displayNameField"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.buttons["TaskerOnboarding1.categoryPicker"].exists)
        XCTAssertFalse(app.buttons["TaskerOnboarding1.continueButton"].exists)
    }

    func testTaskerSubscriptionLifecycle() throws {
        let email = uniqueTestEmail(prefix: "ios-tasker")
        cleanupTestData(for: email)

        launchToEmailEntry()
        completeEmailAuth(email: email)
        completeProfileSetup(name: "iOS Tasker Tester", city: "Toronto", province: "ON")
        saveScreenshot(named: "ios-tasker-post-profile-setup")

        openProfileTab()
        let primaryAction = app.buttons["Profile.taskerOnboardingLink"]
        XCTAssertTrue(primaryAction.waitForExistence(timeout: 10))
        saveScreenshot(named: "ios-tasker-profile-tab")

        primaryAction.tap()
        completeTaskerOnboarding(
            displayName: "Local Tasker",
            categoryBio: "Professional, responsive, and ready for local Patchwork jobs.",
            hourlyRate: "60"
        )
        saveScreenshot(named: "ios-tasker-after-complete")

        XCTAssertTrue(identifiedElement("Subscription.customPaywall").waitForExistence(timeout: 20))

        if app.buttons["Close"].waitForExistence(timeout: 5) {
            app.buttons["Close"].tap()
        } else if app.buttons["Subscription.billingCloseButton"].exists {
            app.buttons["Subscription.billingCloseButton"].tap()
        }
        XCTAssertTrue(app.buttons["TaskerOnboarding5.doneButton"].waitForExistence(timeout: 10))
        app.buttons["TaskerOnboarding5.doneButton"].tap()

        let subscriptionLink = app.buttons["Profile.visibilitySubscriptionLink"]
        XCTAssertTrue(subscriptionLink.waitForExistence(timeout: 10))
        subscriptionLink.tap()

        XCTAssertTrue(identifiedElement("Subscription.customPaywall").waitForExistence(timeout: 20))
        saveScreenshot(named: "ios-tasker-paywall-profile")
    }

    func testBackgroundResumeDoesNotShowProfileSetupForAuthenticatedUser() throws {
        let email = uniqueTestEmail(prefix: "ios-resume")
        cleanupTestData(for: email)

        launchToEmailEntry()
        completeEmailAuth(email: email)
        completeProfileSetup(name: "Resume Tester", city: "Toronto", province: "ON")

        XCTAssertTrue(tabButton(named: "Profile").waitForExistence(timeout: 10))

        backgroundAndRestoreApp()

        XCTAssertTrue(tabButton(named: "Profile").waitForExistence(timeout: 10))
        XCTAssertFalse(app.textFields["ProfileSetup.nameField"].exists)

        Thread.sleep(forTimeInterval: 1)
        XCTAssertFalse(app.textFields["ProfileSetup.nameField"].exists)
    }

    func testProfileSetupDraftSurvivesBackgroundResume() throws {
        let email = uniqueTestEmail(prefix: "ios-profile-draft")
        cleanupTestData(for: email)

        launchToEmailEntry()
        completeEmailAuth(email: email)

        let name = "Draft Resume Tester"
        let city = "Toronto"
        let province = "ON"

        let nameField = app.textFields["ProfileSetup.nameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 30))
        replaceText(in: nameField, with: name, shouldClearExisting: false)
        dismissKeyboardIfPresent()

        let cityField = app.textFields["ProfileSetup.cityField"]
        replaceText(in: cityField, with: city)
        dismissKeyboardIfPresent()

        let provinceField = app.textFields["ProfileSetup.provinceField"]
        replaceText(in: provinceField, with: province)
        dismissKeyboardIfPresent()

        backgroundAndRestoreApp()

        XCTAssertTrue(app.textFields["ProfileSetup.nameField"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.textFields["ProfileSetup.nameField"].value as? String, name)
        XCTAssertEqual(app.textFields["ProfileSetup.cityField"].value as? String, city)
        XCTAssertEqual(app.textFields["ProfileSetup.provinceField"].value as? String, province)
    }

    func testTaskerOnboardingDraftSurvivesBackgroundResume() throws {
        let email = uniqueTestEmail(prefix: "ios-tasker-draft")
        cleanupTestData(for: email)

        launchToEmailEntry()
        completeEmailAuth(email: email)
        completeProfileSetup(name: "Tasker Draft Tester", city: "Toronto", province: "ON")

        openProfileTab()
        let primaryAction = app.buttons["Profile.taskerOnboardingLink"]
        XCTAssertTrue(primaryAction.waitForExistence(timeout: 10))
        primaryAction.tap()

        let displayName = "Unsaved Tasker Draft"
        let website = "https://draft-tasker.example"
        let social = "@drafttasker"

        let displayNameField = app.textFields["TaskerOnboarding1.displayNameField"]
        XCTAssertTrue(displayNameField.waitForExistence(timeout: 10))
        replaceText(in: displayNameField, with: displayName)

        app.buttons["TaskerOnboarding1.categoryPicker"].tap()
        let categoryRow = app.buttons["Categories.row.interior-cleaning-services"]
        XCTAssertTrue(categoryRow.waitForExistence(timeout: 10))
        categoryRow.tap()

        app.buttons["TaskerOnboarding1.continueButton"].tap()

        let websiteField = app.textFields["TaskerOnboarding2.websiteLinks.field.0"]
        XCTAssertTrue(websiteField.waitForExistence(timeout: 10))
        replaceText(in: websiteField, with: website)

        let socialField = app.textFields["TaskerOnboarding2.socialLinks.field.0"]
        XCTAssertTrue(socialField.waitForExistence(timeout: 10))
        replaceText(in: socialField, with: social)
        dismissKeyboardIfPresent()

        backgroundAndRestoreApp()

        XCTAssertTrue(app.textFields["TaskerOnboarding2.websiteLinks.field.0"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.textFields["TaskerOnboarding2.websiteLinks.field.0"].value as? String, website)
        XCTAssertEqual(app.textFields["TaskerOnboarding2.socialLinks.field.0"].value as? String, social)

        app.buttons["TaskerOnboarding2.backButton"].tap()
        XCTAssertEqual(app.textFields["TaskerOnboarding1.displayNameField"].value as? String, displayName)
        XCTAssertTrue(app.buttons["TaskerOnboarding1.categoryPicker"].label.contains("Interior Cleaning Services"))
    }

    func testTaskerProfileManagementPersistsDisplayNameAndCategoryEdits() throws {
        let taskerEmail = uniqueTestEmail(prefix: "ios-tasker-manage")
        let seekerEmail = uniqueTestEmail(prefix: "ios-seeker-manage")
        cleanupTestData(for: taskerEmail)
        cleanupTestData(for: seekerEmail)

        let initialDisplayName = "Managed Tasker"
        let updatedDisplayName = "Managed Tasker Pro"
        let updatedCategoryBio = "Detailed cabinet refinishing, trim painting, and touch-ups for busy households."
        let coordinateOffset = Double(Int(Date().timeIntervalSince1970) % 100) / 10_000
        let discoveryLat = 49.2827 + coordinateOffset
        let discoveryLng = -123.1207 - coordinateOffset

        launchToEmailEntry()
        completeEmailAuth(email: taskerEmail)
        completeProfileSetup(name: "Tasker Manager", city: "Toronto", province: "ON")

        openProfileTab()
        let primaryAction = app.buttons["Profile.taskerOnboardingLink"]
        XCTAssertTrue(primaryAction.waitForExistence(timeout: 10))
        primaryAction.tap()

        completeTaskerOnboarding(
            displayName: initialDisplayName,
            categoryBio: "Fast, reliable painting help for local Patchwork jobs.",
            hourlyRate: "60"
        )

        _ = app.otherElements["Subscription.customPaywall"].waitForExistence(timeout: 3)
        if app.buttons["Subscription.billingCloseButton"].waitForExistence(timeout: 5) {
            app.buttons["Subscription.billingCloseButton"].tap()
        } else if app.buttons["Close"].waitForExistence(timeout: 2) {
            app.buttons["Close"].tap()
        }

        XCTAssertTrue(app.buttons["TaskerOnboarding5.doneButton"].waitForExistence(timeout: 10))
        app.buttons["TaskerOnboarding5.doneButton"].tap()

        openTaskerProfileManagement()

        let displayNameField = app.textFields["TaskerProfile.displayNameField"]
        replaceText(in: displayNameField, with: updatedDisplayName)
        app.buttons["TaskerProfile.saveButton"].tap()

        XCTAssertTrue(app.descendants(matching: .any)["TaskerProfile.statusBanner"].waitForExistence(timeout: 10))
        XCTAssertTrue(waitForTaskerProfile(email: taskerEmail) { profile in
            (profile["displayName"] as? String) == updatedDisplayName
        })

        guard let profile: [String: Any] = testProxy(action: "getTaskerProfileByEmail", args: ["email": taskerEmail]),
              let taskerProfileId = profile["_id"] as? String,
              let categories = profile["categories"] as? [[String: Any]],
              let categoryId = categories.first?["categoryId"] as? String else {
            XCTFail("Missing tasker profile after management save")
            return
        }

        let categoryRow = app.buttons["TaskerProfile.category.\(categoryId)"]
        XCTAssertTrue(categoryRow.waitForExistence(timeout: 10))
        categoryRow.tap()

        let categoryBioField = app.textViews["TaskerProfileCategorySheet.bioField"]
        XCTAssertTrue(categoryBioField.waitForExistence(timeout: 10))
        replaceText(in: categoryBioField, with: updatedCategoryBio)
        dismissKeyboardIfPresent()

        let rateTypeControl = app.segmentedControls["TaskerProfileCategorySheet.rateTypePicker"]
        XCTAssertTrue(rateTypeControl.waitForExistence(timeout: 10))
        rateTypeControl.buttons["Fixed"].tap()
        dismissKeyboardIfPresent()

        let fixedRateField = app.textFields["TaskerProfileCategorySheet.fixedRateField"]
        XCTAssertTrue(fixedRateField.waitForExistence(timeout: 10))
        replaceText(in: fixedRateField, with: "145")

        let radiusIncrementButton = app.buttons["TaskerProfileCategorySheet.radiusIncrementButton"]
        XCTAssertTrue(radiusIncrementButton.waitForExistence(timeout: 10))
        for _ in 0 ..< 5 {
            radiusIncrementButton.tap()
        }

        app.buttons["TaskerProfile.categorySaveButton"].tap()

        XCTAssertTrue(waitForTaskerProfile(email: taskerEmail) { profile in
            guard let categories = profile["categories"] as? [[String: Any]],
                  let updatedCategory = categories.first(where: { ($0["categoryId"] as? String) == categoryId }) else {
                return false
            }

            return (updatedCategory["bio"] as? String) == updatedCategoryBio
                && (updatedCategory["rateType"] as? String) == "fixed"
                && (updatedCategory["fixedRate"] as? Int) == 14500
                && updatedCategory["hourlyRate"] == nil
                && (updatedCategory["serviceRadius"] as? Int) == 30
        })

        XCTAssertTrue(categoryRow.waitForExistence(timeout: 10))
        categoryRow.tap()

        XCTAssertEqual(categoryBioField.value as? String, updatedCategoryBio)
        XCTAssertEqual(fixedRateField.value as? String, "145.00")
        XCTAssertEqual(identifiedElement("TaskerProfileCategorySheet.radiusValue").label, "30 km")

        app.buttons["TaskerProfile.categoryCloseButton"].tap()

        let discoverableTasker = ensureDiscoverableTasker(
            email: taskerEmail,
            name: "Tasker Manager",
            displayName: updatedDisplayName,
            lat: discoveryLat,
            lng: discoveryLng,
            categoryBio: updatedCategoryBio,
            rateType: "fixed",
            hourlyRate: nil,
            fixedRate: 14500,
            serviceRadius: 30
        )
        XCTAssertEqual(discoverableTasker["taskerProfileId"] as? String, taskerProfileId)

        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        if backButton.waitForExistence(timeout: 5) {
            backButton.tap()
        }

        signOutToEmailEntry()
        completeEmailAuth(email: seekerEmail)
        completeProfileSetup(name: "Seeking Manager", city: "Toronto", province: "ON")
        setUserLocation(email: seekerEmail, lat: discoveryLat, lng: discoveryLng)
        app.terminate()
        app.launch()
        if !app.tabBars.firstMatch.waitForExistence(timeout: 5) {
            launchToEmailEntry()
            completeEmailAuth(email: seekerEmail)
        }
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 20))

        XCTAssertFalse(app.buttons["Home.layout.listButton"].exists)

        openDiscoverProfile(named: updatedDisplayName)

        XCTAssertTrue(app.staticTexts[updatedCategoryBio].waitForExistence(timeout: 20))
        let updatedRateMetric = app.otherElements["ProviderDetail.metric.fixed-rate"]
        if !updatedRateMetric.waitForExistence(timeout: 5) {
            app.swipeUp()
        }
        XCTAssertTrue(updatedRateMetric.waitForExistence(timeout: 20))
        XCTAssertTrue(
            updatedRateMetric.label.contains("145.00 flat"),
            "Expected edited fixed rate, got: \(updatedRateMetric.label)"
        )
    }

    func testSeekerDiscoveryStartsConversation() throws {
        let seekerEmail = uniqueTestEmail(prefix: "ios-seeker")
        let taskerEmail = uniqueTestEmail(prefix: "ios-visible-tasker")
        let displayName = "Nearby Cleaner \(Int(Date().timeIntervalSince1970))"
        cleanupTestData(for: seekerEmail)
        cleanupTestData(for: taskerEmail)

        let tasker = ensureDiscoverableTasker(
            email: taskerEmail,
            name: "Nearby Cleaner",
            displayName: displayName
        )
        let taskerProfileId = tasker["taskerProfileId"] as? String
        XCTAssertNotNil(taskerProfileId)

        launchToEmailEntry()
        completeEmailAuth(email: seekerEmail)
        completeProfileSetup(name: "Nearby Seeker", city: "Toronto", province: "ON")
        saveScreenshot(named: "ios-seeker-after-profile-setup")

        openSpotlightTaskerProfile()
        saveScreenshot(named: "ios-seeker-after-view-profile")

        startChatFromProviderDetail()
        saveScreenshot(named: "ios-seeker-after-start-chat")
        Thread.sleep(forTimeInterval: 3)
        saveScreenshot(named: "ios-seeker-after-start-chat-delay")

        let proposeTermsButton = app.buttons["Propose terms"]
        XCTAssertTrue(proposeTermsButton.waitForExistence(timeout: 10))
    }

    func testTaskerSendsProposal() throws {
        let seekerEmail = uniqueTestEmail(prefix: "ios-seeker-send-proposal")
        let taskerEmail = uniqueTestEmail(prefix: "ios-tasker-send-proposal")
        let taskerName = "Proposal Tasker \(Int(Date().timeIntervalSince1970))"
        let seekerName = "Proposal Seeker \(Int(Date().timeIntervalSince1970))"

        cleanupTestData(for: seekerEmail)
        cleanupTestData(for: taskerEmail)

        launchToEmailEntry()
        completeEmailAuth(email: taskerEmail)
        completeProfileSetup(name: taskerName, city: "Toronto", province: "ON")
        _ = ensureDiscoverableTasker(email: taskerEmail, name: taskerName, displayName: taskerName)
        _ = ensureConversation(
            seekerEmail: seekerEmail,
            seekerName: seekerName,
            taskerEmail: taskerEmail
        )
        signOutToEmailEntry()
        completeEmailAuth(email: taskerEmail)

        openMessagesTaskerConversation(named: seekerName)
        let proposeTermsButton = app.buttons["Propose terms"]
        XCTAssertTrue(proposeTermsButton.waitForExistence(timeout: 15))
        proposeTermsButton.tap()

        submitProposal(rate: "75")

        XCTAssertTrue(waitForProposalStatus("Pending"))
        XCTAssertTrue(waitForLatestProposal(seekerEmail: seekerEmail, taskerEmail: taskerEmail) { proposal in
            proposal["status"] as? String == "pending"
        })
    }

    func testSeekerAcceptsProposalCreatesJob() throws {
        let seekerEmail = uniqueTestEmail(prefix: "ios-seeker-accept-proposal")
        let taskerEmail = uniqueTestEmail(prefix: "ios-tasker-accept-proposal")
        let taskerName = "Accept Tasker \(Int(Date().timeIntervalSince1970))"
        let seekerName = "Accept Seeker \(Int(Date().timeIntervalSince1970))"

        cleanupTestData(for: seekerEmail)
        cleanupTestData(for: taskerEmail)

        launchToEmailEntry()
        completeEmailAuth(email: seekerEmail)
        completeProfileSetup(name: seekerName, city: "Toronto", province: "ON")

        _ = ensurePendingProposal(
            seekerEmail: seekerEmail,
            taskerEmail: taskerEmail,
            taskerName: taskerName,
            taskerDisplayName: taskerName
        )

        openMessagesConversation(named: taskerName)

        let acceptButton = app.buttons["Accept"]
        XCTAssertTrue(acceptButton.waitForExistence(timeout: 15))
        acceptButton.tap()

        XCTAssertTrue(app.staticTexts["Accepted"].waitForExistence(timeout: 15))
        let jobStatusText = app.staticTexts["Job in progress"]
        XCTAssertTrue(jobStatusText.waitForExistence(timeout: 15))

        let dismissJobBannerButton = app.buttons["Dismiss job status banner"]
        XCTAssertTrue(dismissJobBannerButton.waitForExistence(timeout: 10))
        dismissJobBannerButton.tap()
        XCTAssertFalse(app.buttons["Dismiss job status banner"].waitForExistence(timeout: 2))

        let messageField = app.textFields["Message"]
        focusForTyping(messageField)
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 2))
        XCTAssertFalse(app.keyboards.buttons["Done"].exists)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.34)).tap()
        XCTAssertFalse(app.keyboards.firstMatch.waitForExistence(timeout: 2))

        XCTAssertTrue(waitForLatestProposal(seekerEmail: seekerEmail, taskerEmail: taskerEmail) { proposal in
            proposal["status"] as? String == "accepted"
        })
        XCTAssertTrue(waitForConversation(seekerEmail: seekerEmail, taskerEmail: taskerEmail) { conversation in
            conversation["jobId"] as? String != nil
        })
        let conversation = conversationByEmails(seekerEmail: seekerEmail, taskerEmail: taskerEmail)
        let jobId = conversation?["jobId"] as? String
        XCTAssertNotNil(jobId)

        let jobsTab = tabButton(named: "Jobs")
        XCTAssertTrue(jobsTab.waitForExistence(timeout: 10))
        jobsTab.tap()
        if let jobId {
            XCTAssertTrue(identifiedElement("Jobs.row.\(jobId)").waitForExistence(timeout: 15))
        }
    }

    func testSeekerDeclinesProposalDoesNotCreateJob() throws {
        let seekerEmail = uniqueTestEmail(prefix: "ios-seeker-decline-proposal")
        let taskerEmail = uniqueTestEmail(prefix: "ios-tasker-decline-proposal")
        let taskerName = "Decline Tasker \(Int(Date().timeIntervalSince1970))"
        let seekerName = "Decline Seeker \(Int(Date().timeIntervalSince1970))"

        cleanupTestData(for: seekerEmail)
        cleanupTestData(for: taskerEmail)

        launchToEmailEntry()
        completeEmailAuth(email: seekerEmail)
        completeProfileSetup(name: seekerName, city: "Toronto", province: "ON")

        _ = ensurePendingProposal(
            seekerEmail: seekerEmail,
            taskerEmail: taskerEmail,
            taskerName: taskerName,
            taskerDisplayName: taskerName
        )

        openMessagesConversation(named: taskerName)

        let declineButton = app.buttons["Decline"]
        XCTAssertTrue(declineButton.waitForExistence(timeout: 15))
        declineButton.tap()

        XCTAssertTrue(app.staticTexts["Declined"].waitForExistence(timeout: 15))
        XCTAssertTrue(waitForLatestProposal(seekerEmail: seekerEmail, taskerEmail: taskerEmail) { proposal in
            proposal["status"] as? String == "declined"
        })
        XCTAssertTrue(waitForConversation(seekerEmail: seekerEmail, taskerEmail: taskerEmail) { conversation in
            conversation["jobId"] as? String == nil
        })

        let jobsTab = tabButton(named: "Jobs")
        XCTAssertTrue(jobsTab.waitForExistence(timeout: 10))
        jobsTab.tap()
        XCTAssertFalse(app.staticTexts[taskerName].waitForExistence(timeout: 5))
    }

    func testCompleteJobMovesAcceptedJobToCompleted() throws {
        let seekerEmail = uniqueTestEmail(prefix: "ios-seeker-complete-job")
        let taskerEmail = uniqueTestEmail(prefix: "ios-tasker-complete-job")
        let taskerName = "Complete Tasker \(Int(Date().timeIntervalSince1970))"
        let seekerName = "Complete Seeker \(Int(Date().timeIntervalSince1970))"

        cleanupTestData(for: seekerEmail)
        cleanupTestData(for: taskerEmail)

        launchToEmailEntry()
        completeEmailAuth(email: seekerEmail)
        completeProfileSetup(name: seekerName, city: "Toronto", province: "ON")

        let acceptedJob = ensureAcceptedJob(
            seekerEmail: seekerEmail,
            taskerEmail: taskerEmail,
            taskerName: taskerName,
            taskerDisplayName: taskerName
        )
        guard let jobId = acceptedJob["jobId"] as? String else {
            XCTFail("Failed to seed accepted job")
            return
        }

        let jobsTab = tabButton(named: "Jobs")
        XCTAssertTrue(jobsTab.waitForExistence(timeout: 10))
        jobsTab.tap()

        let activeRow = identifiedElement("Jobs.row.\(jobId)")
        XCTAssertTrue(activeRow.waitForExistence(timeout: 15))
        activeRow.tap()

        let completeButton = app.buttons["JobDetail.completeButton"]
        XCTAssertTrue(completeButton.waitForExistence(timeout: 15))
        completeButton.tap()

        XCTAssertTrue(waitForJob(jobId: jobId) { job in
            job["status"] as? String == "completed"
        })

        let backButton = app.buttons["JobDetail.backButton"]
        XCTAssertTrue(backButton.waitForExistence(timeout: 10))
        backButton.tap()

        let completedTab = identifiedElement("Jobs.statusTab.completed")
        XCTAssertTrue(completedTab.waitForExistence(timeout: 10))
        completedTab.tap()

        XCTAssertTrue(identifiedElement("Jobs.row.\(jobId)").waitForExistence(timeout: 15))
    }

    func testLeaveReviewOnCompletedJob() throws {
        let seekerEmail = uniqueTestEmail(prefix: "ios-seeker-review-job")
        let taskerEmail = uniqueTestEmail(prefix: "ios-tasker-review-job")
        let taskerName = "Review Tasker \(Int(Date().timeIntervalSince1970))"
        let seekerName = "Review Seeker \(Int(Date().timeIntervalSince1970))"

        cleanupTestData(for: seekerEmail)
        cleanupTestData(for: taskerEmail)

        launchToEmailEntry()
        completeEmailAuth(email: seekerEmail)
        completeProfileSetup(name: seekerName, city: "Toronto", province: "ON")

        let completedJob = ensureCompletedJob(
            seekerEmail: seekerEmail,
            taskerEmail: taskerEmail,
            taskerName: taskerName,
            taskerDisplayName: taskerName
        )
        guard let jobId = completedJob["jobId"] as? String else {
            XCTFail("Failed to seed completed job")
            return
        }

        let jobsTab = tabButton(named: "Jobs")
        XCTAssertTrue(jobsTab.waitForExistence(timeout: 10))
        jobsTab.tap()

        let completedTab = identifiedElement("Jobs.statusTab.completed")
        XCTAssertTrue(completedTab.waitForExistence(timeout: 10))
        completedTab.tap()

        let completedRow = identifiedElement("Jobs.row.\(jobId)")
        XCTAssertTrue(completedRow.waitForExistence(timeout: 15))
        completedRow.tap()

        let leaveReviewButton = app.buttons["JobDetail.leaveReviewButton"]
        XCTAssertTrue(leaveReviewButton.waitForExistence(timeout: 15))
        leaveReviewButton.tap()

        let reviewField = app.textViews["LeaveReview.textField"]
        XCTAssertTrue(reviewField.waitForExistence(timeout: 15))
        app.buttons["LeaveReview.star.5"].tap()
        replaceText(in: reviewField, with: "Excellent work, clear communication, and everything was completed on time.")

        let submitButton = app.buttons["LeaveReview.submitButton"]
        XCTAssertTrue(submitButton.waitForExistence(timeout: 10))
        submitButton.tap()

        XCTAssertTrue(waitForReview(jobId: jobId, reviewerEmail: seekerEmail) { review in
            (review["rating"] as? Int) == 5
        })
        XCTAssertTrue(waitForJob(jobId: jobId) { job in
            job["seekerReviewId"] as? String != nil
        })
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

    private func launchToEmailEntry() {
        XCTAssertTrue(app.buttons["Auth.getStartedButton"].waitForExistence(timeout: 5))
        app.buttons["Auth.getStartedButton"].tap()

        XCTAssertTrue(app.buttons["Auth.onboardingSkipButton"].waitForExistence(timeout: 5))
        app.buttons["Auth.onboardingSkipButton"].tap()

        XCTAssertTrue(app.buttons["Auth.emailSignInButton"].waitForExistence(timeout: 5))
        app.buttons["Auth.emailSignInButton"].tap()

        XCTAssertTrue(app.textFields["Auth.emailField"].waitForExistence(timeout: 5))
    }

    private func signOutToEmailEntry() {
        openProfileTab()
        let signOutButton = app.buttons["Profile.signOutButton"]
        XCTAssertTrue(signOutButton.waitForExistence(timeout: 10))
        signOutButton.tap()
        launchToEmailEntry()
    }

    private func completeEmailAuth(email: String) {
        let emailField = app.textFields["Auth.emailField"]
        replaceText(in: emailField, with: email)
        app.buttons["Auth.sendCodeButton"].tap()

        let firstCodeField = app.textFields["Auth.codeField.0"]
        let verifyButton = app.buttons["Auth.verifyButton"]
        if !firstCodeField.waitForExistence(timeout: 30) {
            saveScreenshot(named: "ios-auth-code-field-missing")
            XCTFail("Auth send-code timed out before verification UI appeared for \(email)")
        }
        enterOTP(testOTP(for: email))

        if waitForAuthenticatedOrSetupState(timeout: 12) {
            return
        }

        if verifyButton.exists, verifyButton.isHittable, verifyButton.isEnabled {
            verifyButton.tap()
            _ = waitForAuthenticatedOrSetupState(timeout: 12)
        }
    }

    private func completeProfileSetup(
        name: String,
        city: String,
        province: String,
        finishWithNotificationsAllow: Bool = false
    ) {
        let nameField = app.textFields["ProfileSetup.nameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 30))
        replaceText(in: nameField, with: name, shouldClearExisting: false)
        dismissKeyboardIfPresent()

        let cityField = app.textFields["ProfileSetup.cityField"]
        replaceText(in: cityField, with: city)
        let homeBaseSuggestion = app.buttons["ProfileSetup.homeBaseSuggestion.\(city), \(province.uppercased())"]
        XCTAssertTrue(homeBaseSuggestion.waitForExistence(timeout: 10))
        homeBaseSuggestion.tap()
        dismissKeyboardIfPresent()

        app.buttons["ProfileSetup.continueButton"].tap()

        let locationSkip = app.buttons["ProfileSetup.locationSkipButton"]
        XCTAssertTrue(locationSkip.waitForExistence(timeout: 10))
        locationSkip.tap()

        let notificationsButton = finishWithNotificationsAllow
            ? app.buttons["ProfileSetup.notificationsAllowButton"]
            : app.buttons["ProfileSetup.notificationsSkipButton"]
        XCTAssertTrue(notificationsButton.waitForExistence(timeout: 10))
        notificationsButton.tap()
        if finishWithNotificationsAllow {
            acceptSystemNotificationPromptIfNeeded()
        }

        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 20))
    }

    private func acceptSystemNotificationPromptIfNeeded() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allowButtons = [
            springboard.buttons["Allow"],
            springboard.buttons["Allow Notifications"]
        ]

        for button in allowButtons where button.waitForExistence(timeout: 5) {
            button.tap()
            return
        }
    }

    private func openProfileTab() {
        let profileTab = tabButton(named: "Profile")
        XCTAssertTrue(profileTab.waitForExistence(timeout: 5))
        profileTab.tap()
        XCTAssertTrue(app.buttons["Profile.signOutButton"].waitForExistence(timeout: 10))
    }

    private func dismissLocationPromptIfNeeded() {
        let skipButton = app.buttons["LocationPrompt.skipButton"]
        if skipButton.waitForExistence(timeout: 3) {
            skipButton.tap()
        }
    }

    private func openSpotlightTaskerProfile() {
        let viewButton = app.buttons["Home.spotlightViewProfileButton"]
        XCTAssertTrue(viewButton.waitForExistence(timeout: 10))
        viewButton.tap()
    }

    private func openMessagesConversation(named participantName: String) {
        let messagesTab = tabButton(named: "Messages")
        XCTAssertTrue(messagesTab.waitForExistence(timeout: 10))
        messagesTab.tap()

        let conversationName = app.staticTexts[participantName]
        XCTAssertTrue(conversationName.waitForExistence(timeout: 15))
        conversationName.tap()
    }

    private func startChatFromProviderDetail() {
        let startChatButton = app.buttons["ProviderDetail.startChatButton"]
        XCTAssertTrue(startChatButton.waitForExistence(timeout: 15))
        startChatButton.tap()
    }

    private func openDiscoverProfile(named displayName: String, maxSkips: Int = 10) {
        for _ in 0 ..< maxSkips {
            let providerButton = app.buttons["Home.spotlightViewProfileButton"]
            XCTAssertTrue(providerButton.waitForExistence(timeout: 20))
            if providerButton.label.contains(displayName) {
                providerButton.tap()
                return
            }

            let skipButton = app.buttons["Home.skipButton"]
            XCTAssertTrue(skipButton.waitForExistence(timeout: 5))
            skipButton.tap()
        }

        XCTFail("Could not find Discover card for \(displayName)")
    }

    private func openMessagesTaskerConversation(named participantName: String) {
        let messagesTab = tabButton(named: "Messages")
        XCTAssertTrue(messagesTab.waitForExistence(timeout: 10))
        messagesTab.tap()

        let taskerRoleButton = identifiedElement("Messages.roleTab.tasker")
        XCTAssertTrue(taskerRoleButton.waitForExistence(timeout: 10))
        taskerRoleButton.tap()

        let conversationName = app.staticTexts[participantName]
        XCTAssertTrue(conversationName.waitForExistence(timeout: 15))
        conversationName.tap()
    }

    private func openTaskerProfileManagement() {
        openProfileTab()
        let manageLink = app.buttons["Profile.taskerOnboardingLink"]
        XCTAssertTrue(manageLink.waitForExistence(timeout: 10))
        manageLink.tap()
        XCTAssertTrue(app.textFields["TaskerProfile.displayNameField"].waitForExistence(timeout: 10))
    }

    private func completeTaskerOnboarding(
        displayName: String,
        categoryRowIdentifier: String = "Categories.row.interior-cleaning-services",
        categoryBio: String,
        hourlyRate: String
    ) {
        let displayNameField = app.textFields["TaskerOnboarding1.displayNameField"]
        XCTAssertTrue(displayNameField.waitForExistence(timeout: 10))
        replaceText(in: displayNameField, with: displayName)

        app.buttons["TaskerOnboarding1.categoryPicker"].tap()
        let categoryRow = app.buttons[categoryRowIdentifier]
        XCTAssertTrue(categoryRow.waitForExistence(timeout: 10))
        categoryRow.tap()

        app.buttons["TaskerOnboarding1.continueButton"].tap()

        let linksContinue = app.buttons["TaskerOnboarding2.continueButton"]
        XCTAssertTrue(linksContinue.waitForExistence(timeout: 10))
        linksContinue.tap()

        let bioField = app.textViews["TaskerOnboarding3.bioField"]
        XCTAssertTrue(bioField.waitForExistence(timeout: 10))
        replaceText(in: bioField, with: categoryBio)

        let hourlyRateField = app.textFields["TaskerOnboarding3.hourlyRateField"]
        XCTAssertTrue(hourlyRateField.waitForExistence(timeout: 10))
        replaceText(in: hourlyRateField, with: hourlyRate)

        app.buttons["TaskerOnboarding3.continueButton"].tap()

        let portfolioContinue = app.buttons["TaskerOnboarding4.continueButton"]
        XCTAssertTrue(portfolioContinue.waitForExistence(timeout: 10))
        portfolioContinue.tap()

        let profileCardPreview = identifiedElement("TaskerOnboarding5.discoverCardPreview")
        XCTAssertTrue(profileCardPreview.waitForExistence(timeout: 10))

        let termsToggle = app.buttons["TaskerOnboarding5.acceptTermsToggle"]
        XCTAssertTrue(termsToggle.waitForExistence(timeout: 10))
        termsToggle.tap()

        app.buttons["TaskerOnboarding5.completeButton"].tap()
    }

    private func backgroundAndRestoreApp() {
        XCUIDevice.shared.press(.home)
        app.activate()
    }

    private func uniqueTestEmail(prefix: String) -> String {
        let timestamp = Int(Date().timeIntervalSince1970)
        return "\(prefix).\(timestamp)@test.com"
    }

    private func tabButton(named name: String) -> XCUIElement {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10))
        let namedButton = tabBar.buttons[name]
        XCTAssertTrue(namedButton.waitForExistence(timeout: 10), "Missing tab button: \(name)")
        return namedButton
    }

    private func identifiedElement(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    private func fetchOTP(email: String) -> String {
        for _ in 0 ..< 30 {
            if let otp: String = testProxy(action: "getOtp", args: ["email": email]), !otp.isEmpty {
                return otp
            }
            Thread.sleep(forTimeInterval: 1)
        }
        XCTFail("Failed to fetch OTP for \(email)")
        return ""
    }

    private func testOTP(for email: String) -> String {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return fetchOTP(email: normalizedEmail)
    }

    private func enterOTP(_ otp: String) {
        for (index, digit) in otp.enumerated() {
            let codeField = app.textFields["Auth.codeField.\(index)"]
            XCTAssertTrue(codeField.waitForExistence(timeout: 2), "Missing OTP field \(index)")
            codeField.tap()
            codeField.typeText(String(digit))
        }
    }

    private func waitForAuthenticatedOrSetupState(timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if app.textFields["ProfileSetup.nameField"].exists
                || app.tabBars.firstMatch.exists
                || app.buttons["LocationPrompt.skipButton"].exists
                || app.buttons["ProfileSetup.locationSkipButton"].exists {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        return false
    }

    private func cleanupTestData(for email: String) {
        _ = testProxy(action: "cleanupConversations", args: ["userEmail": email]) as Optional<[String: Int]>
        _ = testProxy(action: "deleteTestUser", args: ["email": email]) as Optional<[String: Any]>
    }

    private func ensureDiscoverableTasker(
        email: String,
        name: String,
        displayName: String,
        city: String = "Toronto",
        province: String = "ON",
        lat: Double = 43.6532,
        lng: Double = -79.3832,
        categoryBio: String = "Reliable local cleaning help for homes and apartments.",
        rateType: String = "hourly",
        hourlyRate: Int? = 5500,
        fixedRate: Int? = nil,
        serviceRadius: Int = 25,
        subscriptionPlan: String = "tasker"
    ) -> [String: Any] {
        var args: [String: Any] = [
            "email": email,
            "name": name,
            "displayName": displayName,
            "city": city,
            "province": province,
            "lat": lat,
            "lng": lng,
            "categorySlug": "interior-cleaning-services",
            "categoryName": "Interior Cleaning Services",
            "categoryBio": categoryBio,
            "rateType": rateType,
            "serviceRadius": serviceRadius,
            "verified": true,
            "subscriptionPlan": subscriptionPlan,
        ]
        if let hourlyRate {
            args["hourlyRate"] = hourlyRate
        }
        if let fixedRate {
            args["fixedRate"] = fixedRate
        }

        let result: [String: Any]? = testProxy(action: "ensureDiscoverableTasker", args: args)
        return result ?? [:]
    }

    private func setUserLocation(email: String, lat: Double, lng: Double) {
        let result: [String: Any]? = testProxy(
            action: "setTaskerLocationByEmail",
            args: [
                "email": email,
                "lat": lat,
                "lng": lng,
            ]
        )
        XCTAssertEqual(result?["updated"] as? Bool, true)
    }

    private func ensurePendingProposal(
        seekerEmail: String,
        taskerEmail: String,
        taskerName: String,
        taskerDisplayName: String,
        city: String = "Toronto",
        province: String = "ON",
        lat: Double = 43.6532,
        lng: Double = -79.3832
    ) -> [String: Any] {
        let result: [String: Any]? = testProxy(
            action: "ensurePendingProposalBetweenEmails",
            args: [
                "seekerEmail": seekerEmail,
                "taskerEmail": taskerEmail,
                "taskerName": taskerName,
                "taskerDisplayName": taskerDisplayName,
                "city": city,
                "province": province,
                "lat": lat,
                "lng": lng,
                "categorySlug": "interior-cleaning-services",
                "categoryName": "Interior Cleaning Services",
                "categoryBio": "Reliable local cleaning help for homes and apartments.",
                "rate": 7500,
                "rateType": "hourly",
                "startDateTime": "2026-03-16T10:00:00-04:00",
                "notes": "Can arrive with supplies and start at 10:00 AM.",
            ]
        )
        return result ?? [:]
    }

    private func ensureAcceptedJob(
        seekerEmail: String,
        taskerEmail: String,
        taskerName: String,
        taskerDisplayName: String,
        city: String = "Toronto",
        province: String = "ON",
        lat: Double = 43.6532,
        lng: Double = -79.3832
    ) -> [String: Any] {
        let result: [String: Any]? = testProxy(
            action: "ensureAcceptedJobBetweenEmails",
            args: [
                "seekerEmail": seekerEmail,
                "taskerEmail": taskerEmail,
                "taskerName": taskerName,
                "taskerDisplayName": taskerDisplayName,
                "city": city,
                "province": province,
                "lat": lat,
                "lng": lng,
                "categorySlug": "interior-cleaning-services",
                "categoryName": "Interior Cleaning Services",
                "categoryBio": "Reliable local cleaning help for homes and apartments.",
                "rate": 7500,
                "rateType": "hourly",
                "startDateTime": "2026-03-16T10:00:00-04:00",
                "notes": "Can arrive with supplies and start at 10:00 AM.",
            ]
        )
        return result ?? [:]
    }

    private func ensureCompletedJob(
        seekerEmail: String,
        taskerEmail: String,
        taskerName: String,
        taskerDisplayName: String,
        city: String = "Toronto",
        province: String = "ON",
        lat: Double = 43.6532,
        lng: Double = -79.3832
    ) -> [String: Any] {
        let result: [String: Any]? = testProxy(
            action: "ensureCompletedJobBetweenEmails",
            args: [
                "seekerEmail": seekerEmail,
                "taskerEmail": taskerEmail,
                "taskerName": taskerName,
                "taskerDisplayName": taskerDisplayName,
                "city": city,
                "province": province,
                "lat": lat,
                "lng": lng,
                "categorySlug": "interior-cleaning-services",
                "categoryName": "Interior Cleaning Services",
                "categoryBio": "Reliable local cleaning help for homes and apartments.",
                "rate": 7500,
                "rateType": "hourly",
                "startDateTime": "2026-03-16T10:00:00-04:00",
                "notes": "Can arrive with supplies and start at 10:00 AM.",
            ]
        )
        return result ?? [:]
    }

    private func ensureConversation(
        seekerEmail: String,
        seekerName: String,
        taskerEmail: String,
        city: String = "Toronto",
        province: String = "ON",
        lat: Double = 43.6532,
        lng: Double = -79.3832
    ) -> [String: Any] {
        let result: [String: Any]? = testProxy(
            action: "ensureConversationBetweenEmails",
            args: [
                "seekerEmail": seekerEmail,
                "seekerName": seekerName,
                "taskerEmail": taskerEmail,
                "city": city,
                "province": province,
                "lat": lat,
                "lng": lng,
                "initialMessage": "Hi, I’d like help with a cleaning job.",
            ]
        )
        return result ?? [:]
    }

    private func waitForConversation(
        seekerEmail: String,
        taskerEmail: String,
        timeout: TimeInterval = 15,
        predicate: ([String: Any]) -> Bool
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let conversation: [String: Any] = testProxy(
                action: "getConversationByEmails",
                args: [
                    "seekerEmail": seekerEmail,
                    "taskerEmail": taskerEmail,
                ]
            ), predicate(conversation) {
                return true
            }
            Thread.sleep(forTimeInterval: 0.5)
        }
        return false
    }

    private func waitForJob(
        jobId: String,
        timeout: TimeInterval = 15,
        predicate: ([String: Any]) -> Bool
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let job: [String: Any] = testProxy(action: "getJobById", args: ["jobId": jobId]),
               predicate(job) {
                return true
            }
            Thread.sleep(forTimeInterval: 0.5)
        }
        return false
    }

    private func waitForReview(
        jobId: String,
        reviewerEmail: String,
        timeout: TimeInterval = 15,
        predicate: ([String: Any]) -> Bool
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let review: [String: Any] = testProxy(
                action: "getReviewByJobAndReviewer",
                args: [
                    "jobId": jobId,
                    "reviewerEmail": reviewerEmail,
                ]
            ), predicate(review) {
                return true
            }
            Thread.sleep(forTimeInterval: 0.5)
        }
        return false
    }

    private func conversationByEmails(seekerEmail: String, taskerEmail: String) -> [String: Any]? {
        testProxy(
            action: "getConversationByEmails",
            args: [
                "seekerEmail": seekerEmail,
                "taskerEmail": taskerEmail,
            ]
        )
    }

    private func waitForLatestProposal(
        seekerEmail: String,
        taskerEmail: String,
        timeout: TimeInterval = 15,
        predicate: ([String: Any]) -> Bool
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let proposal: [String: Any] = testProxy(
                action: "getLatestProposalByEmails",
                args: [
                    "seekerEmail": seekerEmail,
                    "taskerEmail": taskerEmail,
                ]
            ), predicate(proposal) {
                return true
            }
            Thread.sleep(forTimeInterval: 0.5)
        }
        return false
    }

    private func submitProposal(rate: String) {
        let rateField = app.textFields["ProposalForm.rateField"]
        XCTAssertTrue(rateField.waitForExistence(timeout: 10))
        replaceText(in: rateField, with: rate, shouldClearExisting: false)

        let submitButton = app.buttons["ProposalForm.submitButton"]
        XCTAssertTrue(submitButton.waitForExistence(timeout: 10))
        submitButton.tap()
    }

    private func waitForProposalStatus(_ status: String, timeout: TimeInterval = 15) -> Bool {
        let predicate = NSPredicate(
            format: "identifier BEGINSWITH %@ AND (value CONTAINS %@ OR label == %@)",
            "Chat.proposal.",
            "Status \(status)",
            status
        )
        return app.descendants(matching: .any).matching(predicate).firstMatch.waitForExistence(timeout: timeout)
    }

    private func waitForTaskerProfile(
        email: String,
        timeout: TimeInterval = 15,
        predicate: ([String: Any]) -> Bool
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let profile: [String: Any] = testProxy(action: "getTaskerProfileByEmail", args: ["email": email]),
               predicate(profile) {
                return true
            }
            Thread.sleep(forTimeInterval: 0.5)
        }
        return false
    }

    private func testProxy<T>(action: String, args: [String: Any]) -> T? {
        var request = URLRequest(url: convexSiteURL.appending(path: "/test-proxy"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "action": action,
            "args": args,
        ])

        let semaphore = DispatchSemaphore(value: 0)
        var result: T?

        URLSession.shared.dataTask(with: request) { data, _, _ in
            defer { semaphore.signal() }
            guard let data,
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let rawResult = object["result"] else {
                return
            }

            if T.self == String.self, let value = rawResult as? String {
                result = value as? T
                return
            }

            if let value = rawResult as? T {
                result = value
            }
        }.resume()

        semaphore.wait()
        return result
    }

    private func replaceText(in element: XCUIElement, with text: String, shouldClearExisting: Bool = true) {
        focusForTyping(element)
        if shouldClearExisting,
           let existingValue = element.value as? String,
           !existingValue.isEmpty {
            element.press(forDuration: 1.0)
            let selectAll = app.menuItems["Select All"]
            if selectAll.waitForExistence(timeout: 1) {
                selectAll.tap()
                element.typeText(text)
                return
            }

            let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: existingValue.count + 4)
            element.typeText(deleteString)
        }
        element.typeText(text)
    }

    private func focusForTyping(_ element: XCUIElement) {
        XCTAssertTrue(element.waitForExistence(timeout: 10))

        for _ in 0 ..< 5 {
            element.tap()
            _ = app.keyboards.firstMatch.waitForExistence(timeout: 1)
            if elementHasKeyboardFocus(element) {
                return
            }

            Thread.sleep(forTimeInterval: 0.3)
        }

        XCTFail("Keyboard focus did not reach element \(element)")
    }

    private func dismissKeyboardIfPresent() {
        guard app.keyboards.firstMatch.exists else {
            return
        }

        let returnButton = app.keyboards.buttons["Return"]
        if returnButton.exists {
            returnButton.tap()
            return
        }

        let doneButton = app.keyboards.buttons["Done"]
        if doneButton.exists {
            doneButton.tap()
            return
        }

        let toolbarDoneButton = app.buttons["Done"]
        if toolbarDoneButton.exists {
            toolbarDoneButton.tap()
            return
        }
    }

    private func elementHasKeyboardFocus(_ element: XCUIElement) -> Bool {
        (element.value(forKey: "hasKeyboardFocus") as? Bool) == true
    }

    private func textFieldValue(_ element: XCUIElement) -> String {
        element.value as? String ?? ""
    }

    private func isEmptyTextField(_ element: XCUIElement) -> Bool {
        textFieldValue(element).isEmpty
    }
}
