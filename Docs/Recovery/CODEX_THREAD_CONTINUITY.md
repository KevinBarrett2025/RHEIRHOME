# CODEX Thread Continuity

## Repo Truth
- Repo Root: `/Users/kevinbarrett/Dev/RHEIR`
- Active Branch: `gm/rheir-hardening-phase1`
- HEAD SHA: `860cd9d6a0ef4f73897654e0e5f3faf4d9f3da5f`
- Last Commit: `860cd9d Phase 1: replace category receipts print tracing`

## Current Objective
- Preserve the repo-tracked ship-readiness checklist and checkpoint the `Shared/Features/Labor/LaborPaymentView.swift` payment-processing logging cleanup slice.
- Queue `Shared/Features/Progress/ProgressDetailView.swift` as the next highest-value remaining production seam after the `LaborPaymentView.swift` checkpoint lands.

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
- `Shared/Features/Progress/ProgressDetailView.swift` is now the active highest-value remaining production seam by fresh raw `print(...)` residue count.
- `Shared/Features/Labor/LaborPaymentView.swift` no longer contains the stale post-clear processed-count logging bug.
- Other non-hardened seams still contain raw `print(...)` tracing.
- Focused tests for invite parsing, cache migration, project-store persistence, receipt-intelligence retention, cache clearing, labor aggregation/validation, company-state bucketing, team-member store behavior, and receipt project-resolution behavior now live in `RHEIRTests/RHEIRTests.swift`.
- Focused tests for project access normalization and assignment filtering now live in `RHEIRTests/RHEIRTests.swift`.
- The current working slice has exact simulator evidence recorded:
  - Gate A `build_sim`: PASS (`mcp__xcodebuildmcp__build_sim` with `-derivedDataPath /tmp/rheir_gateA_phase1bs_mcp_dd`)
  - Focused parity `test_sim -only-testing:RHEIRTests`: PASS (`mcp__xcodebuildmcp__test_sim` with `-derivedDataPath /tmp/rheir_parity_phase1bs_mcp_dd`, `27/27`)
  - Direct `xcodebuild` CLI evidence remains less stable than the MCP simulator path in the current local CoreSimulator environment

## Known Constraints
- `Shared/Views/Auth/LoginView.swift` already contained user edits before this thread resumed.
- `rheir_knowledge_database.json` and `RHEIRmemories.csv` are user-owned artifacts and should not be modified unless explicitly requested.
- `RheirLogo 1024x1024.png` is an untracked local asset and should not be modified unless explicitly requested.
- This repo follows a repo-local STS equivalent defined in the root governance docs because the original STS spine docs were not present here.

## Next Required Action
1. Commit the `Shared/Features/Labor/LaborPaymentView.swift` payment-processing logging slice without staging `Shared/Views/Auth/LoginView.swift`, `rheir_knowledge_database.json`, `RHEIRmemories.csv`, or `RheirLogo 1024x1024.png`.
2. Preserve the repo-local STS docs and `SHIP_READINESS_CHECKLIST.md` as the current release-planning truth for this repository.
3. Continue with `Shared/Features/Progress/ProgressDetailView.swift` after the `LaborPaymentView.swift` checkpoint lands.
