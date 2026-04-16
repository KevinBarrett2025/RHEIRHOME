//
//  RHEIRUITests.swift
//  RHEIRUITests
//
//  Created by Kevin Barrett on 5/23/25.
//

import XCTest

final class RHEIRUITests: XCTestCase {
    private enum UITestLaunchEnvironment {
        static let mode = "RHEIR_UI_TEST_MODE"
        static let skipLaunchDelay = "RHEIR_UI_TEST_SKIP_LAUNCH_DELAY"
    }

    private enum UITestLaunchMode: String {
        case signedOut = "signed_out"
        case ready = "ready"
        case selectingOrganization = "selecting_organization"
        case projectSelection = "project_selection"
        case selectedProject = "selected_project"
    }

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testSignedOutModeShowsAppleSignIn() throws {
        let app = makeApp(mode: .signedOut)
        app.launch()

        let appleSignInButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Apple")).firstMatch
        XCTAssertTrue(
            appleSignInButton.waitForExistence(timeout: 5),
            "Expected the signed-out screen to present the Sign in with Apple button."
        )
    }

    @MainActor
    func testReadyModeShowsMainTabShell() throws {
        let app = makeApp(mode: .ready)
        app.launch()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(
            tabBar.waitForExistence(timeout: 5),
            "Expected deterministic ready UI test mode to render the main tab shell."
        )

        XCTAssertTrue(tabBar.buttons["Projects"].exists, "Expected Projects tab in ready UI test mode.")
        XCTAssertTrue(tabBar.buttons["Receipts"].exists, "Expected Receipts tab in ready UI test mode.")
        XCTAssertTrue(tabBar.buttons["Labor"].exists, "Expected Labor tab in ready UI test mode.")
        XCTAssertTrue(tabBar.buttons["Tasks"].exists, "Expected Tasks tab in ready UI test mode.")
        XCTAssertTrue(tabBar.buttons["Company"].exists, "Expected Company tab in ready UI test mode.")
    }

    @MainActor
    func testOrganizationSelectionModeShowsOrganizationList() throws {
        let app = makeApp(mode: .selectingOrganization)
        app.launch()

        let organizationsTitle = app.navigationBars["Organizations"].firstMatch
        XCTAssertTrue(
            organizationsTitle.waitForExistence(timeout: 5),
            "Expected deterministic organization-selection UI test mode to render the organization picker."
        )

        XCTAssertTrue(app.buttons["Sign Out"].exists, "Expected Sign Out action in organization-selection mode.")
        XCTAssertTrue(app.staticTexts["UI Test Builders"].exists, "Expected the seeded builder organization.")
        XCTAssertTrue(app.staticTexts["Ready Roofing Co"].exists, "Expected the seeded contractor organization.")
        XCTAssertTrue(app.buttons["Create"].exists, "Expected the organization create action in organization-selection mode.")
    }

    @MainActor
    func testProjectSelectionModeRequiresAndAppliesProjectContext() throws {
        let app = makeApp(mode: .projectSelection)
        app.launch()

        let chooseProjectButton = app.buttons["project-selection-menu"]
        XCTAssertTrue(
            chooseProjectButton.waitForExistence(timeout: 5),
            "Expected deterministic project-selection UI test mode to expose the project picker."
        )

        XCTAssertTrue(
            app.staticTexts["project-selection-guidance"].waitForExistence(timeout: 5),
            "Expected the multi-project no-selection guidance before a project is chosen."
        )

        app.tabBars.buttons["Receipts"].tap()

        let receiptsGateMessage = app.staticTexts["Choose a project from the Projects tab before viewing receipts."]
        XCTAssertTrue(
            receiptsGateMessage.waitForExistence(timeout: 5),
            "Expected Receipts to require a selected project before showing receipt content."
        )

        app.terminate()

        let selectedProjectApp = makeApp(mode: .selectedProject)
        selectedProjectApp.launch()
        selectedProjectApp.tabBars.buttons["Receipts"].tap()

        XCTAssertTrue(
            selectedProjectApp.staticTexts["No Receipts Yet"].waitForExistence(timeout: 5),
            "Expected Receipts to show project-scoped content when a deterministic selected project is seeded."
        )
        XCTAssertFalse(
            selectedProjectApp.staticTexts["Choose a project from the Projects tab before viewing receipts."].exists,
            "Expected the project-selection gate to disappear when project context is already seeded."
        )
    }

    @MainActor
    func testLaborModeRequiresAndUsesSelectedProjectContext() throws {
        let app = makeApp(mode: .projectSelection)
        app.launch()
        app.tabBars.buttons["Labor"].tap()

        let laborGateMessage = app.staticTexts["Choose a project before viewing or logging labor hours."]
        XCTAssertTrue(
            laborGateMessage.waitForExistence(timeout: 5),
            "Expected Labor to require a selected project before showing project-scoped labor content."
        )

        app.terminate()

        let selectedProjectApp = makeApp(mode: .selectedProject)
        selectedProjectApp.launch()
        selectedProjectApp.tabBars.buttons["Labor"].tap()

        XCTAssertTrue(
            selectedProjectApp.staticTexts["Labor Summary"].waitForExistence(timeout: 5),
            "Expected selected-project mode to show the labor summary."
        )
        XCTAssertTrue(
            selectedProjectApp.staticTexts["No team members found"].exists,
            "Expected selected-project mode to show the empty labor team-member state."
        )
        XCTAssertTrue(
            selectedProjectApp.buttons["Log Hours for Team Member"].exists,
            "Expected selected-project mode to keep the log-hours action available."
        )
        XCTAssertFalse(
            selectedProjectApp.staticTexts["Choose a project before viewing or logging labor hours."].exists,
            "Expected the labor project-selection gate to disappear when project context is already seeded."
        )
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            makeApp(mode: .signedOut).launch()
        }
    }

    private func makeApp(mode: UITestLaunchMode) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment[UITestLaunchEnvironment.mode] = mode.rawValue
        app.launchEnvironment[UITestLaunchEnvironment.skipLaunchDelay] = "1"
        return app
    }
}
