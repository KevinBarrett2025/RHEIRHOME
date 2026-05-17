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
        static let preserveState = "RHEIR_UI_TEST_PRESERVE_STATE"
    }

    private enum UITestLaunchMode: String {
        case signedOut = "signed_out"
        case ready = "ready"
        case noOrganization = "no_organization"
        case selectingOrganization = "selecting_organization"
        case projectSelection = "project_selection"
        case selectedProject = "selected_project"
        case laborManagement = "labor_management"
        case taskManagement = "task_management"
        case estimatorMapping = "estimator_mapping"
        case scannedReceiptReview = "scanned_receipt_review"
        case mixedCategoryReceipt = "mixed_category_receipt"
        case restoredSession = "restored_session"
    }

    private static let selectedProjectCardIdentifier = "project-card-A7A92AF6-2E2B-4F51-BEA4-4B53CF2A7D11"
    private static let completedProjectCardIdentifier = "completed-project-card-2D617D4E-8B4F-4C3A-B874-2F774AAFE61C"
    private static let estimatorMappingReceiptButtonIdentifier = "ai-project-calculator-map-receipt-ui-test-estimator-receipt-001"
    private static let estimatorMappingWorkHourButtonIdentifier = "ai-project-calculator-map-hour-5D8CB53E-67D7-468C-8171-1A0A0C830511"
    private static let estimatorMappingTaskButtonIdentifier = "ai-project-calculator-map-task-8A6A2F75-0B87-4E33-9264-BF6C3E3BC84D"

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

        XCTAssertTrue(
            app.staticTexts["Projects"].waitForExistence(timeout: 5),
            "Expected deterministic ready UI test mode to render the project-selection home."
        )
        XCTAssertTrue(
            app.staticTexts["Choose a project to begin"].exists,
            "Expected fast-ship mode to explain that project context unlocks the work tabs."
        )
        XCTAssertFalse(
            app.tabBars.firstMatch.exists,
            "Expected fast-ship mode to hide the work-tab bar until a project is selected."
        )
        XCTAssertFalse(app.buttons["Company"].exists, "Expected the fast-ship v1 shell to hide the Company tab.")
    }

    @MainActor
    func testOrganizationSelectionModeAutoResolvesIntoReadyShell() throws {
        let app = makeApp(mode: .selectingOrganization)
        app.launch()

        XCTAssertTrue(
            app.staticTexts["Projects"].waitForExistence(timeout: 5),
            "Expected fast-ship v1 mode to bypass the organization picker and resolve directly into the project-selection home."
        )

        XCTAssertFalse(
            app.navigationBars["Organizations"].exists,
            "Expected the organization-selection surface to stay hidden in fast-ship v1 mode."
        )
        XCTAssertFalse(
            app.tabBars.firstMatch.exists,
            "Expected fast-ship v1 mode to hide work tabs until project context is selected."
        )
    }

    @MainActor
    func testNoOrganizationModeUsesFastShipPersonalWorkspace() throws {
        let app = makeApp(mode: .noOrganization)
        app.launch()

        XCTAssertTrue(
            app.staticTexts["Projects"].waitForExistence(timeout: 5),
            "Expected fast-ship v1 mode to create a personal workspace fallback and show the project-selection home."
        )

        XCTAssertFalse(
            app.staticTexts["Create Your Organization"].exists,
            "Expected fast-ship v1 mode to hide legacy organization setup when CloudKit organizations are unavailable."
        )
        XCTAssertFalse(app.tabBars.firstMatch.exists, "Expected work tabs to stay hidden until project context is selected.")
        XCTAssertFalse(app.buttons["Company"].exists, "Expected Company tab to stay hidden in fast-ship v1 mode.")
    }

    @MainActor
    func testProjectSelectionModeRequiresAndAppliesProjectContext() throws {
        let app = makeApp(mode: .projectSelection)
        app.launch()

        XCTAssertTrue(
            app.staticTexts["Projects"].waitForExistence(timeout: 5),
            "Expected deterministic project-selection UI test mode to expose the project-selection home."
        )

        XCTAssertTrue(
            app.staticTexts["Choose a project to begin"].exists,
            "Expected the fast-ship project-selection guidance before a project is chosen."
        )

        XCTAssertFalse(
            app.tabBars.firstMatch.exists,
            "Expected Receipts/Labor/Tasks tabs to stay hidden before a project is selected."
        )

        let projectCard = app.buttons[Self.selectedProjectCardIdentifier]
        XCTAssertTrue(
            projectCard.waitForExistence(timeout: 5),
            "Expected deterministic project-selection UI test mode to expose selectable project cards."
        )
        projectCard.tap()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(
            tabBar.waitForExistence(timeout: 5),
            "Expected work tabs to appear after selecting project context."
        )
        tabBar.buttons["Receipts"].tap()
        XCTAssertTrue(app.staticTexts["No Receipts Yet"].waitForExistence(timeout: 5))

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
    func testBusinessResourcesEntryOpensReusableResourceHub() throws {
        let app = makeApp(mode: .projectSelection)
        app.launch()

        XCTAssertTrue(
            app.staticTexts["Projects"].waitForExistence(timeout: 5),
            "Expected deterministic project-selection mode to show the Projects home."
        )

        let resourcesEntry = app.buttons["business-resources-entry"]
        XCTAssertTrue(
            resourcesEntry.waitForExistence(timeout: 5),
            "Expected fast-ship Projects to expose Business Resources without legacy company/admin UI."
        )
        resourcesEntry.tap()

        XCTAssertTrue(
            app.navigationBars["Business Resources"].waitForExistence(timeout: 5),
            "Expected Business Resources to open as a dedicated contractor setup hub."
        )
        XCTAssertTrue(app.buttons["business-resources-workers-link"].exists)
        XCTAssertTrue(app.buttons["business-resources-vendors-link"].exists)
        XCTAssertTrue(app.buttons["business-resources-payment-methods-link"].exists)
        XCTAssertFalse(
            app.staticTexts["Company"].exists,
            "Expected the v1 resources hub to avoid re-exposing legacy Company workspace copy."
        )

        app.buttons["business-resources-workers-link"].tap()
        XCTAssertTrue(
            app.navigationBars["Workers & Rates"].waitForExistence(timeout: 5),
            "Expected the Workers resource to be backed by a real add/edit surface."
        )
        XCTAssertTrue(app.buttons["business-workers-add-button"].exists)
    }

    @MainActor
    func testProjectSelectionShowsCompletedProjectArchive() throws {
        let app = makeApp(mode: .projectSelection)
        app.launch()

        XCTAssertTrue(
            app.staticTexts["Projects"].waitForExistence(timeout: 5),
            "Expected deterministic project-selection UI test mode to expose the project-selection home."
        )

        XCTAssertTrue(
            app.staticTexts["2 Active Projects"].exists,
            "Expected the active project scope to remain focused on open jobs."
        )

        let completedSegment = app.segmentedControls.buttons["Completed"]
        if completedSegment.waitForExistence(timeout: 3) {
            completedSegment.tap()
        } else {
            app.buttons["Completed"].tap()
        }

        XCTAssertTrue(
            app.staticTexts["1 Completed Project"].waitForExistence(timeout: 5),
            "Expected completed projects to be visible from the Projects screen instead of disappearing."
        )

        let completedProjectCard = app.buttons[Self.completedProjectCardIdentifier]
        XCTAssertTrue(
            completedProjectCard.waitForExistence(timeout: 5),
            "Expected the completed project card to be recoverable from the Completed scope."
        )
        completedProjectCard.tap()

        XCTAssertTrue(
            app.navigationBars["Project Closeout"].waitForExistence(timeout: 5),
            "Expected completed projects to open a closeout detail instead of becoming active work context."
        )
        XCTAssertFalse(
            app.tabBars.firstMatch.exists,
            "Expected viewing completed projects before active selection to keep Receipts/Labor/Tasks hidden."
        )
    }

    @MainActor
    func testCompletedProjectCanBeReopenedIntoActiveWorkContext() throws {
        let app = makeApp(mode: .projectSelection)
        app.launch()

        XCTAssertTrue(
            app.staticTexts["Projects"].waitForExistence(timeout: 5),
            "Expected deterministic project-selection UI test mode to expose the project-selection home."
        )

        let completedSegment = app.segmentedControls.buttons["Completed"]
        if completedSegment.waitForExistence(timeout: 3) {
            completedSegment.tap()
        } else {
            app.buttons["Completed"].tap()
        }

        let completedProjectCard = app.buttons[Self.completedProjectCardIdentifier]
        XCTAssertTrue(
            completedProjectCard.waitForExistence(timeout: 5),
            "Expected the completed project card to be available for reopen."
        )
        completedProjectCard.tap()

        let reopenButton = app.buttons["reopen-completed-project-button"]
        XCTAssertTrue(
            reopenButton.waitForExistence(timeout: 5),
            "Expected completed closeout detail to expose a single reopen action."
        )
        reopenButton.tap()

        let confirmButton = app.buttons["Move to Active"]
        XCTAssertTrue(
            confirmButton.waitForExistence(timeout: 5),
            "Expected reopen confirmation before moving a completed project back to active."
        )
        confirmButton.tap()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(
            tabBar.waitForExistence(timeout: 5),
            "Expected reopening a completed project to restore active project work tabs."
        )

        XCTAssertTrue(
            app.staticTexts["3 Active Projects"].waitForExistence(timeout: 5),
            "Expected the reopened project to return to the Active project scope."
        )

        tabBar.buttons["Receipts"].tap()
        XCTAssertTrue(
            app.staticTexts["Lumber Yard"].waitForExistence(timeout: 5),
            "Expected the reopened project to keep its existing receipt data available for cleanup."
        )
    }

    @MainActor
    func testLaborModeRequiresAndUsesSelectedProjectContext() throws {
        let app = makeApp(mode: .projectSelection)
        app.launch()

        XCTAssertTrue(
            app.staticTexts["Choose a project to begin"].waitForExistence(timeout: 5),
            "Expected project-selection mode to keep users on the context picker before Labor is available."
        )
        XCTAssertFalse(
            app.tabBars.firstMatch.exists,
            "Expected Labor tab to stay hidden before project context is selected."
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
            selectedProjectApp.staticTexts["No Labor Logged Yet"].exists,
            "Expected selected-project mode to show the simplified fast-ship labor empty state."
        )
        XCTAssertTrue(
            selectedProjectApp.buttons["Log Hours"].exists,
            "Expected selected-project mode to keep the log-hours action available."
        )
        XCTAssertFalse(
            selectedProjectApp.staticTexts["Choose a project before viewing or logging labor hours."].exists,
            "Expected the labor project-selection gate to disappear when project context is already seeded."
        )
    }

    @MainActor
    func testLogHoursRateMenuShowsOnlyConfiguredRatesAndCanAddRateInFlow() throws {
        let app = makeApp(mode: .laborManagement)
        app.launch()

        app.tabBars.buttons["Labor"].tap()
        XCTAssertTrue(
            app.staticTexts["Labor Summary"].waitForExistence(timeout: 5),
            "Expected labor-management mode to open the selected-project labor surface."
        )

        let logHoursButton = app.buttons["labor-log-hours-button"]
        XCTAssertTrue(
            logHoursButton.waitForExistence(timeout: 5),
            "Expected Labor to expose the in-context log-hours action."
        )
        logHoursButton.tap()

        XCTAssertTrue(
            app.navigationBars["Log Hours"].waitForExistence(timeout: 5),
            "Expected the log-hours sheet to open."
        )

        app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Select Team Member")
        ).firstMatch.tap()
        app.buttons["Sam Carter"].tap()

        let rateMenu = app.buttons["log-hours-rate-menu"]
        XCTAssertTrue(
            rateMenu.waitForExistence(timeout: 5),
            "Expected a configured-rate menu after choosing a worker."
        )
        rateMenu.tap()

        XCTAssertFalse(
            app.buttons["Select Rate..."].exists,
            "Expected instructional copy to stay out of the selectable rate list."
        )
        XCTAssertTrue(
            app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Framing")).firstMatch.exists,
            "Expected configured worker rates to remain selectable."
        )

        let addRateButton = app.buttons["log-hours-add-rate-button"]
        XCTAssertTrue(
            addRateButton.waitForExistence(timeout: 5),
            "Expected the rate menu to keep the in-flow add-rate action."
        )
        addRateButton.tap()

        XCTAssertTrue(
            app.navigationBars["Edit Sam Carter"].waitForExistence(timeout: 5),
            "Expected adding a missing rate while logging hours to open the worker editor."
        )
        XCTAssertTrue(
            app.staticTexts["Pay Rates"].exists,
            "Expected the worker editor to expose pay-rate management immediately."
        )
    }

    @MainActor
    func testLaborManagementOpensWorkerPaymentLedger() throws {
        let app = makeApp(mode: .laborManagement)
        app.launch()

        app.tabBars.buttons["Labor"].tap()

        XCTAssertTrue(
            app.staticTexts["Labor Summary"].waitForExistence(timeout: 5),
            "Expected labor-management mode to open the selected-project labor surface."
        )
        XCTAssertTrue(app.buttons["labor-manage-workers-button"].exists)
        app.swipeUp()

        let leadWorkerRow = app.buttons["labor-member-row-AA8E5BDE-0B7E-4632-B2D4-DF74D104F0E1"]
        let leadWorkerName = app.staticTexts["labor-member-name-AA8E5BDE-0B7E-4632-B2D4-DF74D104F0E1"]
        XCTAssertTrue(
            leadWorkerName.waitForExistence(timeout: 5) || leadWorkerRow.waitForExistence(timeout: 5),
            "Expected reusable worker resources to appear inside the selected project labor list."
        )
        XCTAssertTrue(app.staticTexts["Sam Carter"].exists)
        XCTAssertTrue(app.staticTexts["4.0 hrs"].exists)
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "$52.00/hr Framing")).firstMatch.exists)
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "$128.00 unpaid")).firstMatch.exists)

        if leadWorkerRow.exists {
            leadWorkerRow.tap()
        } else {
            tapElement(leadWorkerName)
        }

        XCTAssertTrue(
            app.navigationBars["Labor Payment"].waitForExistence(timeout: 5),
            "Expected tapping a worker to open the real labor payment ledger."
        )
        XCTAssertTrue(app.buttons["labor-payment-tab-unpaid"].exists)
        XCTAssertTrue(app.buttons["labor-payment-tab-paid"].exists)
        XCTAssertTrue(app.buttons["labor-unpaid-hour-DA7A5D5E-9150-43EE-B0E4-B9CE93457D15"].exists)

        app.buttons["labor-payment-tab-paid"].tap()
        app.swipeUp()

        let reversiblePaymentButton = app.buttons["labor-payment-unpay-DA7A5D5E-9150-43EE-B0E4-B9CE93457D15"]
        let reversiblePaymentLabel = app.staticTexts["labor-payment-unpay-label-DA7A5D5E-9150-43EE-B0E4-B9CE93457D15"]
        let genericUnpayButton = app.buttons["Unpay"]
        XCTAssertTrue(
            genericUnpayButton.waitForExistence(timeout: 5) ||
            reversiblePaymentButton.waitForExistence(timeout: 5) ||
            reversiblePaymentLabel.waitForExistence(timeout: 5),
            "Expected partially paid labor to expose a reversible payment action."
        )
        XCTAssertTrue(
            app.staticTexts["PARTIAL-01"].exists ||
            app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "PARTIAL-01")).firstMatch.exists,
            "Expected labor payments to preserve reference or check details for correction/reissue."
        )

        let paymentLedgerScreenshot = XCTAttachment(screenshot: app.screenshot())
        paymentLedgerScreenshot.name = "Labor payment paid ledger professional row layout"
        paymentLedgerScreenshot.lifetime = .keepAlways
        add(paymentLedgerScreenshot)
    }

    @MainActor
    func testTasksModeRequiresAndUsesSelectedProjectContext() throws {
        let app = makeApp(mode: .projectSelection)
        app.launch()

        XCTAssertTrue(
            app.staticTexts["Choose a project to begin"].waitForExistence(timeout: 5),
            "Expected project-selection mode to keep users on the context picker before Tasks is available."
        )
        XCTAssertFalse(
            app.tabBars.firstMatch.exists,
            "Expected Tasks tab to stay hidden before project context is selected."
        )

        app.terminate()

        let selectedProjectApp = makeApp(mode: .selectedProject)
        selectedProjectApp.launch()
        selectedProjectApp.tabBars.buttons["Tasks"].tap()

        XCTAssertTrue(
            selectedProjectApp.staticTexts["No Tasks Yet"].waitForExistence(timeout: 5),
            "Expected selected-project mode to show the task empty state."
        )
        XCTAssertTrue(
            selectedProjectApp.buttons["Create First Task"].exists,
            "Expected selected-project mode to keep the primary task creation action available."
        )
        XCTAssertFalse(
            selectedProjectApp.staticTexts["Choose a project before viewing or managing tasks."].exists,
            "Expected the tasks project-selection gate to disappear when project context is already seeded."
        )
    }

    @MainActor
    func testTaskManagementSupportsAssignmentEditingCompletionProofAndRefresh() throws {
        let app = makeApp(mode: .taskManagement)
        app.launch()
        app.tabBars.buttons["Tasks"].tap()

        XCTAssertTrue(
            app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Overdue Tasks (1)")).firstMatch.waitForExistence(timeout: 5),
            "Expected seeded overdue work to surface immediately."
        )
        XCTAssertTrue(app.staticTexts["Assigned: Sam Carter"].exists)

        let overdueTask = app.buttons["task-row-A11B1F20-08A0-4B3B-9A52-9A687EE92001"]
        XCTAssertTrue(overdueTask.waitForExistence(timeout: 5))
        overdueTask.tap()

        XCTAssertTrue(app.navigationBars["Task Details"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["task-detail-mark-complete-button"].exists)
        let bottomActionAttachment = XCTAttachment(screenshot: app.screenshot())
        bottomActionAttachment.name = "Task detail bottom completion action"
        bottomActionAttachment.lifetime = .keepAlways
        add(bottomActionAttachment)
        app.buttons["task-detail-menu"].tap()
        app.buttons["Edit Task"].tap()
        XCTAssertTrue(app.navigationBars["Edit Task"].waitForExistence(timeout: 5))
        let reassignmentWorker = revealElement(
            identifier: "task-worker-BC02E8DE-0E43-4B8A-BA12-4B8E99730BE7",
            in: app
        )
        XCTAssertTrue(reassignmentWorker.exists)
        reassignmentWorker.tap()
        app.buttons["task-save-button"].tap()

        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Mia Lopez")).firstMatch.waitForExistence(timeout: 5))

        XCTAssertTrue(app.buttons["task-detail-mark-complete-button"].waitForExistence(timeout: 5))
        app.buttons["task-detail-mark-complete-button"].tap()
        XCTAssertTrue(app.navigationBars["Complete Task"].waitForExistence(timeout: 5))
        let notesField = app.textFields["Completion notes"]
        XCTAssertTrue(notesField.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["task-proof-photo-button"].exists)
        let proofLibraryButton = revealElement(identifier: "task-proof-library-button", in: app)
        XCTAssertTrue(proofLibraryButton.exists)
        let proofSheetAttachment = XCTAttachment(screenshot: app.screenshot())
        proofSheetAttachment.name = "Task completion photo proof sheet"
        proofSheetAttachment.lifetime = .keepAlways
        add(proofSheetAttachment)
        XCTAssertFalse(
            app.buttons["Complete"].isEnabled,
            "Expected completion to require proof notes before saving."
        )
        notesField.tap()
        notesField.typeText("Framing verified before inspection.")
        XCTAssertTrue(app.buttons["Complete"].isEnabled)
        app.buttons["Complete"].tap()

        XCTAssertTrue(
            app.staticTexts["All Other Tasks (2)"].waitForExistence(timeout: 5),
            "Expected task completion to refresh the live task list immediately."
        )
        XCTAssertFalse(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Overdue Tasks (1)")).firstMatch.exists)

        let completedTask = app.buttons["task-row-A11B1F20-08A0-4B3B-9A52-9A687EE92001"]
        XCTAssertTrue(completedTask.waitForExistence(timeout: 5))
        completedTask.tap()
        XCTAssertTrue(app.staticTexts["Completed By"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Sam Carter")).firstMatch.exists)
    }

    @MainActor
    func testTaskManagementSupportsCreateEditReopenAndDelete() throws {
        let app = makeApp(mode: .taskManagement)
        app.launch()
        app.tabBars.buttons["Tasks"].tap()

        let taskListScreenshot = XCTAttachment(screenshot: app.screenshot())
        taskListScreenshot.name = "Tasks CRUD control bar"
        taskListScreenshot.lifetime = .keepAlways
        add(taskListScreenshot)

        app.buttons["tasks-add-button"].tap()
        XCTAssertTrue(app.navigationBars["New Task"].waitForExistence(timeout: 5))
        let titleField = app.textFields["task-title-field"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5))
        titleField.tap()
        titleField.typeText("Stage backsplash tile")
        XCTAssertTrue(revealElement(identifier: "task-before-camera-button", in: app).exists)
        XCTAssertTrue(revealElement(identifier: "task-before-library-button", in: app).exists)
        let beforePhotoAttachment = XCTAttachment(screenshot: app.screenshot())
        beforePhotoAttachment.name = "Task before photo controls"
        beforePhotoAttachment.lifetime = .keepAlways
        add(beforePhotoAttachment)
        app.buttons["task-save-button"].tap()

        let newTask = app.staticTexts["Stage backsplash tile"]
        XCTAssertTrue(newTask.waitForExistence(timeout: 5))
        newTask.tap()
        XCTAssertTrue(app.navigationBars["Task Details"].waitForExistence(timeout: 5))

        app.buttons["task-detail-menu"].tap()
        app.buttons["task-edit-button"].tap()
        XCTAssertTrue(app.navigationBars["Edit Task"].waitForExistence(timeout: 5))
        let editedTitleField = app.textFields["task-title-field"]
        replaceText(in: editedTitleField, with: "Stage tile materials")
        app.buttons["task-save-button"].tap()
        XCTAssertTrue(
            app.staticTexts["Stage tile materials"].waitForExistence(timeout: 5),
            "Expected detail content to refresh from the live edited task."
        )

        app.buttons["task-detail-menu"].tap()
        app.buttons["task-delete-button"].tap()
        XCTAssertTrue(
            app.staticTexts["All Other Tasks (1)"].waitForExistence(timeout: 5),
            "Expected deleting the newly created task to refresh the live list."
        )

        let overdueTask = app.buttons["task-row-A11B1F20-08A0-4B3B-9A52-9A687EE92001"]
        overdueTask.tap()
        XCTAssertTrue(app.buttons["task-detail-mark-complete-button"].waitForExistence(timeout: 5))
        app.buttons["task-detail-mark-complete-button"].tap()
        let notesField = app.textFields["Completion notes"]
        XCTAssertTrue(notesField.waitForExistence(timeout: 5))
        notesField.tap()
        notesField.typeText("Ready for next trade.")
        app.buttons["Complete"].tap()

        let completedTask = app.buttons["task-row-A11B1F20-08A0-4B3B-9A52-9A687EE92001"]
        XCTAssertTrue(completedTask.waitForExistence(timeout: 5))
        completedTask.tap()
        app.buttons["task-detail-menu"].tap()
        app.buttons["task-reopen-button"].tap()
        XCTAssertTrue(
            app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Overdue Tasks (1)")).firstMatch.waitForExistence(timeout: 5),
            "Expected reopening a task to restore overdue state immediately."
        )
    }

    @MainActor
    func testBudgetSurfaceShowsOnlyFastShipV1Tabs() throws {
        let app = makeApp(mode: .selectedProject)
        app.launch()

        app.tabBars.buttons["Projects"].tap()

        let projectCard = app.buttons[Self.selectedProjectCardIdentifier]
        XCTAssertTrue(
            projectCard.waitForExistence(timeout: 5),
            "Expected deterministic selected-project mode to expose the seeded Kitchen Remodel project card."
        )
        projectCard.tap()

        XCTAssertTrue(
            app.buttons["budget-tab-breakdown"].waitForExistence(timeout: 5),
            "Expected the budget surface to expose the Breakdown tab."
        )
        XCTAssertTrue(
            app.buttons["budget-tab-estimator"].exists,
            "Expected the budget surface to keep the Estimator tab in fast-ship v1 mode."
        )
        XCTAssertFalse(app.buttons["budget-tab-team"].exists, "Expected Team tab to stay hidden in fast-ship v1 mode.")
        XCTAssertFalse(app.buttons["budget-tab-vendors"].exists, "Expected Vendors tab to stay hidden in fast-ship v1 mode.")
        XCTAssertFalse(app.buttons["budget-tab-payments"].exists, "Expected Payments tab to stay hidden in fast-ship v1 mode.")
    }

    @MainActor
    func testProjectReportsPreviewSurfaceExposesPDFAndCSVExports() throws {
        let app = makeApp(mode: .selectedProject)
        app.launch()

        app.tabBars.buttons["Projects"].tap()

        let projectCard = app.buttons[Self.selectedProjectCardIdentifier]
        XCTAssertTrue(
            projectCard.waitForExistence(timeout: 5),
            "Expected the seeded project card before opening project reports."
        )
        projectCard.tap()

        let reportsEntry = revealButton(identifier: "project-reports-entry", in: app, maxSwipes: 6)
        XCTAssertTrue(
            reportsEntry.exists,
            "Expected the budget breakdown to expose the live reports entry."
        )
        reportsEntry.tap()

        XCTAssertTrue(
            app.navigationBars["Project Reports"].waitForExistence(timeout: 5),
            "Expected project reports to open as a live sheet."
        )

        let pdfPreviewButton = revealElement(
            identifier: "Preview Project Report",
            in: app,
            maxSwipes: 6,
            query: { $0.buttons["Preview Project Report"] }
        )
        XCTAssertTrue(pdfPreviewButton.exists)
        XCTAssertTrue(
            revealElement(
                identifier: "Export Receipt Line Items",
                in: app,
                maxSwipes: 6,
                query: { $0.buttons["Export Receipt Line Items"] }
            ).exists
        )
        XCTAssertTrue(
            revealElement(
                identifier: "Export Labor Payment Ledger",
                in: app,
                maxSwipes: 6,
                query: { $0.buttons["Export Labor Payment Ledger"] }
            ).exists
        )
        XCTAssertTrue(
            revealElement(
                identifier: "Preview Task Closeout",
                in: app,
                maxSwipes: 6,
                query: { $0.buttons["Preview Task Closeout"] }
            ).exists
        )
        pdfPreviewButton.tap()

        let pdfPreview = app.descendants(matching: .any)["project-report-pdf-preview"]
        XCTAssertTrue(
            pdfPreview.waitForExistence(timeout: 8),
            "Expected the field report to render a preview before export."
        )
        XCTAssertTrue(app.buttons["project-report-preview-export"].exists)

        let pdfPreviewAttachment = XCTAttachment(screenshot: app.screenshot())
        pdfPreviewAttachment.name = "Project PDF preview"
        pdfPreviewAttachment.lifetime = .keepAlways
        add(pdfPreviewAttachment)

        app.buttons["project-report-preview-done"].tap()

        let tasksPreviewButton = revealElement(
            identifier: "Preview Task Closeout",
            in: app,
            maxSwipes: 6,
            query: { $0.buttons["Preview Task Closeout"] }
        )
        XCTAssertTrue(tasksPreviewButton.exists)
        tasksPreviewButton.tap()

        let csvPreview = app.descendants(matching: .any)["project-report-csv-preview"]
        XCTAssertTrue(
            csvPreview.waitForExistence(timeout: 5),
            "Expected structured CSV exports to render a readable preview before export."
        )
        XCTAssertTrue(app.buttons["project-report-preview-export"].exists)
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
    func testManualReceiptPersistsAcrossFastShipRelaunch() throws {
        let vendorName = "UI Test Relaunch Vendor"
        let amount = "123.45"

        let app = makeApp(mode: .selectedProject)
        app.launch()
        app.tabBars.buttons["Receipts"].tap()

        saveManualReceipt(in: app, vendorName: vendorName, amount: amount)

        let receiptCard = app.buttons["receipt-card-\(vendorName)"]
        XCTAssertTrue(
            receiptCard.waitForExistence(timeout: 8),
            "Expected the saved receipt to appear before terminating the app for relaunch coverage."
        )

        app.terminate()

        let restoredApp = makeApp(mode: .restoredSession, preserveState: true)
        restoredApp.launch()

        let tabBar = restoredApp.tabBars.firstMatch
        XCTAssertTrue(
            tabBar.waitForExistence(timeout: 5),
            "Expected the relaunch-preserving UI test mode to resolve back into the main tab shell."
        )

        restoredApp.tabBars.buttons["Receipts"].tap()

        XCTAssertFalse(
            restoredApp.staticTexts["Choose a project from the Projects tab before viewing receipts."].exists,
            "Expected the selected project context to restore after relaunch."
        )
        XCTAssertTrue(
            restoredApp.buttons["receipt-card-\(vendorName)"].waitForExistence(timeout: 8),
            "Expected the saved receipt card to persist after terminating and relaunching the fast-ship app shell."
        )

        restoredApp.buttons["receipt-card-\(vendorName)"].tap()

        XCTAssertTrue(
            restoredApp.navigationBars["Receipt Details"].waitForExistence(timeout: 5),
            "Expected the persisted receipt to remain navigable after relaunch."
        )
        XCTAssertEqual(
            restoredApp.staticTexts["receipt-detail-vendor"].label,
            vendorName,
            "Expected the relaunch-restored receipt detail header to keep the saved vendor."
        )
        XCTAssertEqual(
            restoredApp.staticTexts["receipt-detail-amount"].label,
            "$123.45",
            "Expected the relaunch-restored receipt detail header to keep the saved amount."
        )
    }

    @MainActor
    func testScannedReceiptPersistsAfterLeavingAndReturningToReceipts() throws {
        let vendorName = "UI Test Scanned Vendor"

        let app = makeApp(mode: .scannedReceiptReview)
        app.launch()
        app.tabBars.buttons["Receipts"].tap()

        let scannedReceiptNavBar = app.navigationBars["AI-Scanned Receipt"]
        XCTAssertTrue(
            scannedReceiptNavBar.waitForExistence(timeout: 5),
            "Expected the seeded scanned-receipt review flow to present the real AI-scanned receipt sheet."
        )
        XCTAssertTrue(
            app.textFields["receipt-scan-vendor"].waitForExistence(timeout: 5),
            "Expected the scanned-receipt review sheet to expose the editable vendor field."
        )
        XCTAssertTrue(
            app.textFields["receipt-scan-payment-method"].exists,
            "Expected the scanned-receipt review sheet to expose the editable payment method field."
        )
        XCTAssertTrue(
            app.textFields["receipt-scan-tax"].exists,
            "Expected the scanned-receipt review sheet to expose the editable tax field."
        )
        let receiptNumberField = revealElement(
            identifier: "receipt-scan-receipt-number",
            in: app,
            query: { $0.textFields["receipt-scan-receipt-number"] }
        )
        XCTAssertTrue(
            receiptNumberField.exists,
            "Expected the scanned-receipt review sheet to expose the editable receipt number field."
        )
        let imagePreview = revealElement(
            identifier: "receipt-scan-image-preview",
            in: app,
            query: { $0.images["receipt-scan-image-preview"] }
        )
        XCTAssertTrue(
            imagePreview.exists,
            "Expected the scanned-receipt review sheet to keep a visible preview of the source image before saving."
        )
        let imagePreviewAttachment = XCTAttachment(screenshot: app.screenshot())
        imagePreviewAttachment.name = "Scanned receipt review image preview"
        imagePreviewAttachment.lifetime = .keepAlways
        add(imagePreviewAttachment)

        let saveButton = app.buttons["receipt-scan-save"]
        XCTAssertTrue(
            waitForEnabled(saveButton, timeout: 5),
            "Expected the seeded scanned-receipt review flow to allow saving without extra manual repair."
        )
        saveButton.tap()

        let successAlert = app.alerts["Receipt Added Successfully"]
        XCTAssertTrue(
            successAlert.waitForExistence(timeout: 8),
            "Expected saving the scanned receipt review to surface the success alert."
        )
        successAlert.buttons["OK"].tap()

        XCTAssertTrue(
            waitForNonExistence(of: scannedReceiptNavBar, timeout: 5),
            "Expected confirming the scanned-receipt success alert to dismiss the review sheet."
        )

        let receiptCard = app.buttons["receipt-card-\(vendorName)"]
        XCTAssertTrue(
            receiptCard.waitForExistence(timeout: 8),
            "Expected the scanned receipt to render in the selected-project receipts list after saving."
        )

        app.tabBars.buttons["Projects"].tap()
        app.tabBars.buttons["Receipts"].tap()

        XCTAssertTrue(
            app.buttons["receipt-card-\(vendorName)"].waitForExistence(timeout: 5),
            "Expected the saved scanned receipt to remain visible after leaving and returning to the receipts surface."
        )
        app.buttons["receipt-card-\(vendorName)"].tap()

        XCTAssertTrue(
            app.navigationBars["Receipt Details"].waitForExistence(timeout: 5),
            "Expected the saved scanned receipt to reopen from the receipts list after returning."
        )
        XCTAssertEqual(
            app.staticTexts["receipt-detail-vendor"].label,
            vendorName,
            "Expected the reopened scanned receipt detail to keep the saved vendor."
        )
        XCTAssertEqual(
            app.staticTexts["receipt-detail-amount"].label,
            "$89.76",
            "Expected the reopened scanned receipt detail to keep the saved amount."
        )
        XCTAssertEqual(
            app.staticTexts["receipt-detail-category"].label,
            "Materials",
            "Expected the reopened scanned receipt detail to keep the seeded category."
        )
        XCTAssertEqual(
            app.staticTexts["receipt-detail-items-header"].label,
            "Items (2)",
            "Expected the reopened scanned receipt detail to keep the persisted item count."
        )
        XCTAssertTrue(
            app.staticTexts["receipt-detail-item-primer"].exists,
            "Expected the first scanned receipt item to persist into the saved receipt detail."
        )
        XCTAssertTrue(
            app.staticTexts["receipt-detail-item-brush-set"].exists,
            "Expected the second scanned receipt item to persist into the saved receipt detail."
        )
        XCTAssertTrue(
            app.images["receipt-detail-image-preview"].exists,
            "Expected the saved scanned receipt to keep a visible receipt-image preview in detail."
        )
    }

    @MainActor
    func testSavedScannedReceiptEditSheetShowsPersistedItems() throws {
        let app = makeApp(mode: .scannedReceiptReview)
        app.launch()
        app.tabBars.buttons["Receipts"].tap()

        let vendorName = "UI Test Scanned Vendor"
        let scannedReceiptNavBar = app.navigationBars["AI-Scanned Receipt"]
        XCTAssertTrue(
            scannedReceiptNavBar.waitForExistence(timeout: 5),
            "Expected the seeded scanned-receipt review flow to present the review sheet before testing edit persistence."
        )

        let saveButton = app.buttons["receipt-scan-save"]
        XCTAssertTrue(
            waitForEnabled(saveButton, timeout: 5),
            "Expected the seeded scanned receipt review to be savable before testing the saved edit sheet."
        )
        saveButton.tap()

        let successAlert = app.alerts["Receipt Added Successfully"]
        XCTAssertTrue(
            successAlert.waitForExistence(timeout: 8),
            "Expected saving the scanned receipt review to surface the success alert."
        )
        successAlert.buttons["OK"].tap()

        XCTAssertTrue(
            waitForNonExistence(of: scannedReceiptNavBar, timeout: 5),
            "Expected confirming the scanned receipt success alert to dismiss the review sheet."
        )

        let receiptCard = app.buttons["receipt-card-\(vendorName)"]
        XCTAssertTrue(
            receiptCard.waitForExistence(timeout: 8),
            "Expected the saved scanned receipt to render in the receipts list before opening detail."
        )
        receiptCard.tap()

        XCTAssertTrue(
            app.navigationBars["Receipt Details"].waitForExistence(timeout: 5),
            "Expected the saved scanned receipt to reopen from the receipts list before testing its edit sheet."
        )

        openReceiptActionsMenu(in: app)

        let editButton = receiptDetailMenuAction(
            identifier: "receipt-detail-menu-edit",
            fallbackTitle: "Edit Receipt",
            in: app
        )
        XCTAssertTrue(
            editButton.waitForExistence(timeout: 5),
            "Expected the receipt detail actions menu to expose the edit action for the saved scanned receipt."
        )
        editButton.tap()

        let editReceiptNavBar = app.navigationBars["Edit Receipt"]
        XCTAssertTrue(
            editReceiptNavBar.waitForExistence(timeout: 5),
            "Expected tapping the receipt detail edit action to open the Edit Receipt sheet."
        )

        let itemizedHeader = revealElement(
            identifier: "receipt-edit-items-header",
            in: app,
            query: { $0.staticTexts["receipt-edit-items-header"] }
        )
        XCTAssertTrue(
            itemizedHeader.exists,
            "Expected the saved scanned receipt edit sheet to expose the persisted itemized breakdown section."
        )

        let primerRow = revealElement(
            identifier: "receipt-edit-item-primer",
            in: app,
            query: { $0.buttons["receipt-edit-item-primer"] }
        )
        XCTAssertTrue(
            primerRow.exists,
            "Expected the saved scanned receipt edit sheet to expose the persisted Primer line item."
        )

        let brushSetRow = revealElement(
            identifier: "receipt-edit-item-brush-set",
            in: app,
            query: { $0.buttons["receipt-edit-item-brush-set"] }
        )
        XCTAssertTrue(
            brushSetRow.exists,
            "Expected the saved scanned receipt edit sheet to expose the persisted Brush Set line item."
        )

        primerRow.tap()

        let lineItemNavBar = app.navigationBars["Edit Line Item"]
        XCTAssertTrue(
            lineItemNavBar.waitForExistence(timeout: 5),
            "Expected tapping a saved scanned receipt item to open its line-item editor."
        )
        XCTAssertTrue(
            app.textFields["receipt-edit-line-item-name"].waitForExistence(timeout: 5),
            "Expected the line-item editor to expose the editable item name field."
        )

        lineItemNavBar.buttons["Cancel"].tap()
        XCTAssertTrue(
            editReceiptNavBar.waitForExistence(timeout: 5),
            "Expected cancelling the line-item editor to return to the parent receipt edit sheet."
        )
    }

    @MainActor
    func testSavedScannedReceiptOpensPartialRefundFlow() throws {
        let app = makeApp(mode: .scannedReceiptReview)
        app.launch()
        app.tabBars.buttons["Receipts"].tap()

        let vendorName = "UI Test Scanned Vendor"
        let scannedReceiptNavBar = app.navigationBars["AI-Scanned Receipt"]
        XCTAssertTrue(
            scannedReceiptNavBar.waitForExistence(timeout: 5),
            "Expected the seeded scanned-receipt review flow before testing partial refunds."
        )

        let saveButton = app.buttons["receipt-scan-save"]
        XCTAssertTrue(
            waitForEnabled(saveButton, timeout: 5),
            "Expected the seeded scanned receipt review to be savable before testing partial refunds."
        )
        saveButton.tap()

        let successAlert = app.alerts["Receipt Added Successfully"]
        XCTAssertTrue(
            successAlert.waitForExistence(timeout: 8),
            "Expected saving the scanned receipt review to surface the success alert."
        )
        successAlert.buttons["OK"].tap()

        XCTAssertTrue(
            waitForNonExistence(of: scannedReceiptNavBar, timeout: 5),
            "Expected confirming the scanned receipt success alert to dismiss the review sheet."
        )

        let receiptCard = app.buttons["receipt-card-\(vendorName)"]
        XCTAssertTrue(
            receiptCard.waitForExistence(timeout: 8),
            "Expected the scanned receipt to render before opening the partial refund flow."
        )
        receiptCard.tap()

        XCTAssertTrue(
            app.navigationBars["Receipt Details"].waitForExistence(timeout: 5),
            "Expected the saved scanned receipt to reopen from the receipts list."
        )

        openReceiptActionsMenu(in: app)
        let editButton = receiptDetailMenuAction(
            identifier: "receipt-detail-menu-edit",
            fallbackTitle: "Edit Receipt",
            in: app
        )
        XCTAssertTrue(
            editButton.waitForExistence(timeout: 5),
            "Expected the receipt detail actions menu to expose Edit Receipt before line-item refunds."
        )
        editButton.tap()

        let primerRow = revealElement(
            identifier: "receipt-edit-item-primer",
            in: app,
            query: { $0.buttons["receipt-edit-item-primer"] }
        )
        XCTAssertTrue(
            primerRow.waitForExistence(timeout: 5),
            "Expected the receipt editor to expose the persisted Primer line item before refunding it."
        )
        primerRow.swipeLeft()

        let refundButton = app.buttons["receipt-edit-item-refund-primer"]
        XCTAssertTrue(
            refundButton.waitForExistence(timeout: 5),
            "Expected swiping an editable receipt line item to expose the row-level Refund action."
        )
        refundButton.tap()

        let refundAlert = app.alerts["Refund Primer?"]
        XCTAssertTrue(
            refundAlert.waitForExistence(timeout: 5),
            "Expected the row-level Refund action to ask for confirmation."
        )
        XCTAssertTrue(
            refundAlert.staticTexts["Refund $43.50 for this line item including $3.52 tax."].exists,
            "Expected the confirmation to include the item-level tax allocation."
        )

        let previewAttachment = XCTAttachment(screenshot: app.screenshot())
        previewAttachment.name = "Receipt line-item refund confirmation"
        previewAttachment.lifetime = .keepAlways
        add(previewAttachment)

        refundAlert.buttons["Refund"].tap()

        XCTAssertTrue(
            app.navigationBars["Receipt Details"].waitForExistence(timeout: 5),
            "Expected saving a partial refund to return to the source receipt detail."
        )
        XCTAssertEqual(
            app.staticTexts["receipt-detail-refunded-total"].label,
            "$43.50",
            "Expected the source receipt detail to show the linked refund total immediately after save."
        )
        XCTAssertEqual(
            app.staticTexts["receipt-detail-refundable-remaining"].label,
            "$46.26",
            "Expected the source receipt detail to preserve the remaining refundable gross balance."
        )
        let linkedRefundRow = revealElement(
            identifier: "receipt-detail-linked-refund-primer",
            in: app,
            query: { $0.buttons["receipt-detail-linked-refund-primer"] }
        )
        XCTAssertTrue(
            linkedRefundRow.exists,
            "Expected the linked refund to render as a sub receipt on the source receipt detail."
        )
        let refundedItemStatus = revealElement(
            identifier: "receipt-detail-item-refund-status-primer",
            in: app,
            query: { $0.staticTexts["receipt-detail-item-refund-status-primer"] }
        )
        XCTAssertEqual(
            refundedItemStatus.label,
            "REFUNDED",
            "Expected the source item row to show that the item has been refunded."
        )
        openReceiptActionsMenu(in: app)
        let postRefundEditButton = receiptDetailMenuAction(
            identifier: "receipt-detail-menu-edit",
            fallbackTitle: "Edit Receipt",
            in: app
        )
        XCTAssertTrue(
            postRefundEditButton.waitForExistence(timeout: 5),
            "Expected the source receipt to remain editable after recording a linked refund."
        )
        postRefundEditButton.tap()
        let editRefundedItemStatus = revealElement(
            identifier: "receipt-edit-item-refund-status-primer",
            in: app,
            query: { $0.staticTexts["receipt-edit-item-refund-status-primer"] }
        )
        XCTAssertEqual(
            editRefundedItemStatus.label,
            "REFUNDED",
            "Expected the edit receipt itemized list to label already refunded items."
        )
        app.buttons["Cancel"].tap()
        XCTAssertTrue(
            app.navigationBars["Receipt Details"].waitForExistence(timeout: 5),
            "Expected cancelling the receipt editor to return to source receipt detail."
        )

        let summaryAttachment = XCTAttachment(screenshot: app.screenshot())
        summaryAttachment.name = "Receipt refund summary after save"
        summaryAttachment.lifetime = .keepAlways
        add(summaryAttachment)

        app.terminate()

        let restoredApp = makeApp(mode: .restoredSession, preserveState: true)
        restoredApp.launch()

        XCTAssertTrue(
            restoredApp.tabBars.firstMatch.waitForExistence(timeout: 5),
            "Expected the preserved session to restore after recording a partial refund."
        )
        restoredApp.tabBars.buttons["Receipts"].tap()

        let restoredSourceReceiptCard = restoredApp.buttons["receipt-card-\(vendorName)"]
        XCTAssertTrue(
            restoredSourceReceiptCard.waitForExistence(timeout: 8),
            "Expected the original scanned receipt to persist after relaunch."
        )
        XCTAssertEqual(
            restoredApp.buttons.matching(identifier: "receipt-card-\(vendorName)").count,
            1,
            "Expected the linked refund to render under the original receipt instead of as a duplicate top-level receipt card."
        )
        let restoredLinkedRefundToggle = restoredApp.buttons["receipt-card-linked-refunds-toggle-ui-test-scanned-vendor"]
        XCTAssertTrue(
            restoredLinkedRefundToggle.waitForExistence(timeout: 5),
            "Expected linked refunds to be summarized in a collapsed child receipt disclosure after relaunch."
        )
        XCTAssertEqual(
            restoredLinkedRefundToggle.value as? String,
            "collapsed",
            "Expected linked refund receipt rows to stay collapsed by default."
        )

        let refundedFilter = restoredApp.buttons["receipts-refund-filter-refunded"]
        XCTAssertTrue(
            refundedFilter.waitForExistence(timeout: 5),
            "Expected the receipts screen to expose the refunded-purchase filter."
        )
        refundedFilter.tap()
        XCTAssertEqual(
            restoredApp.staticTexts["receipts-filter-summary-refunded"].label,
            "$43.50",
            "Expected the refunded filter summary to show the linked refund total."
        )

        let refundReceiptsFilter = restoredApp.buttons["receipts-refund-filter-refund-receipts"]
        XCTAssertTrue(
            refundReceiptsFilter.waitForExistence(timeout: 5),
            "Expected the receipts screen to expose the refund-receipts filter."
        )
        refundReceiptsFilter.tap()
        XCTAssertEqual(
            restoredApp.staticTexts["receipts-filter-summary-net"].label,
            "-$43.50",
            "Expected the refund-receipts filter to summarize return receipts as negative cash flow."
        )

        let allRefundsFilter = restoredApp.buttons["receipts-refund-filter-all"]
        allRefundsFilter.tap()
        let filterChips = restoredApp.scrollViews["receipts-filter-chips"]
        if filterChips.exists {
            filterChips.swipeLeft()
        }
        let visaPaymentFilter = restoredApp.buttons["receipts-payment-filter-visa-4242"]
        XCTAssertTrue(
            visaPaymentFilter.waitForExistence(timeout: 5),
            "Expected the receipts screen to expose a card/payment-method filter with card details."
        )
        visaPaymentFilter.tap()
        XCTAssertEqual(
            restoredApp.staticTexts["receipts-filter-summary-purchases"].label,
            "$89.76",
            "Expected the payment filter to preserve gross card spend."
        )
        XCTAssertEqual(
            restoredApp.staticTexts["receipts-filter-summary-refunded"].label,
            "$43.50",
            "Expected the payment filter to expose card refunds."
        )
        XCTAssertEqual(
            restoredApp.staticTexts["receipts-filter-summary-net"].label,
            "$46.26",
            "Expected the payment filter to show net card spend after refunds."
        )
        restoredApp.buttons["receipts-payment-filter-all"].tap()

        let postFilterLinkedRefundToggle = restoredApp.buttons["receipt-card-linked-refunds-toggle-ui-test-scanned-vendor"]
        XCTAssertTrue(
            postFilterLinkedRefundToggle.waitForExistence(timeout: 5),
            "Expected the linked refund disclosure to remain available after clearing payment filters."
        )
        postFilterLinkedRefundToggle.tap()
        let restoredLinkedRefundRow = restoredApp.buttons["receipt-card-linked-refund-ui-test-scanned-vendor-primer"]
        XCTAssertTrue(
            restoredLinkedRefundRow.waitForExistence(timeout: 5),
            "Expected expanding linked refunds to reveal the child refund receipt below the source receipt."
        )
        restoredLinkedRefundRow.tap()

        let reverseRefundButton = revealElement(
            identifier: "receipt-detail-reverse-refund",
            in: restoredApp,
            query: { $0.buttons["receipt-detail-reverse-refund"] }
        )
        XCTAssertTrue(
            reverseRefundButton.waitForExistence(timeout: 5),
            "Expected a linked refund receipt detail to expose a visible reversal action."
        )
        reverseRefundButton.tap()

        let reverseAlert = restoredApp.alerts["Reverse Refund?"]
        XCTAssertTrue(
            reverseAlert.waitForExistence(timeout: 5),
            "Expected reversing a refund to require confirmation."
        )
        reverseAlert.buttons["Reverse Refund"].tap()

        let reversedSourceReceiptCard = restoredApp.buttons["receipt-card-\(vendorName)"]
        XCTAssertTrue(
            reversedSourceReceiptCard.waitForExistence(timeout: 8),
            "Expected reversing the linked refund to return to the receipts list with the source receipt still visible."
        )
        XCTAssertTrue(
            waitForNonExistence(
                of: restoredApp.buttons["receipt-card-linked-refunds-toggle-ui-test-scanned-vendor"],
                timeout: 5
            ),
            "Expected reversing the refund to remove the linked refund disclosure from the source receipt."
        )
        reversedSourceReceiptCard.tap()

        XCTAssertTrue(
            restoredApp.navigationBars["Receipt Details"].waitForExistence(timeout: 5),
            "Expected the source receipt to remain navigable after reversing the linked refund."
        )
        XCTAssertEqual(
            restoredApp.staticTexts["receipt-detail-amount"].label,
            "$89.76",
            "Expected reversal coverage to reopen the original source receipt rather than a linked refund."
        )
        XCTAssertFalse(
            restoredApp.staticTexts["receipt-detail-refunded-total"].exists,
            "Expected reversing the refund to remove the source receipt refund summary."
        )

        let relaunchAttachment = XCTAttachment(screenshot: restoredApp.screenshot())
        relaunchAttachment.name = "Receipt refund filters and reversal after relaunch"
        relaunchAttachment.lifetime = .keepAlways
        add(relaunchAttachment)
    }

    @MainActor
    func testSavedReceiptDetailOpensEditSheet() throws {
        let app = makeApp(mode: .selectedProject)
        app.launch()
        app.tabBars.buttons["Receipts"].tap()

        openSavedReceiptDetails(in: app, vendorName: "UI Test Editable Vendor", amount: "45.67")

        openReceiptActionsMenu(in: app)

        let editButton = receiptDetailMenuAction(
            identifier: "receipt-detail-menu-edit",
            fallbackTitle: "Edit Receipt",
            in: app
        )
        XCTAssertTrue(
            editButton.waitForExistence(timeout: 5),
            "Expected the receipt detail actions menu to expose the edit action."
        )
        editButton.tap()

        let editReceiptNavBar = app.navigationBars["Edit Receipt"]
        XCTAssertTrue(
            editReceiptNavBar.waitForExistence(timeout: 5),
            "Expected the receipt detail actions menu to open the Edit Receipt sheet."
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

        openReceiptActionsMenu(in: app)

        let deleteButton = receiptDetailMenuAction(
            identifier: "receipt-detail-menu-delete",
            fallbackTitle: "Delete Receipt",
            in: app
        )
        XCTAssertTrue(
            deleteButton.waitForExistence(timeout: 5),
            "Expected the receipt detail actions menu to expose the delete action."
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

        openReceiptActionsMenu(in: app)

        let editButton = receiptDetailMenuAction(
            identifier: "receipt-detail-menu-edit",
            fallbackTitle: "Edit Receipt",
            in: app
        )
        XCTAssertTrue(
            editButton.waitForExistence(timeout: 5),
            "Expected the receipt detail actions menu to expose the edit action before testing persistence."
        )
        editButton.tap()

        let editReceiptNavBar = app.navigationBars["Edit Receipt"]
        XCTAssertTrue(
            editReceiptNavBar.waitForExistence(timeout: 5),
            "Expected tapping the receipt detail actions menu to open the Edit Receipt sheet."
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
    func testMixedCategoryReceiptCategoryDrilldownUsesItemizedSpend() throws {
        let app = makeApp(mode: .mixedCategoryReceipt)
        app.launch()
        app.tabBars.buttons["Receipts"].tap()

        let categoriesViewModeButton = app.buttons["receipts-view-mode-categories"]
        XCTAssertTrue(
            categoriesViewModeButton.waitForExistence(timeout: 5),
            "Expected the receipts screen to expose the Categories view mode for mixed-category receipt coverage."
        )
        categoriesViewModeButton.tap()

        XCTAssertEqual(
            app.staticTexts["receipts-category-summary-total-plumbing"].label,
            "$12.34",
            "Expected the Plumbing category summary to use the itemized plumbing spend, not the full receipt total."
        )
        XCTAssertEqual(
            app.staticTexts["receipts-category-summary-total-framing"].label,
            "$15.55",
            "Expected the Framing category summary to use the itemized framing spend, not the full receipt total."
        )
        XCTAssertEqual(
            app.staticTexts["receipts-category-summary-total-roofing"].label,
            "$8.40",
            "Expected the Roofing category summary to use the itemized roofing spend, not the full receipt total."
        )

        let framingFilterButton = app.buttons["receipts-category-filter-framing"]
        XCTAssertTrue(
            framingFilterButton.waitForExistence(timeout: 5),
            "Expected the mixed-category seeded receipt to expose the Framing category filter."
        )
        framingFilterButton.tap()

        XCTAssertTrue(
            waitForSelectedValue(on: framingFilterButton, timeout: 5),
            "Expected tapping the Framing category filter to drill into the itemized framing spend."
        )
        XCTAssertEqual(
            app.staticTexts["receipts-category-drilldown-total-framing"].label,
            "$15.55",
            "Expected the selected Framing header to show the itemized category total at a glance."
        )
        XCTAssertEqual(
            app.staticTexts["receipts-category-drilldown-count-framing"].label,
            "1 receipt with Framing spend",
            "Expected the selected Framing header to show how many receipts contribute itemized spend."
        )
        XCTAssertEqual(
            app.staticTexts["receipt-card-amount-ui-test-mixed-category-vendor-framing"].label,
            "$15.55",
            "Expected the drilled-in mixed-category receipt card to show only the scoped framing spend."
        )
        XCTAssertEqual(
            app.staticTexts["receipt-card-category-ui-test-mixed-category-vendor-framing"].label,
            "Framing",
            "Expected the drilled-in mixed-category receipt card to label itself with the selected itemized category."
        )
    }

    @MainActor
    func testReceiptCardQuickViewShowsSavedReceiptImage() throws {
        let app = makeApp(mode: .mixedCategoryReceipt)
        app.launch()
        app.tabBars.buttons["Receipts"].tap()

        let viewImageButton = app.buttons["receipt-card-view-image-ui-test-mixed-category-vendor"]
        XCTAssertTrue(
            viewImageButton.waitForExistence(timeout: 5),
            "Expected the saved receipt card to expose the quick image preview action."
        )
        viewImageButton.tap()

        let closeButton = app.buttons["zoomable-image-close"]
        XCTAssertTrue(
            closeButton.waitForExistence(timeout: 5),
            "Expected tapping the receipt-card quick view action to present the real receipt image viewer."
        )
        closeButton.tap()

        XCTAssertTrue(
            waitForNonExistence(of: closeButton, timeout: 5),
            "Expected dismissing the quick receipt image preview to close the viewer."
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
    func testAIProjectCalculatorBuildsAndApprovesDraftEstimate() throws {
        let app = makeApp(mode: .selectedProject)
        app.launch()

        openAIProjectCalculator(in: app)
        buildAndApproveEstimatorDraft(in: app)

        let varianceDashboard = app.staticTexts["ai-project-calculator-variance-dashboard"]
        XCTAssertTrue(
            varianceDashboard.waitForExistence(timeout: 8),
            "Expected approving the estimator draft to render the live variance dashboard."
        )
    }

    @MainActor
    func testAIProjectCalculatorMapsActualsAndUpdatesVariance() throws {
        let app = makeApp(mode: .estimatorMapping)
        app.launch()

        openAIProjectCalculator(in: app)
        buildAndApproveEstimatorDraft(in: app, disableAutoGenerateStarterTasks: true)

        let mappingHeader = revealElement(identifier: "ai-project-calculator-needs-mapping", in: app, maxSwipes: 8)
        XCTAssertTrue(
            mappingHeader.exists,
            "Expected the approved estimator baseline to expose the live mapping queue for seeded actuals."
        )

        mapEstimatorActual(identifier: Self.estimatorMappingReceiptButtonIdentifier, in: app)
        mapEstimatorActual(identifier: Self.estimatorMappingWorkHourButtonIdentifier, in: app)
        mapEstimatorActual(identifier: Self.estimatorMappingTaskButtonIdentifier, in: app)

        let mappingEmptyState = revealElement(
            identifier: "ai-project-calculator-needs-mapping-empty",
            in: app,
            maxSwipes: 8,
            query: { $0.staticTexts["ai-project-calculator-needs-mapping-empty"] }
        )
        XCTAssertTrue(
            mappingEmptyState.waitForExistence(timeout: 8),
            "Expected mapping the seeded receipt, work hour, and task to clear the live mapping queue."
        )

        let actualSummary = revealElement(identifier: "ai-project-calculator-summary-actual", in: app, maxSwipes: 8)
        XCTAssertTrue(
            waitForAccessibilityValue(on: actualSummary, notEquals: "$0.00", timeout: 5),
            "Expected mapping the seeded receipt and labor hour to move the Actual metric away from zero."
        )

        let committedSummary = revealElement(identifier: "ai-project-calculator-summary-committed", in: app, maxSwipes: 8)
        XCTAssertTrue(
            waitForAccessibilityValue(on: committedSummary, notEquals: "$0.00", timeout: 5),
            "Expected mapping the seeded task to move the Committed metric away from zero."
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

    private func makeApp(mode: UITestLaunchMode, preserveState: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment[UITestLaunchEnvironment.mode] = mode.rawValue
        app.launchEnvironment[UITestLaunchEnvironment.skipLaunchDelay] = "1"
        if preserveState {
            app.launchEnvironment[UITestLaunchEnvironment.preserveState] = "1"
        }
        return app
    }

    private func buildAndApproveEstimatorDraft(
        in app: XCUIApplication,
        disableAutoGenerateStarterTasks: Bool = false
    ) {
        if disableAutoGenerateStarterTasks {
            let autoGenerateToggle = revealElement(
                identifier: "ai-project-calculator-auto-generate-tasks",
                in: app,
                maxSwipes: 6,
                query: { $0.switches["ai-project-calculator-auto-generate-tasks"] }
            )
            XCTAssertTrue(
                autoGenerateToggle.exists,
                "Expected the estimator intake to expose the starter-task toggle."
            )
            if (autoGenerateToggle.value as? String) == "1" {
                autoGenerateToggle.tap()
            }
            XCTAssertTrue(
                waitForAccessibilityValue(on: autoGenerateToggle, equals: "0", timeout: 3),
                "Expected the starter-task toggle to turn off for deterministic mapping coverage."
            )
        }

        let zipField = app.textFields["ai-project-calculator-zip"]
        XCTAssertTrue(
            zipField.waitForExistence(timeout: 5),
            "Expected the AI Project Calculator intake to expose the ZIP field."
        )
        replaceText(in: zipField, with: "90210", app: app)

        let vendorsField = app.textFields["ai-project-calculator-vendors"]
        XCTAssertTrue(
            vendorsField.waitForExistence(timeout: 5),
            "Expected the AI Project Calculator intake to expose the preferred vendors field."
        )
        replaceText(in: vendorsField, with: "Home Depot", app: app)

        let promptField = app.textViews["ai-project-calculator-prompt"]
        XCTAssertTrue(
            promptField.waitForExistence(timeout: 5),
            "Expected the AI Project Calculator intake to expose the project prompt editor."
        )
        replaceText(
            in: promptField,
            with: "Remodel a dated kitchen with new cabinets, quartz counters, appliance swaps, lighting, flooring transitions, and finish carpentry with a contractor-grade scope.",
            app: app
        )
        dismissKeyboardIfPresent(in: app)

        let buildButton = revealButton(identifier: "ai-project-calculator-build", in: app, maxSwipes: 6)
        XCTAssertTrue(
            buildButton.exists,
            "Expected the estimator intake to expose the build-draft action after entering required context."
        )
        buildButton.tap()

        let draftReview = app.staticTexts["ai-project-calculator-draft-review"]
        XCTAssertTrue(
            draftReview.waitForExistence(timeout: 8),
            "Expected building the estimator draft to render the draft review section without clarifications."
        )

        let approveButton = revealButton(identifier: "ai-project-calculator-approve", in: app, maxSwipes: 8)
        XCTAssertTrue(
            approveButton.exists,
            "Expected the draft review surface to expose the approve-baseline action."
        )
        approveButton.tap()
    }

    private func mapEstimatorActual(identifier: String, in app: XCUIApplication) {
        let mappingButton = revealButton(identifier: identifier, in: app, maxSwipes: 8)
        XCTAssertTrue(
            mappingButton.exists,
            "Expected the live estimator mapping queue to expose \(identifier)."
        )
        mappingButton.tap()

        let mappingNavigationBar = app.navigationBars["Map Cost"]
        XCTAssertTrue(
            mappingNavigationBar.waitForExistence(timeout: 5),
            "Expected tapping \(identifier) to open the mapping sheet."
        )

        let saveButton = app.buttons["ai-project-calculator-mapping-save"]
        XCTAssertTrue(
            saveButton.waitForExistence(timeout: 5),
            "Expected the mapping sheet to expose the save action."
        )
        saveButton.tap()

        XCTAssertTrue(
            waitForNonExistence(of: mappingNavigationBar, timeout: 5),
            "Expected saving the mapping sheet to dismiss it cleanly."
        )
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

            let toggle = application.switches[identifier]
            if toggle.exists { return toggle }

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

    private func openReceiptActionsMenu(in app: XCUIApplication) {
        let identifiedMenu = app.buttons["receipt-detail-actions-menu"]
        let actionsMenu = identifiedMenu.exists ? identifiedMenu : app.buttons["Receipt Actions"]
        XCTAssertTrue(
            actionsMenu.waitForExistence(timeout: 5),
            "Expected the receipt detail screen to expose the top-right actions menu."
        )
        actionsMenu.tap()
    }

    private func receiptDetailMenuAction(
        identifier: String,
        fallbackTitle: String,
        in app: XCUIApplication
    ) -> XCUIElement {
        let identifiedAction = app.buttons[identifier]
        return identifiedAction.exists ? identifiedAction : app.buttons[fallbackTitle]
    }

    private func openAIProjectCalculator(in app: XCUIApplication) {
        app.tabBars.buttons["Projects"].tap()

        let projectCard = app.buttons[Self.selectedProjectCardIdentifier]
        XCTAssertTrue(
            projectCard.waitForExistence(timeout: 5),
            "Expected deterministic selected-project mode to expose the seeded Kitchen Remodel project card."
        )
        projectCard.tap()

        let estimatorTab = app.buttons["budget-tab-estimator"]
        XCTAssertTrue(
            estimatorTab.waitForExistence(timeout: 5),
            "Expected the budget breakdown surface to expose the Estimator tab."
        )
        estimatorTab.tap()

        XCTAssertTrue(
            waitForSelectedValue(on: estimatorTab, timeout: 5),
            "Expected tapping the Estimator tab to switch the budget surface into estimator mode."
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

    private func waitForAccessibilityValue(
        on element: XCUIElement,
        notEquals unexpectedValue: String,
        timeout: TimeInterval
    ) -> Bool {
        let predicate = NSPredicate(format: "value != %@", unexpectedValue)
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

    private func replaceText(in field: XCUIElement, with value: String) {
        field.tap()
        let currentValue = field.value as? String ?? ""
        if !currentValue.isEmpty {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: currentValue.count))
        }
        field.typeText(value)
    }

}
