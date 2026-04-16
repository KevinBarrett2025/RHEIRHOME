# RHEIR Ship Mode NX Board

## Active Lane
- `Phase 1 Foundation Hardening`

## Current Checkpoint
- Canonical tree cleanup completed in the working branch.
- Session flow consolidated around `AppSessionSupport.swift`.
- `ProjectStore`, `ProjectRepository`, `OrganizationProjectSyncStore`, `ProjectAccessStore`, `ReceiptProjectStore`, `ReceiptIntelligenceStore`, `LaborStore`, `CompanyStore`, and `TeamMemberStore` are active seams in compiled code.
- Active organization directory, vendor intelligence, and payment intelligence services now use structured logging.
- Active invite routing, organization setup/selection, and Sign in with Apple coordination now use structured logging.
- Active offline sync/storage, CloudKit project service, CloudKit zone management, and top-level CloudKit runtime coordination now use structured logging.
- `CompanyStore` and its companion types no longer live inside `MasterCompanySettingsView.swift`.
- Active company/project UI assignment, team-member, organization-edit, payment-method, and team-management views now use structured logging instead of raw `print(...)` tracing.
- Debug/support settings views and data-management helpers now use structured `Logger.settingsSupport` logging instead of raw `print(...)` tracing.
- `HiddenDebugPanelView.swift` now uses structured `Logger.settingsSupport` logging instead of raw `print(...)` tracing.
- `OrganizationKnowledgeService.swift`, `Employee.swift`, and `AdminOnboardingView.swift` now use structured logging instead of raw `print(...)` tracing.
- `ProjectViewModel+BudgetIntegration.swift` and `ProjectViewModel+Import.swift` now use structured logging instead of raw `print(...)` tracing.
- `ProjectViewModel+Filters.swift` now uses structured `Logger.project` logging instead of raw `print(...)` tracing.
- `OrganizationDataMigrationService.swift` now uses structured `Logger.organizationMigration` logging instead of raw `print(...)` tracing.
- `CompleteDataResetService.swift` now uses structured `Logger.settingsSupport` logging instead of raw `print(...)` tracing.
- The organization create/fetch/delete and helper-query paths in `CloudKitAuthService+Organization.swift` now use structured `Logger.auth` logging instead of raw `print(...)` tracing.
- The lower invite/zone-management/join/assignment half of `CloudKitAuthService+Organization.swift` now uses structured `Logger.auth` logging instead of raw `print(...)` tracing.
- `CloudKitAuthService.swift` now uses structured `Logger.auth` logging instead of raw `print(...)` tracing.
- `OrganizationZoneService.swift` now uses structured `Logger.cloudKitZone` logging instead of raw `print(...)` tracing.
- `ScalableCloudKitArchitecture.swift` now uses structured `Logger.scalableCloudKit` logging instead of raw `print(...)` tracing.
- `Shared/Services/Organization/CloudKitVendorService.swift` now uses structured `Logger.cloudKitVendor` logging instead of raw `print(...)` tracing.
- `CloudKitOrganizationSharingService.swift` now uses structured `Logger.organizationSharing` logging instead of raw `print(...)` tracing.
- `CloudKitOrganizationDebugService.swift` now uses structured `Logger.organizationDebug` logging instead of raw `print(...)` tracing.
- `AppleIDAuthService.swift` now uses structured `Logger.auth` logging instead of raw `print(...)` tracing.
- `SimpleCloudKitSharingService.swift` now uses structured `Logger.organizationSharing` logging instead of raw `print(...)` tracing.
- `ProjectDataMigrationService.swift` now uses structured `Logger.organizationMigration` logging instead of raw `print(...)` tracing.
- `Organization/CloudKitPaymentMethodService.swift` now uses structured `Logger.cloudKitPaymentMethod` logging instead of raw `print(...)` tracing.
- `DataMigrationService.swift` now uses structured `Logger.organizationMigration` logging instead of raw `print(...)` tracing.
- `Core/JWTService.swift` now uses structured `Logger.auth` logging instead of raw `print(...)` tracing.
- `PaymentMethodManagementService.swift` now uses structured `Logger.company` logging instead of raw `print(...)` tracing.
- `ReceiptOCRService.swift` now uses structured `Logger.receiptOCR` logging instead of raw `print(...)` tracing.
- `Core/UserService.swift` now uses structured `Logger.auth` logging instead of raw `print(...)` tracing.
- `Core/CloudKitService.swift` now uses structured `Logger.auth` logging instead of raw `print(...)` tracing.
- `CloudKitSharingService.swift` now uses structured `Logger.organizationSharing` logging instead of raw `print(...)` tracing.
- `TeamMemberService.swift` now uses structured `Logger.teamMember` logging instead of raw `print(...)` tracing.
- `Core/AuthenticationService.swift` now uses structured `Logger.auth` logging instead of raw `print(...)` tracing.
- `EnhancedReceiptService.swift` now uses structured `Logger.receiptOCR` logging instead of raw `print(...)` tracing.
- `VendorManagementService.swift` now uses structured `Logger.company` logging instead of raw `print(...)` tracing.
- `OrganizationService.swift` now uses structured `Logger.organizationService` logging instead of raw `print(...)` tracing.
- `CloudKitPhotoService.swift` now uses structured `Logger.cloudKitPhoto` logging instead of raw `print(...)` tracing.
- `ProductionChatGPTService.swift` now uses structured `Logger.productionChatGPT` logging instead of raw `print(...)` tracing.
- `CloudKitAuthService+User.swift` now uses structured `Logger.auth` logging instead of raw `print(...)` tracing.
- `EnhancedOrganizationService.swift` now uses structured `Logger.organizationService` logging instead of raw `print(...)` tracing.
- `GlobalChatGPTService.swift` now uses structured `Logger.globalChatGPT` logging instead of raw `print(...)` tracing.
- `ContextAwareReceiptService.swift` now uses structured `Logger.receiptWorkflow` logging instead of raw `print(...)` tracing.
- `ReceiptScannerView.swift` now uses structured `Logger.receiptWorkflow` / `Logger.receiptOCR` logging instead of raw `print(...)` tracing.
- `EditProjectView.swift` now uses structured `Logger.project` logging instead of raw `print(...)` tracing.
- `ReceiptScannerView.swift` no longer depends on the unavailable `Logger.receiptOCR` category inside the compiled view target.
- `LogHoursView.swift` now uses structured `Logger.labor` / `Logger.teamMember` logging instead of raw `print(...)` tracing.
- `NewProjectView.swift` now uses structured `Logger.project` logging instead of raw `print(...)` tracing and no longer carries the unused `intelligenceData` warning.
- `ProjectDetailview.swift` now uses structured `Logger.project` logging instead of raw `print(...)` tracing.
- `AddTeamMemberView.swift` now uses structured `Logger.teamMember` logging instead of raw `print(...)` tracing.
- `ScannedReceiptEntryView.swift` now uses structured `Logger.receiptWorkflow` logging instead of raw `print(...)` tracing.
- `ReceiptsView.swift` now uses structured `Logger.receiptWorkflow` logging instead of raw `print(...)` tracing.
- `UniversalHeaderView.swift` now uses structured `Logger.settingsSupport` / `Logger.company` logging instead of raw `print(...)` tracing.
- `TaskDetailViewWrapper.swift` now uses structured `Logger.cloudKitPhoto` logging instead of raw `print(...)` tracing.
- `DailyProgressComponents.swift` now uses structured `Logger.cloudKitPhoto` logging instead of raw `print(...)` tracing.
- `DirectoryEmployeeRowView.swift` now uses structured `Logger.teamMember` logging instead of raw `print(...)` tracing.
- `SubscriptionBadgeView.swift` no longer emits preview-only raw `print(...)` tracing.
- `FAB.swift` no longer emits preview-only raw `print(...)` tracing.
- `EnhancedTeamMemberDetailView.swift` now uses structured `Logger.teamMember` logging instead of raw `print(...)` tracing.
- `TaskCreateEditView.swift` now uses structured `Logger.project` logging instead of raw `print(...)` tracing.
- `ReceiptScannerCoordinator.swift` now uses structured `Logger.receiptWorkflow` logging instead of raw `print(...)` tracing.
- `ReceiptEditView.swift` now uses structured `Logger.receiptWorkflow` logging instead of raw `print(...)` tracing.
- `ReceiptDetailView.swift` now uses structured `Logger.receiptWorkflow` logging instead of raw `print(...)` tracing.
- `QuickVendorCreateView.swift` no longer emits preview-only raw `print(...)` tracing.
- `QuickPaymentMethodCreateView.swift` no longer emits preview-only raw `print(...)` tracing.
- `ManualReceiptEntryView.swift` now uses structured `Logger.receiptWorkflow` logging instead of raw `print(...)` tracing.
- `CommunicationLogsView.swift` no longer emits preview-only raw `print(...)` tracing.
- `CategoryReceiptsView.swift` now uses structured `Logger.receiptWorkflow` logging instead of raw `print(...)` tracing.
- `LaborPaymentView.swift` now uses structured `Logger.labor` logging instead of raw `print(...)` tracing, and its logged payment batch count now reflects the pre-clear selection size.
- Stable simulator evidence is green on the staged checkpoint:
  - Gate A `build_sim`: PASS (`mcp__xcodebuildmcp__build_sim` with `-derivedDataPath /tmp/rheir_gateA_phase1bs_mcp_dd`)
  - Focused parity `test_sim -only-testing:RHEIRTests`: PASS (`mcp__xcodebuildmcp__test_sim` with `-derivedDataPath /tmp/rheir_parity_phase1bs_mcp_dd`, `27/27`)

## Open Work
- Finish replacing raw `print(...)` tracing in the other non-hardened production seams, starting with `Shared/Features/Progress/ProgressDetailView.swift`.
- Continue shrinking the remaining oversized active state owners.
- After the `Shared/Features/Progress/ProgressDetailView.swift` checkpoint, continue with the next highest-value non-hardened production seam.
- Use `SHIP_READINESS_CHECKLIST.md` as the current release-progress reference alongside the STS docs.

## Blockers
- Device-targeted Gate A remains blocked by signing for `com.RheirHome.RHEIR`.
- Raw in-sandbox `xcodebuild` remains less reliable than the stable `xcodebuildmcp` simulator path in this environment.
