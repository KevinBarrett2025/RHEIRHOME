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
    func testCompanyModeShowsAdminManagementSurface() throws {
        let app = makeApp(mode: .selectedProject)
        app.launch()
        app.tabBars.buttons["Company"].tap()

        XCTAssertTrue(
            app.navigationBars["Company Settings"].waitForExistence(timeout: 5),
            "Expected selected-project admin mode to open the Company settings surface."
        )
        XCTAssertTrue(
            app.staticTexts["Team Status Overview"].waitForExistence(timeout: 5),
            "Expected the admin company team overview to render."
        )
        XCTAssertTrue(
            app.staticTexts["Manage Team"].exists,
            "Expected the admin-only team management section."
        )
        XCTAssertTrue(
            app.buttons["Add Internal Team Member"].exists,
            "Expected the admin-only add team member action."
        )
        XCTAssertFalse(
            app.staticTexts["Administrator Access Required"].exists,
            "Expected admin mode to avoid the restricted company access state."
        )
    }

    @MainActor
    func testReceiptsModeShowsEntryActionsAndManualEntrySheet() throws {
        let app = makeApp(mode: .selectedProject)
        app.launch()
        app.tabBars.buttons["Receipts"].tap()

        XCTAssertTrue(
            app.staticTexts["No Receipts Yet"].waitForExistence(timeout: 5),
            "Expected selected-project mode to show the empty receipts state."
        )
        XCTAssertTrue(
            app.buttons["Scan Receipt"].exists,
            "Expected the empty receipts state to expose the scan entry action."
        )
        XCTAssertTrue(
            app.buttons["Manual Entry"].exists,
            "Expected the empty receipts state to expose the manual entry action."
        )

        app.buttons["Manual Entry"].tap()

        XCTAssertTrue(
            app.navigationBars["Add Receipt"].waitForExistence(timeout: 5),
            "Expected Manual Entry to open the Add Receipt sheet."
        )
        XCTAssertTrue(
            app.staticTexts["Receipt Details"].exists,
            "Expected the Add Receipt sheet to render the receipt details section."
        )
        XCTAssertTrue(
            app.buttons["Cancel"].exists,
            "Expected the Add Receipt sheet to expose a cancel action."
        )
    }

    @MainActor
    func testManualReceiptEntryOpensVendorPicker() throws {
        let app = makeApp(mode: .selectedProject)
        app.launch()
        app.tabBars.buttons["Receipts"].tap()

        XCTAssertTrue(
            app.buttons["Manual Entry"].waitForExistence(timeout: 5),
            "Expected selected-project mode to expose the manual receipt entry action."
        )

        app.buttons["Manual Entry"].tap()

        let addReceiptNavBar = app.navigationBars["Add Receipt"]
        XCTAssertTrue(
            addReceiptNavBar.waitForExistence(timeout: 5),
            "Expected the Add Receipt sheet to open before exercising the picker routes."
        )

        let vendorPickerButton = app.buttons["manual-receipt-vendor-picker"]
        XCTAssertTrue(
            vendorPickerButton.exists,
            "Expected the Add Receipt sheet to expose the vendor picker button."
        )
        vendorPickerButton.tap()

        XCTAssertTrue(
            app.navigationBars["Select Vendor"].waitForExistence(timeout: 5),
            "Expected tapping the vendor row to open the vendor picker sheet."
        )
        XCTAssertTrue(
            app.buttons["Add New Vendor"].exists,
            "Expected the vendor picker to expose the add-vendor action."
        )
        app.navigationBars["Select Vendor"].buttons["Cancel"].tap()

        XCTAssertTrue(
            addReceiptNavBar.waitForExistence(timeout: 5),
            "Expected cancelling the vendor picker to return to the Add Receipt sheet."
        )
    }

    @MainActor
    func testManualReceiptEntryOpensAddVendorForm() throws {
        let app = makeApp(mode: .selectedProject)
        app.launch()
        app.tabBars.buttons["Receipts"].tap()

        XCTAssertTrue(
            app.buttons["Manual Entry"].waitForExistence(timeout: 5),
            "Expected selected-project mode to expose the manual receipt entry action."
        )

        app.buttons["Manual Entry"].tap()

        let addReceiptNavBar = app.navigationBars["Add Receipt"]
        XCTAssertTrue(
            addReceiptNavBar.waitForExistence(timeout: 5),
            "Expected the Add Receipt sheet to open before exercising the add-vendor route."
        )

        let vendorPickerButton = app.buttons["manual-receipt-vendor-picker"]
        XCTAssertTrue(
            vendorPickerButton.exists,
            "Expected the Add Receipt sheet to expose the vendor picker button."
        )
        vendorPickerButton.tap()

        let vendorNavBar = app.navigationBars["Select Vendor"]
        XCTAssertTrue(
            vendorNavBar.waitForExistence(timeout: 5),
            "Expected tapping the vendor row to open the vendor picker sheet."
        )

        let addNewVendorButton = app.buttons["vendor-picker-add-new"]
        XCTAssertTrue(
            addNewVendorButton.exists,
            "Expected the vendor picker to expose the add-vendor action."
        )
        addNewVendorButton.tap()

        let addVendorNavBar = app.navigationBars["Add New Vendor"]
        XCTAssertTrue(
            addVendorNavBar.waitForExistence(timeout: 5),
            "Expected tapping add new vendor to open the nested vendor form."
        )
        XCTAssertTrue(
            app.textFields["Vendor Name"].exists,
            "Expected the nested add-vendor form to expose the vendor name field."
        )

        addVendorNavBar.buttons["Cancel"].tap()

        XCTAssertTrue(
            vendorNavBar.waitForExistence(timeout: 5),
            "Expected cancelling the add-vendor form to return to the vendor picker."
        )

        vendorNavBar.buttons["Cancel"].tap()

        XCTAssertTrue(
            addReceiptNavBar.waitForExistence(timeout: 5),
            "Expected cancelling the vendor picker to return to the Add Receipt sheet."
        )
    }

    @MainActor
    func testManualReceiptEntryOpensPaymentMethodPicker() throws {
        let app = makeApp(mode: .selectedProject)
        app.launch()
        app.tabBars.buttons["Receipts"].tap()

        XCTAssertTrue(
            app.buttons["Manual Entry"].waitForExistence(timeout: 5),
            "Expected selected-project mode to expose the manual receipt entry action."
        )

        app.buttons["Manual Entry"].tap()

        let addReceiptNavBar = app.navigationBars["Add Receipt"]
        XCTAssertTrue(
            addReceiptNavBar.waitForExistence(timeout: 5),
            "Expected the Add Receipt sheet to open before exercising the payment-method route."
        )

        let paymentMethodPickerButton = revealButton(
            identifier: "manual-receipt-payment-method-picker",
            in: app
        )
        XCTAssertTrue(
            paymentMethodPickerButton.exists,
            "Expected the Add Receipt sheet to expose the payment-method picker button."
        )
        XCTAssertTrue(
            paymentMethodPickerButton.isHittable,
            "Expected the payment-method picker button to become hittable after scrolling the Add Receipt form."
        )
        paymentMethodPickerButton.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

        XCTAssertTrue(
            app.navigationBars["Select Payment Method"].waitForExistence(timeout: 5),
            "Expected tapping the payment-method row to open the payment picker sheet."
        )
        XCTAssertTrue(
            app.buttons["Add New Payment Method"].exists,
            "Expected the payment picker to expose the add-payment-method action."
        )
        app.navigationBars["Select Payment Method"].buttons["Cancel"].tap()

        XCTAssertTrue(
            addReceiptNavBar.waitForExistence(timeout: 5),
            "Expected cancelling the payment-method picker to return to the Add Receipt sheet."
        )
    }

    @MainActor
    func testManualReceiptEntryOpensAddPaymentMethodForm() throws {
        let app = makeApp(mode: .selectedProject)
        app.launch()
        app.tabBars.buttons["Receipts"].tap()

        XCTAssertTrue(
            app.buttons["Manual Entry"].waitForExistence(timeout: 5),
            "Expected selected-project mode to expose the manual receipt entry action."
        )

        app.buttons["Manual Entry"].tap()

        let addReceiptNavBar = app.navigationBars["Add Receipt"]
        XCTAssertTrue(
            addReceiptNavBar.waitForExistence(timeout: 5),
            "Expected the Add Receipt sheet to open before exercising the add-payment-method route."
        )

        let paymentMethodPickerButton = revealButton(
            identifier: "manual-receipt-payment-method-picker",
            in: app
        )
        XCTAssertTrue(
            paymentMethodPickerButton.exists,
            "Expected the Add Receipt sheet to expose the payment-method picker button."
        )
        paymentMethodPickerButton.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

        let paymentMethodNavBar = app.navigationBars["Select Payment Method"]
        XCTAssertTrue(
            paymentMethodNavBar.waitForExistence(timeout: 5),
            "Expected tapping the payment-method row to open the payment picker sheet."
        )

        let addNewPaymentMethodButton = app.buttons["payment-method-picker-add-new"]
        XCTAssertTrue(
            addNewPaymentMethodButton.exists,
            "Expected the payment picker to expose the add-payment-method action."
        )
        addNewPaymentMethodButton.tap()

        let addPaymentMethodNavBar = app.navigationBars["Add Payment Method"]
        XCTAssertTrue(
            addPaymentMethodNavBar.waitForExistence(timeout: 5),
            "Expected tapping add new payment method to open the nested payment-method form."
        )
        XCTAssertTrue(
            app.textFields["Payment Method Name"].exists,
            "Expected the nested add-payment-method form to expose the payment method name field."
        )
        XCTAssertTrue(
            app.textFields["Nickname (Optional)"].exists,
            "Expected the nested add-payment-method form to expose the nickname field."
        )

        addPaymentMethodNavBar.buttons["Cancel"].tap()

        XCTAssertTrue(
            paymentMethodNavBar.waitForExistence(timeout: 5),
            "Expected cancelling the add-payment-method form to return to the payment-method picker."
        )

        paymentMethodNavBar.buttons["Cancel"].tap()

        XCTAssertTrue(
            addReceiptNavBar.waitForExistence(timeout: 5),
            "Expected cancelling the payment-method picker to return to the Add Receipt sheet."
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

    private func revealButton(identifier: String, in app: XCUIApplication, maxSwipes: Int = 4) -> XCUIElement {
        let sheetCollection = app.collectionViews.firstMatch
        var button = app.buttons[identifier]

        for _ in 0..<maxSwipes where !button.exists {
            let start = sheetCollection.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.78))
            let end = sheetCollection.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.48))
            start.press(forDuration: 0.01, thenDragTo: end)
            button = app.buttons[identifier]
        }

        return button
    }

}
