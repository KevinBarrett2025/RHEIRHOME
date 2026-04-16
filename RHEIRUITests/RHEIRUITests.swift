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
    func testManualReceiptEntrySavesReceiptIntoSelectedProject() throws {
        let app = makeApp(mode: .selectedProject)
        app.launch()
        app.tabBars.buttons["Receipts"].tap()

        let vendorName = "UI Test Saved Vendor"
        saveManualReceipt(in: app, vendorName: vendorName, amount: "123.45")

        XCTAssertTrue(
            app.staticTexts[vendorName].waitForExistence(timeout: 8),
            "Expected the saved manual receipt to render in the selected-project receipts list."
        )
        XCTAssertFalse(
            app.staticTexts["No Receipts Yet"].exists,
            "Expected the empty receipts state to disappear after saving a manual receipt."
        )
    }

    @MainActor
    func testManualReceiptEntryNavigatesToSavedReceiptDetails() throws {
        let app = makeApp(mode: .selectedProject)
        app.launch()
        app.tabBars.buttons["Receipts"].tap()

        let vendorName = "UI Test Saved Vendor"
        openSavedReceiptDetails(in: app, vendorName: vendorName, amount: "123.45")

        XCTAssertTrue(
            app.staticTexts["receipt-detail-vendor"].waitForExistence(timeout: 5),
            "Expected the receipt detail header to expose the saved vendor."
        )
        XCTAssertEqual(
            app.staticTexts["receipt-detail-vendor"].label,
            vendorName,
            "Expected the receipt detail header to show the saved vendor name."
        )
        XCTAssertEqual(
            app.staticTexts["receipt-detail-category"].label,
            "Materials",
            "Expected the receipt detail header to preserve the default manual-entry category."
        )
        XCTAssertEqual(
            app.staticTexts["receipt-detail-amount"].label,
            "$123.45",
            "Expected the receipt detail header to show the saved amount."
        )
    }

    @MainActor
    func testSavedReceiptDetailOpensEditSheet() throws {
        let app = makeApp(mode: .selectedProject)
        app.launch()
        app.tabBars.buttons["Receipts"].tap()

        openSavedReceiptDetails(in: app, vendorName: "UI Test Editable Vendor", amount: "45.67")

        let editButton = app.buttons["receipt-detail-edit-action"]
        XCTAssertTrue(
            editButton.waitForExistence(timeout: 5),
            "Expected the receipt detail screen to expose the explicit edit action."
        )
        editButton.tap()

        let editReceiptNavBar = app.navigationBars["Edit Receipt"]
        XCTAssertTrue(
            editReceiptNavBar.waitForExistence(timeout: 5),
            "Expected the explicit edit action to open the Edit Receipt sheet."
        )
        XCTAssertTrue(
            app.textFields["Vendor"].waitForExistence(timeout: 5),
            "Expected the Edit Receipt sheet to expose the vendor field."
        )

        editReceiptNavBar.buttons["Cancel"].tap()

        XCTAssertTrue(
            app.navigationBars["Receipt Details"].waitForExistence(timeout: 5),
            "Expected cancelling edit to return to the receipt detail screen."
        )
        XCTAssertEqual(
            app.staticTexts["receipt-detail-vendor"].label,
            "UI Test Editable Vendor",
            "Expected the saved receipt detail header to remain unchanged after cancelling edit."
        )
    }

    @MainActor
    func testSavedReceiptDetailDeletesReceiptAndReturnsToList() throws {
        let app = makeApp(mode: .selectedProject)
        app.launch()
        app.tabBars.buttons["Receipts"].tap()

        let vendorName = "UI Test Deleted Vendor"
        openSavedReceiptDetails(in: app, vendorName: vendorName, amount: "18.90")

        let deleteButton = app.buttons["receipt-detail-delete-action"]
        XCTAssertTrue(
            deleteButton.waitForExistence(timeout: 5),
            "Expected the receipt detail screen to expose the explicit delete action."
        )
        deleteButton.tap()

        let deleteAlert = app.alerts["Delete Receipt"]
        XCTAssertTrue(
            deleteAlert.waitForExistence(timeout: 5),
            "Expected tapping delete to show the destructive confirmation alert."
        )
        deleteAlert.buttons["Delete"].tap()

        XCTAssertTrue(
            app.staticTexts["No Receipts Yet"].waitForExistence(timeout: 8),
            "Expected deleting the only saved receipt to return the receipts list to the empty state."
        )
        XCTAssertFalse(
            app.staticTexts[vendorName].exists,
            "Expected the deleted receipt row to disappear from the receipts list."
        )
        XCTAssertFalse(
            app.navigationBars["Receipt Details"].exists,
            "Expected the detail screen to dismiss after deleting the receipt."
        )
    }

    @MainActor
    func testSavedReceiptDetailPersistsEdits() throws {
        let app = makeApp(mode: .selectedProject)
        app.launch()
        app.tabBars.buttons["Receipts"].tap()

        let originalVendorName = "UI Test Editable Saved Vendor"
        let updatedVendorName = "UI Test Edited Saved Vendor"
        openSavedReceiptDetails(in: app, vendorName: originalVendorName, amount: "45.67")

        let editButton = app.buttons["receipt-detail-edit-action"]
        XCTAssertTrue(
            editButton.waitForExistence(timeout: 5),
            "Expected the receipt detail screen to expose the explicit edit action before testing persistence."
        )
        editButton.tap()

        let editReceiptNavBar = app.navigationBars["Edit Receipt"]
        XCTAssertTrue(
            editReceiptNavBar.waitForExistence(timeout: 5),
            "Expected tapping the explicit edit action to open the Edit Receipt sheet."
        )

        let vendorField = app.textFields["receipt-edit-vendor"]
        XCTAssertTrue(
            vendorField.waitForExistence(timeout: 5),
            "Expected the Edit Receipt sheet to expose the vendor field."
        )
        replaceText(in: vendorField, with: updatedVendorName, app: app)

        let amountField = app.textFields["receipt-edit-amount"]
        XCTAssertTrue(
            amountField.waitForExistence(timeout: 5),
            "Expected the Edit Receipt sheet to expose the amount field."
        )
        replaceText(in: amountField, with: "98.76", app: app)
        dismissEditingFocusIfNeeded(in: app, navigationBar: editReceiptNavBar)

        let saveButton = app.buttons["receipt-edit-save"]
        XCTAssertTrue(
            saveButton.exists,
            "Expected the Edit Receipt sheet to expose the save action."
        )
        XCTAssertTrue(
            waitForEnabled(saveButton, timeout: 5),
            "Expected the Edit Receipt save action to become enabled after entering valid edits."
        )
        saveButton.tap()

        XCTAssertTrue(
            waitForNonExistence(of: editReceiptNavBar, timeout: 5),
            "Expected saving the receipt edit to dismiss the Edit Receipt sheet."
        )
        XCTAssertTrue(
            app.navigationBars["Receipt Details"].waitForExistence(timeout: 5),
            "Expected the receipt detail screen to remain visible after saving edits."
        )
        XCTAssertEqual(
            app.staticTexts["receipt-detail-vendor"].label,
            updatedVendorName,
            "Expected the receipt detail header to refresh to the edited vendor."
        )
        XCTAssertEqual(
            app.staticTexts["receipt-detail-amount"].label,
            "$98.76",
            "Expected the receipt detail header to refresh to the edited amount."
        )

        app.navigationBars["Receipt Details"].buttons.firstMatch.tap()

        let updatedReceiptCard = app.buttons["receipt-card-\(updatedVendorName)"]
        XCTAssertTrue(
            updatedReceiptCard.waitForExistence(timeout: 5),
            "Expected the receipts list to reconcile to the edited vendor after leaving receipt details."
        )
        XCTAssertFalse(
            app.buttons["receipt-card-\(originalVendorName)"].exists,
            "Expected the old vendor receipt card identifier to disappear after editing the saved receipt."
        )
    }

    @MainActor
    func testReceiptsSearchFiltersAndRestoresSavedReceipts() throws {
        let app = makeApp(mode: .selectedProject)
        app.launch()
        app.tabBars.buttons["Receipts"].tap()

        let firstVendorName = "UI Test Browse Vendor Alpha"
        let secondVendorName = "UI Test Browse Vendor Bravo"
        saveManualReceipt(in: app, vendorName: firstVendorName, amount: "10.00")

        XCTAssertTrue(
            app.buttons["receipt-card-\(firstVendorName)"].waitForExistence(timeout: 8),
            "Expected the first saved receipt card to render before expanding receipt browsing coverage."
        )

        saveManualReceipt(in: app, vendorName: secondVendorName, amount: "20.00")

        let secondReceiptCard = app.buttons["receipt-card-\(secondVendorName)"]
        XCTAssertTrue(
            secondReceiptCard.waitForExistence(timeout: 8),
            "Expected the second saved receipt card to render before exercising receipts search coverage."
        )

        let searchField = app.textFields["receipts-search-field"]
        XCTAssertTrue(
            searchField.waitForExistence(timeout: 5),
            "Expected the receipts search field to remain available while browsing saved receipts."
        )
        searchField.tap()
        searchField.typeText("Bravo")
        dismissKeyboardIfPresent(in: app)

        XCTAssertTrue(
            secondReceiptCard.waitForExistence(timeout: 5),
            "Expected searching the receipts list to keep the matching receipt card visible."
        )

        let clearSearchButton = app.buttons["receipts-search-clear"]
        XCTAssertTrue(
            clearSearchButton.waitForExistence(timeout: 5),
            "Expected entering a receipts search to expose the clear action."
        )
        clearSearchButton.tap()

        searchField.tap()
        searchField.typeText("Alpha")
        dismissKeyboardIfPresent(in: app)

        let firstReceiptCard = app.buttons["receipt-card-\(firstVendorName)"]
        XCTAssertTrue(
            firstReceiptCard.waitForExistence(timeout: 5),
            "Expected clearing and rerunning the receipts search to surface the older saved receipt card."
        )
    }

    @MainActor
    func testReceiptsCategoryDrilldownFiltersAndRestoresSavedReceipts() throws {
        let app = makeApp(mode: .selectedProject)
        app.launch()
        app.tabBars.buttons["Receipts"].tap()

        let materialsVendorName = "UI Test Category Material Vendor"
        let generalVendorName = "UI Test Category General Vendor"
        saveManualReceipt(in: app, vendorName: materialsVendorName, amount: "11.00")
        saveManualReceipt(
            in: app,
            vendorName: generalVendorName,
            amount: "22.00",
            category: "General Conditions"
        )

        let categoriesViewModeButton = app.buttons["receipts-view-mode-categories"]
        XCTAssertTrue(
            categoriesViewModeButton.waitForExistence(timeout: 5),
            "Expected the receipts screen to expose the Categories view mode."
        )
        categoriesViewModeButton.tap()

        let generalFilterButton = app.buttons["receipts-category-filter-general-conditions"]
        XCTAssertTrue(
            generalFilterButton.waitForExistence(timeout: 5),
            "Expected category mode to expose the General Conditions filter button."
        )

        let materialsFilterButton = app.buttons["receipts-category-filter-materials"]
        XCTAssertTrue(
            materialsFilterButton.waitForExistence(timeout: 5),
            "Expected category mode to expose the Materials filter button."
        )
        let allCategoriesButton = app.buttons["receipts-category-filter-all"]
        XCTAssertEqual(
            allCategoriesButton.value as? String,
            "selected",
            "Expected category mode to start in the All-categories state."
        )
        generalFilterButton.tap()

        XCTAssertTrue(
            waitForSelectedValue(on: generalFilterButton, timeout: 5),
            "Expected tapping the General Conditions filter to mark it as the active drilldown state."
        )
        XCTAssertTrue(
            waitForNonExistence(of: materialsFilterButton, timeout: 5),
            "Expected the Materials filter to disappear while the receipts surface is drilled into General Conditions."
        )

        allCategoriesButton.tap()

        XCTAssertTrue(
            generalFilterButton.waitForExistence(timeout: 5),
            "Expected returning to All categories to keep the category filter controls visible."
        )
        XCTAssertTrue(
            materialsFilterButton.waitForExistence(timeout: 5),
            "Expected returning to All categories to restore the Materials filter control."
        )
        XCTAssertEqual(
            allCategoriesButton.value as? String,
            "selected",
            "Expected the All filter to become active again after clearing the category drilldown."
        )

        materialsFilterButton.tap()

        XCTAssertTrue(
            waitForSelectedValue(on: materialsFilterButton, timeout: 5),
            "Expected tapping the Materials filter to mark it as the active drilldown state."
        )
        XCTAssertTrue(
            waitForNonExistence(of: generalFilterButton, timeout: 5),
            "Expected the General Conditions filter to disappear while the receipts surface is drilled into Materials."
        )
    }

    @MainActor
    func testReceiptsByVendorModeShowsGroupedSummaryForSavedReceipt() throws {
        let app = makeApp(mode: .selectedProject)
        app.launch()
        app.tabBars.buttons["Receipts"].tap()

        let alphaVendorName = "UI Test Vendor Group Alpha"
        saveManualReceipt(in: app, vendorName: alphaVendorName, amount: "10.00")

        let alphaReceiptCard = app.buttons["receipt-card-\(alphaVendorName)"]
        XCTAssertTrue(
            alphaReceiptCard.waitForExistence(timeout: 5),
            "Expected the saved receipt card to render in the default receipts list before switching view modes."
        )

        let byVendorViewModeButton = app.buttons["receipts-view-mode-by-vendor"]
        XCTAssertTrue(
            byVendorViewModeButton.waitForExistence(timeout: 5),
            "Expected the receipts screen to expose the By Vendor view mode."
        )
        byVendorViewModeButton.tap()

        XCTAssertTrue(
            waitForSelectedValue(on: byVendorViewModeButton, timeout: 5),
            "Expected tapping By Vendor to mark the grouped receipts mode as active."
        )

        let alphaGroupButton = app.buttons["receipts-vendor-group-ui-test-vendor-group-alpha"]
        XCTAssertTrue(
            alphaGroupButton.waitForExistence(timeout: 5),
            "Expected vendor-grouped receipts mode to render a group header for the first saved vendor."
        )
        XCTAssertEqual(
            alphaGroupButton.value as? String,
            "collapsed",
            "Expected vendor groups to start collapsed before the test expands one."
        )
        XCTAssertEqual(
            app.staticTexts["receipts-vendor-group-count-ui-test-vendor-group-alpha"].label,
            "1 receipt",
            "Expected the Alpha vendor group to expose its receipt count."
        )
        XCTAssertEqual(
            app.staticTexts["receipts-vendor-group-total-ui-test-vendor-group-alpha"].label,
            "$10.00",
            "Expected the Alpha vendor group to expose its grouped total."
        )
        XCTAssertFalse(
            alphaReceiptCard.exists,
            "Expected grouped vendor mode to hide the flat receipt-card row until a vendor group is expanded."
        )
    }

    @MainActor
    func testReceiptsByVendorModeExpandsAndCollapsesVendorGroup() throws {
        let app = makeApp(mode: .selectedProject)
        app.launch()
        app.tabBars.buttons["Receipts"].tap()

        let alphaVendorName = "UI Test Vendor Toggle Alpha"
        saveManualReceipt(in: app, vendorName: alphaVendorName, amount: "12.34")

        let alphaReceiptCard = app.buttons["receipt-card-\(alphaVendorName)"]
        XCTAssertTrue(
            alphaReceiptCard.waitForExistence(timeout: 5),
            "Expected the saved receipt card to render in the default receipts list before switching to grouped vendor mode."
        )

        let byVendorViewModeButton = app.buttons["receipts-view-mode-by-vendor"]
        XCTAssertTrue(
            byVendorViewModeButton.waitForExistence(timeout: 5),
            "Expected the receipts screen to expose the By Vendor view mode before testing expansion."
        )
        byVendorViewModeButton.tap()

        XCTAssertTrue(
            waitForSelectedValue(on: byVendorViewModeButton, timeout: 5),
            "Expected tapping By Vendor to activate the grouped vendor view before testing expansion."
        )

        let vendorGroupSlug = "ui-test-vendor-toggle-alpha"
        let alphaGroupButton = app.buttons["receipts-vendor-group-\(vendorGroupSlug)"]
        let alphaGroupList = app.otherElements["receipts-vendor-group-list-\(vendorGroupSlug)"]
        XCTAssertTrue(
            alphaGroupButton.waitForExistence(timeout: 5),
            "Expected vendor-grouped receipts mode to render the grouped vendor summary button for the saved vendor."
        )
        tapElement(alphaGroupButton, normalizedOffset: CGVector(dx: 0.25, dy: 0.5))

        XCTAssertTrue(
            waitForAccessibilityValue(on: alphaGroupButton, equals: "expanded", timeout: 5),
            "Expected expanding the vendor group to update the header accessibility value to expanded."
        )
        XCTAssertTrue(
            alphaGroupList.waitForExistence(timeout: 5),
            "Expected expanding the vendor group to reveal the grouped receipt list container."
        )

        tapElement(alphaGroupButton, normalizedOffset: CGVector(dx: 0.25, dy: 0.5))

        XCTAssertTrue(
            waitForAccessibilityValue(on: alphaGroupButton, equals: "collapsed", timeout: 5),
            "Expected collapsing the vendor group to update the header accessibility value back to collapsed."
        )
        XCTAssertTrue(
            waitForNonExistence(of: alphaGroupList, timeout: 5),
            "Expected collapsing the vendor group to hide the grouped receipt list container again."
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
        revealElement(identifier: identifier, in: app, maxSwipes: maxSwipes, query: { $0.buttons[identifier] })
    }

    private func revealElement(
        identifier: String,
        in app: XCUIApplication,
        maxSwipes: Int = 4,
        query: ((XCUIApplication) -> XCUIElement)? = nil
    ) -> XCUIElement {
        let sheetCollection = app.collectionViews.firstMatch
        let resolveElement = query ?? { application in
            let button = application.buttons[identifier]
            if button.exists { return button }

            let otherElement = application.otherElements[identifier]
            if otherElement.exists { return otherElement }

            let picker = application.pickers[identifier]
            if picker.exists { return picker }

            let staticText = application.staticTexts[identifier]
            if staticText.exists { return staticText }

            return application.otherElements[identifier]
        }

        var element = resolveElement(app)

        for _ in 0..<maxSwipes where !element.exists {
            if sheetCollection.exists {
                let start = sheetCollection.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.78))
                let end = sheetCollection.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.48))
                start.press(forDuration: 0.01, thenDragTo: end)
            } else {
                app.swipeUp()
            }
            element = resolveElement(app)
        }

        return element
    }

    private func openManualReceiptEntry(in app: XCUIApplication) {
        let emptyStateManualEntryButton = app.buttons["Manual Entry"]
        if emptyStateManualEntryButton.waitForExistence(timeout: 2) {
            emptyStateManualEntryButton.tap()
            return
        }

        let manualFAB = app.buttons["receipts-fab-manual"]
        XCTAssertTrue(
            manualFAB.waitForExistence(timeout: 5),
            "Expected the receipts screen to expose either the empty-state Manual Entry action or the floating manual entry button."
        )
        manualFAB.tap()
    }

    private func saveManualReceipt(
        in app: XCUIApplication,
        vendorName: String,
        amount: String,
        category: String? = nil
    ) {
        openManualReceiptEntry(in: app)

        let addReceiptNavBar = app.navigationBars["Add Receipt"]
        XCTAssertTrue(
            addReceiptNavBar.waitForExistence(timeout: 5),
            "Expected the Add Receipt sheet to open before exercising the submission path."
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

        let vendorNameField = app.textFields["Vendor Name"]
        XCTAssertTrue(
            vendorNameField.waitForExistence(timeout: 5),
            "Expected the nested add-vendor form to expose the vendor name field."
        )
        vendorNameField.tap()
        vendorNameField.typeText(vendorName)
        addVendorNavBar.buttons["Add"].tap()

        XCTAssertTrue(
            addReceiptNavBar.waitForExistence(timeout: 5),
            "Expected adding a vendor to return directly to the Add Receipt sheet."
        )

        if let category {
            selectReceiptCategory(category, in: app, navigationBar: addReceiptNavBar)
        }

        let amountField = app.textFields["manual-receipt-amount"]
        XCTAssertTrue(
            amountField.waitForExistence(timeout: 5),
            "Expected the Add Receipt sheet to expose the amount field."
        )
        amountField.tap()
        amountField.typeText(amount)

        let saveButton = app.buttons["manual-receipt-save"]
        XCTAssertTrue(
            saveButton.exists,
            "Expected the Add Receipt sheet to expose the save action."
        )
        saveButton.tap()

        XCTAssertTrue(
            waitForNonExistence(of: addReceiptNavBar, timeout: 5),
            "Expected saving the receipt to dismiss the Add Receipt sheet."
        )
    }

    private func selectReceiptCategory(
        _ categoryName: String,
        in app: XCUIApplication,
        navigationBar: XCUIElement
    ) {
        let categoryPicker = revealElement(identifier: "manual-receipt-category", in: app)
        XCTAssertTrue(
            categoryPicker.waitForExistence(timeout: 5),
            "Expected the Add Receipt sheet to expose the category picker."
        )

        if categoryPicker.isHittable {
            categoryPicker.tap()
        } else {
            categoryPicker.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }

        let categoryButton = app.buttons[categoryName]
        if categoryButton.waitForExistence(timeout: 2) {
            categoryButton.tap()
        } else {
            let categoryCellLabel = app.cells.staticTexts[categoryName]
            if categoryCellLabel.waitForExistence(timeout: 2) {
                categoryCellLabel.tap()
            } else {
                let categoryText = app.staticTexts[categoryName]
                if categoryText.waitForExistence(timeout: 2) {
                    categoryText.tap()
                } else {
                    let pickerWheel = app.pickerWheels.firstMatch
                    XCTAssertTrue(
                        pickerWheel.waitForExistence(timeout: 2),
                        "Expected selecting the receipt category to expose a selectable category option or picker wheel."
                    )
                    pickerWheel.adjust(toPickerWheelValue: categoryName)

                    let doneButton = app.toolbars.buttons["Done"]
                    if doneButton.exists {
                        doneButton.tap()
                    }
                }
            }
        }

        XCTAssertTrue(
            navigationBar.waitForExistence(timeout: 5),
            "Expected selecting the receipt category to keep or return the Add Receipt sheet."
        )
    }

    private func openSavedReceiptDetails(in app: XCUIApplication, vendorName: String, amount: String) {
        saveManualReceipt(in: app, vendorName: vendorName, amount: amount)

        let receiptCard = app.buttons["receipt-card-\(vendorName)"]
        XCTAssertTrue(
            receiptCard.waitForExistence(timeout: 8),
            "Expected the saved receipt card to render before opening its detail view."
        )
        receiptCard.tap()

        let detailNavBar = app.navigationBars["Receipt Details"]
        XCTAssertTrue(
            detailNavBar.waitForExistence(timeout: 5),
            "Expected tapping the saved receipt card to navigate to Receipt Details."
        )
    }

    private func replaceText(in element: XCUIElement, with newValue: String, app: XCUIApplication) {
        let existingValue = (element.value as? String) ?? ""
        element.tap()
        element.press(forDuration: 1.1)

        let selectAllMenuItem = app.menuItems["Select All"]
        if selectAllMenuItem.waitForExistence(timeout: 1) {
            selectAllMenuItem.tap()
        }

        element.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: existingValue.count))
        element.typeText(newValue)
    }

    private func tapElement(_ element: XCUIElement, normalizedOffset: CGVector = CGVector(dx: 0.5, dy: 0.5)) {
        if element.isHittable {
            element.tap()
            return
        }

        let absoluteOffset = CGVector(
            dx: element.frame.minX + (element.frame.width * normalizedOffset.dx),
            dy: element.frame.minY + (element.frame.height * normalizedOffset.dy)
        )

        XCUIApplication()
            .coordinate(withNormalizedOffset: .zero)
            .withOffset(absoluteOffset)
            .tap()
    }

    private func waitForNonExistence(of element: XCUIElement, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    private func waitForEnabled(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "enabled == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    private func waitForSelectedValue(on element: XCUIElement, timeout: TimeInterval) -> Bool {
        waitForAccessibilityValue(on: element, equals: "selected", timeout: timeout)
    }

    private func waitForAccessibilityValue(
        on element: XCUIElement,
        equals expectedValue: String,
        timeout: TimeInterval
    ) -> Bool {
        let predicate = NSPredicate(format: "value == %@", expectedValue)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    private func dismissEditingFocusIfNeeded(in app: XCUIApplication, navigationBar: XCUIElement) {
        guard app.keyboards.count > 0 else { return }
        navigationBar.tap()
    }

    private func dismissKeyboardIfPresent(in app: XCUIApplication) {
        guard app.keyboards.count > 0 else { return }

        let candidateButtons = ["Search", "Done", "Return", "return"]
        for label in candidateButtons {
            let button = app.keyboards.buttons[label]
            if button.exists {
                button.tap()
                return
            }
        }

        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1)).tap()
    }

}
