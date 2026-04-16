# CODEX Thread Continuity

## Repo Truth
- Repo Root: `/Users/kevinbarrett/Dev/RHEIR`
- Active Branch: `gm/rheir-hardening-phase1`
- HEAD SHA: `d7f289ff9417e91549196ada7aa6aa7a5b93f24d`
- Last Commit: `d7f289f Phase 1: add organization selection UI smoke coverage`

## Current Objective
- Extend the deterministic `RHEIRUITests` harness with a seeded project-selection route.
- Prove the app’s project-required gating by covering the no-selection warning, gated receipts state, and post-selection receipts content without touching live CloudKit state.

## Current Working Set
- Session flow now routes through `Shared/Views/Auth/AppSessionSupport.swift`.
- Active app entry points are under `App/` and `Shared/`.
- The repo cleanup removed duplicate source trees and backup directories from the active working tree.
- `ProjectViewModel` now contains the active `ProjectStore` and `ProjectRepository` seams so the target can compile without `project.pbxproj` edits.
- `OrganizationProjectSyncStore` now owns organization-scoped project filtering, snapshot persistence, CloudKit merge/fetch/save helpers, zone setup, and assignment gating previously embedded in `ProjectViewModel`.
- `ProjectAccessStore` now owns accessible-project normalization, assignment filtering, duplicate suppression, and selected-project reconciliation previously embedded in `ProjectViewModel`.
- Active organization directory, vendor intelligence, and payment intelligence services now use structured `Logger` calls instead of raw `print(...)` tracing.
- Active invite routing, organization creation, organization selection, and Sign in with Apple coordination now use structured `Logger` calls instead of raw `print(...)` tracing.
- Active offline sync/storage, CloudKit project service, CloudKit zone management, and top-level CloudKit runtime coordination now use structured `Logger` calls instead of raw `print(...)` tracing.
- Project persistence, organization snapshots, and project assignment caching are now organization-scoped through `ProjectStore`.
- Team-member directory mutations, organization verification, cache building, and logged-hour cleanup now route through `TeamMemberStore`.
- Receipt-to-project resolution and project-list resynchronization now route through `ReceiptProjectStore`.
- Labor aggregation and validation now route through `LaborStore` instead of living inline inside `recomputeLaborData()`.
- Company team-member bucketing and organization summary logic now route through `CompanyStore` in the compiled state layer instead of staying embedded in `MasterCompanySettingsView.swift`.
- `CompanyStore`, `CompanyTeamBuckets`, and `CompanySummary` now live in the compiled state layer instead of `MasterCompanySettingsView.swift`.
- Receipt intelligence persistence now routes through `ReceiptIntelligenceStore` instead of raw `UserDefaults` dictionaries.
- Auth cache clearing now routes through `LocalCacheStore.clearAllKnownSessionKeys()` instead of ad hoc `UserDefaults` removals.
- Active auth/session logging now uses structured `Logger` calls instead of raw `print(...)` tracing in `AuthViewModel.swift`.
- Active labor/time-entry logging now uses `Logger.labor` instead of raw `print(...)` calls in `ProjectViewModel+TimeEntry.swift` and `LaborModuleView.swift`.
- Active project-lifecycle and landing-page refresh logs now use structured `Logger.project` in the main organization/project flow.
- Active receipt entry, cache recomputation, and receipt-intelligence flows now use structured `Logger.receiptWorkflow` / `Logger.receiptIntelligence` instead of raw `print(...)` tracing in the compiled receipt paths.
- Active company/project UI assignment, team-member, organization-edit, payment-method, and team-management views now use structured `Logger` calls instead of raw `print(...)` tracing.
- Debug/support settings views and data-management helpers now use structured `Logger.settingsSupport` calls instead of raw `print(...)` tracing.
- `HiddenDebugPanelView.swift` now uses structured `Logger.settingsSupport` calls instead of raw `print(...)` tracing.
- `OrganizationKnowledgeService.swift`, `Employee.swift`, and `AdminOnboardingView.swift` now use structured `Logger` calls instead of raw `print(...)` tracing.
- `ProjectViewModel+BudgetIntegration.swift` and `ProjectViewModel+Import.swift` now use structured `Logger` calls instead of raw `print(...)` tracing.
- `ProjectViewModel+Filters.swift` now uses structured `Logger.project` calls instead of raw `print(...)` tracing.
- `OrganizationDataMigrationService.swift` now uses structured `Logger.organizationMigration` calls instead of raw `print(...)` tracing.
- `CompleteDataResetService.swift` now uses structured `Logger.settingsSupport` calls instead of raw `print(...)` tracing.
- The organization create/fetch/delete and helper-query paths in `CloudKitAuthService+Organization.swift` now use structured `Logger.auth` calls instead of raw `print(...)` tracing.
- The invite, zone-management, join, and assignment paths in `CloudKitAuthService+Organization.swift` now use structured `Logger.auth` calls instead of raw `print(...)` tracing.
- `CloudKitAuthService.swift` now uses structured `Logger.auth` calls instead of raw `print(...)` tracing.
- `OrganizationZoneService.swift` now uses structured `Logger.cloudKitZone` calls instead of raw `print(...)` tracing.
- `ScalableCloudKitArchitecture.swift` now uses structured `Logger.scalableCloudKit` calls instead of raw `print(...)` tracing.
- `Shared/Services/Organization/CloudKitVendorService.swift` now uses structured `Logger.cloudKitVendor` calls instead of raw `print(...)` tracing.
- `CloudKitOrganizationSharingService.swift` now uses structured `Logger.organizationSharing` calls instead of raw `print(...)` tracing.
- `CloudKitOrganizationDebugService.swift` now uses structured `Logger.organizationDebug` calls instead of raw `print(...)` tracing.
- `AppleIDAuthService.swift` now uses structured `Logger.auth` calls instead of raw `print(...)` tracing.
- `SimpleCloudKitSharingService.swift` now uses structured `Logger.organizationSharing` calls instead of raw `print(...)` tracing.
- `ProjectDataMigrationService.swift` now uses structured `Logger.organizationMigration` calls instead of raw `print(...)` tracing.
- `Organization/CloudKitPaymentMethodService.swift` now uses structured `Logger.cloudKitPaymentMethod` calls instead of raw `print(...)` tracing.
- `DataMigrationService.swift` now uses structured `Logger.organizationMigration` calls instead of raw `print(...)` tracing.
- `Core/JWTService.swift` now uses structured `Logger.auth` calls instead of raw `print(...)` tracing.
- `PaymentMethodManagementService.swift` now uses structured `Logger.company` calls instead of raw `print(...)` tracing.
- `ReceiptOCRService.swift` now uses structured `Logger.receiptOCR` calls instead of raw `print(...)` tracing.
- `Core/UserService.swift` now uses structured `Logger.auth` calls instead of raw `print(...)` tracing.
- `Core/CloudKitService.swift` now uses structured `Logger.auth` calls instead of raw `print(...)` tracing.
- `CloudKitSharingService.swift` now uses structured `Logger.organizationSharing` calls instead of raw `print(...)` tracing.
- `SHIP_READINESS_CHECKLIST.md` is the repo-tracked release plan for foundation completion, release hardening, promo candidacy, and App Store submission.
- `Shared/Services/ChatGPTService.swift` now uses structured `Logger.organizationService` calls instead of raw `print(...)` tracing, even though the file currently houses `OrganizationService`.
- `Shared/Services/TeamMemberService.swift` now uses structured `Logger.teamMember` calls instead of raw `print(...)` tracing.
- `Shared/Services/Core/AuthenticationService.swift` now uses structured `Logger.auth` calls instead of raw `print(...)` tracing.
- `Shared/Services/EnhancedReceiptService.swift` now uses structured `Logger.receiptOCR` calls instead of raw `print(...)` tracing.
- `Shared/Services/VendorManagementService.swift` now uses structured `Logger.company` calls instead of raw `print(...)` tracing.
- `Shared/Services/Organization/OrganizationService.swift` now uses structured `Logger.organizationService` calls instead of raw `print(...)` tracing.
- `Shared/Services/CloudKitPhotoService.swift` now uses structured `Logger.cloudKitPhoto` calls instead of raw `print(...)` tracing.
- `Shared/Services/ProductionChatGPTService.swift` now uses structured `Logger.productionChatGPT` calls instead of raw `print(...)` tracing.
- `Shared/Services/CloudKitAuthService+User.swift` now uses structured `Logger.auth` calls instead of raw `print(...)` tracing.
- `Shared/Services/Organization/EnhancedOrganizationService.swift` now uses structured `Logger.organizationService` calls instead of raw `print(...)` tracing.
- `Shared/Services/GlobalChatGPTService.swift` now uses structured `Logger.globalChatGPT` calls instead of raw `print(...)` tracing.
- `Shared/Services/Core/ContextAwareReceiptService.swift` now uses structured `Logger.receiptWorkflow` calls instead of raw `print(...)` tracing.
- The active production service layer is now down to non-production residue in `StubServices.swift`, `DevelopmentDataManager.swift`, and `PreviewAuthService.swift`.
- `Shared/Features/Receipts/ReceiptScannerView.swift` now uses structured `Logger.receiptWorkflow` / `Logger.receiptOCR` calls instead of raw `print(...)` tracing.
- `Shared/Features/Receipts/ReceiptScannerView.swift` now routes view-side OCR logging through `Logger.receiptWorkflow`, restoring logger compatibility in the compiled target.
- `Shared/Features/Projects/EditProjectView.swift` now uses structured `Logger.project` calls instead of raw `print(...)` tracing in the save path.
- `Shared/Features/TimeEntry/LogHoursView.swift` now uses structured `Logger.labor` / `Logger.teamMember` calls instead of raw `print(...)` tracing for fallback member discovery, rate autofill, appearance diagnostics, and save events.
- `Shared/Features/Projects/NewProjectView.swift` now uses structured `Logger.project` calls instead of raw `print(...)` tracing for invalid-budget validation, intelligence-loading status, and AI suggestion application.
- `Shared/Features/Projects/NewProjectView.swift` no longer carries the unused `intelligenceData` binding warning.
- `Shared/Features/Projects/ProjectDetailview.swift` now uses structured `Logger.project` calls instead of raw `print(...)` tracing for organization validation and share-flow placeholder events.
- `Shared/Features/TimeEntry/AddTeamMemberView.swift` now uses structured `Logger.teamMember` calls instead of raw `print(...)` tracing for default-rate changes and team-member create/update save events.
- `Shared/Features/Receipts/ScannedReceiptEntryView.swift` now uses structured `Logger.receiptWorkflow` calls instead of raw `print(...)` tracing for AI-enhanced vendor/payment sync completion and company-settings sync completion.
- `Shared/Features/Receipts/ReceiptsView.swift` now uses structured `Logger.receiptWorkflow` calls instead of raw `print(...)` tracing for receipt deletion start/completion events.
- `Shared/Views/Components/UniversalHeaderView.swift` now uses structured `Logger.settingsSupport` / `Logger.company` calls instead of raw `print(...)` tracing for hidden debug panel access and subscription-tier switching.
- `Shared/Features/Progress/TaskDetailViewWrapper.swift` now uses structured `Logger.cloudKitPhoto` calls instead of raw `print(...)` tracing for task-photo load failures in both grid and full-screen detail paths.
- `Shared/Features/Progress/DailyProgressComponents.swift` now uses structured `Logger.cloudKitPhoto` calls instead of raw `print(...)` tracing for progress-photo load failures in both card and full-screen detail paths.
- `Shared/Features/Directory/DirectoryEmployeeRowView.swift` now uses structured `Logger.teamMember` calls instead of raw `print(...)` tracing for team-member invitation success/failure results.
- `Shared/Views/Components/SubscriptionBadgeView.swift` no longer emits preview-only console tracing in the tier-selection card preview.
- `Shared/Utilities/Shared/FAB.swift` no longer emits preview-only console tracing in its preview action closure.
- `Shared/Features/TeamMembers/EnhancedTeamMemberDetailView.swift` now uses structured `Logger.teamMember` calls instead of raw `print(...)` tracing for team-member detail save events.
- `Shared/Features/Tasks/TaskCreateEditView.swift` now uses structured `Logger.project` calls instead of raw `print(...)` tracing for task-save events.
- `Shared/Features/Receipts/ReceiptScannerCoordinator.swift` now uses structured `Logger.receiptWorkflow` calls instead of raw `print(...)` tracing for legacy document-camera failure events.
- `Shared/Features/Receipts/ReceiptEditView.swift` now uses structured `Logger.receiptWorkflow` calls instead of raw `print(...)` tracing for receipt-update save events.
- `Shared/Features/Receipts/ReceiptDetailView.swift` now uses structured `Logger.receiptWorkflow` calls instead of raw `print(...)` tracing for receipt-delete completion events.
- `Shared/Features/Receipts/QuickVendorCreateView.swift` no longer emits preview-only console tracing in its preview closure.
- `Shared/Features/Receipts/QuickPaymentMethodCreateView.swift` no longer emits preview-only console tracing in its preview closure.
- `Shared/Features/Receipts/ManualReceiptEntryView.swift` now uses structured `Logger.receiptWorkflow` calls instead of raw `print(...)` tracing for manual receipt company-settings sync completion events.
- `Shared/Features/Projects/CommunicationLogsView.swift` no longer emits preview-only console tracing in its preview closure.
- `Shared/Features/Budget/CategoryReceiptsView.swift` now uses structured `Logger.receiptWorkflow` calls instead of raw `print(...)` tracing for category receipt deletion completion events.
- `Shared/Features/Labor/LaborPaymentView.swift` now uses structured `Logger.labor` calls instead of raw `print(...)` tracing for payment-batch completion events, and the logged batch count now reflects the pre-clear selection size.
- `Shared/Features/Progress/ProgressDetailView.swift` now uses structured `Logger.project` calls instead of raw `print(...)` tracing for progress-photo placeholder tap events.
- `Shared/Features/Receipts/ReceiptScannerView.swift` no longer carries the unused `lowercaseText` warning in `extractPaymentMethodDetails(_:)`.
- `Shared/Features/Labor/LaborPaymentView.swift` no longer contains the stale post-clear processed-count logging bug.
- Production raw `print(...)` cleanup is effectively complete; remaining raw `print(...)` residue is limited to development-only seams such as `Shared/Services/Development/DevelopmentDataManager.swift`, `Shared/Services/StubServices.swift`, and `Shared/Services/PreviewAuthService.swift`.
- `Shared/Views/Settings/PersonalSettingsView.swift` no longer carries the unreachable `catch` warning in its CloudKit status helper.
- `Shared/Models/WorkHour.swift` no longer carries the redundant local `CLLocation: @unchecked Sendable` conformance.
- The stable `xcodebuildmcp` simulator path is now warning-clean for the active target.
- `RheirApp.swift` now supports deterministic signed-out UI test launch mode without touching live CloudKit auth state.
- `RheirApp.swift` now also supports deterministic ready-state UI test launch mode with a seeded local user and organization, again without touching live CloudKit auth state.
- `SessionStore` now supports configurable launch delay so UI tests can bypass the splash wait without affecting normal app launches.
- `SessionStore` now supports optional project/auth bridge suppression for UI test launch modes so seeded states do not wake live CloudKit sync work.
- `RHEIRUITests.swift` now contains a deterministic signed-out smoke test that asserts the Apple Sign-In control renders.
- `RHEIRUITests.swift` now also contains a deterministic ready-state smoke test that asserts the main tab shell renders with the five core tabs.
- `RHEIRUITests.swift` now also contains a deterministic organization-selection smoke test that asserts the org picker and seeded organizations render.
- Deterministic project-selection smoke coverage is the active release-hardening seam now that the signed-out, ready-state, and organization-selection launch routes are stable.
- `RHEIRUITestsLaunchTests.swift` now launches in deterministic signed-out mode before capturing launch evidence.
- Deterministic organization/project workflow coverage is now the next highest-value release-hardening seam in the active tree.
- Focused tests for invite parsing, cache migration, project-store persistence, receipt-intelligence retention, cache clearing, labor aggregation/validation, company-state bucketing, team-member store behavior, and receipt project-resolution behavior now live in `RHEIRTests/RHEIRTests.swift`.
- Focused tests for project access normalization and assignment filtering now live in `RHEIRTests/RHEIRTests.swift`.
- The current working slice has exact simulator evidence recorded:
  - Gate A `build_sim`: PASS (`mcp__xcodebuildmcp__build_sim` with `-derivedDataPath /tmp/rheir_gateA_phase1by_mcp_dd`)
  - Focused parity `test_sim -only-testing:RHEIRTests -only-testing:RHEIRUITests/RHEIRUITests/testSignedOutModeShowsAppleSignIn -only-testing:RHEIRUITests/RHEIRUITestsLaunchTests/testLaunch`: PASS (`mcp__xcodebuildmcp__test_sim` with `-derivedDataPath /tmp/rheir_parity_phase1by_mcp_dd`, `29/29`)
  - Gate A `build_sim` for the ready-state slice: PASS (`mcp__xcodebuildmcp__build_sim` with `-derivedDataPath /tmp/rheir_gateA_phase1bz_mcp_dd`)
  - Expanded UI parity `test_sim -only-testing:RHEIRTests -only-testing:RHEIRUITests/RHEIRUITests/testSignedOutModeShowsAppleSignIn -only-testing:RHEIRUITests/RHEIRUITests/testReadyModeShowsMainTabShell -only-testing:RHEIRUITests/RHEIRUITestsLaunchTests/testLaunch`: PASS (`mcp__xcodebuildmcp__test_sim` with `-derivedDataPath /tmp/rheir_parity_phase1bz_mcp_dd`, `30/30`)
  - Direct `xcodebuild` CLI evidence remains less stable than the MCP simulator path in the current local CoreSimulator environment

## Known Constraints
- `Shared/Views/Auth/LoginView.swift` already contained user edits before this thread resumed.
- `rheir_knowledge_database.json` and `RHEIRmemories.csv` are user-owned artifacts and should not be modified unless explicitly requested.
- `RheirLogo 1024x1024.png` is an untracked local asset and should not be modified unless explicitly requested.
- This repo follows a repo-local STS equivalent defined in the root governance docs because the original STS spine docs were not present here.

## Next Required Action
1. Checkpoint the deterministic project-selection `RHEIRUITests` smoke coverage slice without staging `Shared/Views/Auth/LoginView.swift`, `rheir_knowledge_database.json`, `RHEIRmemories.csv`, or `RheirLogo 1024x1024.png`.
2. Preserve the repo-local STS docs and `SHIP_READINESS_CHECKLIST.md` as the current release-planning truth for this repository.
3. Continue with deterministic project-context workflow coverage after the project-selection UI checkpoint lands.
