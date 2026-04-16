# STS Status

## Repo
- Root: `/Users/kevinbarrett/Dev/RHEIR`
- Branch: `gm/rheir-hardening-phase1`
- HEAD: `14756e16a7dd1a980c4ddd8b2313bf6100a6b244`

## Active Initiative
- RHEIR hardening and streamlining, phase 1 foundation pass.

## Completed
- Recovery tag created before cleanup.
- Remote `origin` configured for `git@github.com:KevinBarrett2025/RHEIRHOME.git`.
- Dead duplicate source trees and backup directories removed from the active working tree.
- Session flow consolidated around `AppSessionSupport.swift`.
- Project-scoped tabs now require explicit project selection.
- Shared scheme/runtime path is healthy enough for `xcodebuildmcp` simulator build + focused parity.
- Repo-local STS governance docs created for this repo.
- Added `ProjectStore` for organization-scoped local project/team-member/assignment persistence.
- Added `ProjectRepository` for CloudKit project fetch/save and project assignment persistence.
- Added `OrganizationProjectSyncStore` for organization-scoped project filtering, snapshot persistence, CloudKit merge/fetch/save helpers, zone setup, and assignment gating.
- Added `ProjectAccessStore` for accessible-project normalization, assignment filtering, duplicate suppression, and selected-project reconciliation.
- Added `TeamMemberStore` for team-member directory merges, organization verification, cache building, and logged-hour cleanup.
- Added `ReceiptProjectStore` for receipt target resolution, cross-list project resynchronization, and hardened project-scoped receipt updates.
- Added `LaborStore` for labor-hour aggregation, totals, and validation.
- Added `CompanyStore` for company team-member bucketing, project assignment categorization, and organization summary logic.
- Added `ReceiptIntelligenceStore` for typed receipt intelligence and organizational insight persistence.
- Removed direct `UserDefaults` access and manual `objectWillChange.send()` from the project persistence/selection path in `ProjectViewModel`.
- Removed inline team-member merge/update/remove logic from the active project/team-member path and routed it through `TeamMemberStore`.
- Removed inline labor recomputation logic and the forced `objectWillChange.send()` refresh from `recomputeLaborData()`.
- Removed inline company/team categorization logic from `MasterCompanySettingsView.swift`.
- Relocated `CompanyStore`, `CompanyTeamBuckets`, and `CompanySummary` out of `MasterCompanySettingsView.swift` into the compiled state layer so the settings view no longer owns store definitions.
- Removed direct `UserDefaults` access and forced refresh hacks from the active receipt intelligence path.
- Routed AuthViewModel cache clearing through `LocalCacheStore` instead of raw session-key deletion.
- Replaced raw `print(...)` tracing in active auth/session flows with structured `Logger` usage and masked org/user identifiers where applicable.
- Replaced raw `print(...)` tracing in active labor/time-entry flows with `Logger.labor`.
- Replaced raw `print(...)` tracing in the active project lifecycle and landing-page refresh paths with `Logger.project`.
- Replaced raw `print(...)` tracing in the active receipt entry, receipt cache recompute, and receipt-intelligence paths with `Logger.receiptWorkflow` / `Logger.receiptIntelligence`.
- Replaced raw company-settings prints with structured `Logger.company` usage in the active organization settings flow.
- Replaced raw `print(...)` tracing in the active organization directory, vendor intelligence, and payment intelligence services with structured `Logger` usage.
- Replaced raw `print(...)` tracing in the active deep-link, organization-entry, and Sign in with Apple coordination flow with structured `Logger` usage.
- Replaced raw `print(...)` tracing in `OfflineDataManager`, `CloudKitProjectService`, `CloudKitZoneManager`, and `RHEIRCloudKitManager` with structured `Logger` usage and lower-noise runtime sync logging.
- Replaced raw `print(...)` tracing in the active company/project UI assignment, team-member, organization-edit, payment-method, and team-management views with structured `Logger` usage.
- Replaced raw `print(...)` tracing in the debug/support settings views and data-management helpers with structured `Logger.settingsSupport` usage.
- Replaced raw `print(...)` tracing in `HiddenDebugPanelView.swift` with structured `Logger.settingsSupport` usage.
- Replaced raw `print(...)` tracing in `OrganizationKnowledgeService.swift`, `Employee.swift`, and `AdminOnboardingView.swift` with structured `Logger` usage.
- Replaced raw `print(...)` tracing in `ProjectViewModel+BudgetIntegration.swift` and `ProjectViewModel+Import.swift` with structured `Logger` usage.
- Replaced raw `print(...)` tracing in `ProjectViewModel+Filters.swift` with structured `Logger.project` usage for invalid-value warnings, enhanced-versus-legacy comparison logs, and legacy fallback notices.
- Replaced raw `print(...)` tracing in `OrganizationDataMigrationService.swift` with structured `Logger.organizationMigration` usage for local-backup, migration, and backup-listing events.
- Replaced raw `print(...)` tracing in `CompleteDataResetService.swift` with structured `Logger.settingsSupport` usage for reset completion, local clearing, zone deletion, record deletion, and query fallback notices.
- Replaced raw `print(...)` tracing in the organization create/fetch/delete and helper-query paths of `CloudKitAuthService+Organization.swift` with structured `Logger.auth` usage and masked org/user identifiers.
- Replaced raw `print(...)` tracing in the lower invite/zone-management/join/assignment half of `CloudKitAuthService+Organization.swift` with structured `Logger.auth` usage and masked org/user identifiers.
- Replaced raw `print(...)` tracing in `CloudKitAuthService.swift` with structured `Logger.auth` usage for sign-out, invite saving, account status checks, Apple Sign-In, user restoration, and local email persistence events.
- Replaced raw `print(...)` tracing in `OrganizationZoneService.swift` with structured `Logger.cloudKitZone` usage for zone setup, collaboration sharing, invitation acceptance, project persistence, and team-member sync events.
- Replaced raw `print(...)` tracing in `ScalableCloudKitArchitecture.swift` with structured `Logger.scalableCloudKit` usage for organization creation, zone setup, record persistence, sharing, invitation acceptance, and metrics events.
- Replaced raw `print(...)` tracing in `Shared/Services/Organization/CloudKitVendorService.swift` with structured `Logger.cloudKitVendor` usage for CloudKit vendor CRUD, migration, offline queue sync, merge resolution, and local-storage events.
- Replaced raw `print(...)` tracing in `CloudKitOrganizationSharingService.swift` with structured `Logger.organizationSharing` usage for zone creation, organization record/share creation, participant invites, project saves, share URLs, and share acceptance.
- Replaced raw `print(...)` tracing in `CloudKitOrganizationDebugService.swift` with structured `Logger.organizationDebug` usage for analysis runs, discrepancy repair, team-member reconciliation, project-persistence fixes, and emergency recovery.
- Replaced raw `print(...)` tracing in `AppleIDAuthService.swift` with structured `Logger.auth` usage for restore, Apple sign-in start, request configuration, email persistence, sign-out, and authorization callback events.
- Replaced raw `print(...)` tracing in `SimpleCloudKitSharingService.swift` with structured `Logger.organizationSharing` usage for shared-database enablement checks, project CRUD, and team-member CRUD events.
- Replaced raw `print(...)` tracing in `ProjectDataMigrationService.swift` with structured `Logger.organizationMigration` usage for project migration start/completion, organization cleanup, organization query filtering, and delete operations.
- Replaced raw `print(...)` tracing in `Organization/CloudKitPaymentMethodService.swift` with structured `Logger.cloudKitPaymentMethod` usage for load/save/delete flows, find-or-create behavior, spending updates, record validation, and local migration events.
- Replaced raw `print(...)` tracing in `DataMigrationService.swift` with structured `Logger.organizationMigration` usage for legacy migration start/completion, legacy cleanup queries, organization keep/delete decisions, and delete operations.
- Replaced raw `print(...)` tracing in `Core/JWTService.swift` with structured `Logger.auth` usage for JWT exchange, app-specific JWT creation, Lambda fallback, request/response metadata, token cache lifecycle, and local JWT fallback creation.
- Replaced raw `print(...)` tracing in `PaymentMethodManagementService.swift` with structured `Logger.company` usage for find-or-create resolution, spending updates, duplicate cleanup, persistence, and default-seed events.
- Replaced raw `print(...)` tracing in `ReceiptOCRService.swift` with structured `Logger.receiptOCR` usage for OCR extraction and receipt-analysis completion events.
- Replaced raw `print(...)` tracing in `Core/UserService.swift` with structured `Logger.auth` usage for CloudKit user upsert/fetch/update/delete lifecycle and fallback events.
- Replaced raw `print(...)` tracing in `Core/CloudKitService.swift` with structured `Logger.auth` usage for account-status checks and user-record ID fetch events.
- Replaced raw `print(...)` tracing in `CloudKitSharingService.swift` with structured `Logger.organizationSharing` usage for organization share creation, acceptance, and share-controller lifecycle events.
- Replaced raw `print(...)` tracing in `Shared/Services/ChatGPTService.swift` with structured `Logger.organizationService` usage for organization directory and project-tracking events in the current file contents.
- Replaced raw `print(...)` tracing in `Shared/Services/TeamMemberService.swift` with structured `Logger.teamMember` usage for team-member CRUD, photo metadata, status refresh, and organization persistence events.
- Replaced raw `print(...)` tracing in `Shared/Services/Core/AuthenticationService.swift` with structured `Logger.auth` usage for Apple Sign-In, silent sign-in, JWT refresh/reuse, persisted-user restore, and local Apple ID persistence events.
- Replaced raw `print(...)` tracing in `Shared/Services/EnhancedReceiptService.swift` with structured `Logger.receiptOCR` usage for enhanced receipt OCR, AI-analysis orchestration, and fallback-path events.
- Replaced raw `print(...)` tracing in `Shared/Services/VendorManagementService.swift` with structured `Logger.company` usage for vendor lookup, creation, spending updates, local persistence, and default-directory seeding events.
- Replaced raw `print(...)` tracing in `Shared/Services/Organization/OrganizationService.swift` with structured `Logger.organizationService` usage for initialization, organization creation/fetch, and CloudKit team-member/project sync events.
- Replaced raw `print(...)` tracing in `Shared/Services/CloudKitPhotoService.swift` with structured `Logger.cloudKitPhoto` usage for CloudKit photo fetch, upload, identifier lookup, and delete events.
- Replaced raw `print(...)` tracing in `Shared/Services/ProductionChatGPTService.swift` with structured `Logger.productionChatGPT` usage for receipt AI usage, JSON-parse failures, and receipt-date parsing warnings.
- Replaced raw `print(...)` tracing in `Shared/Services/CloudKitAuthService+User.swift` with structured `Logger.auth` usage for private user-record save/fetch failures and permission-fallback events.
- Replaced raw `print(...)` tracing in `Shared/Services/Organization/EnhancedOrganizationService.swift` with structured `Logger.organizationService` usage for service initialization, organization creation success, and organization-fetch failures.
- Replaced raw `print(...)` tracing in `Shared/Services/GlobalChatGPTService.swift` with structured `Logger.globalChatGPT` usage for global receipt-analysis JSON-parse failures without echoing raw content.
- Replaced raw `print(...)` tracing in `Shared/Services/Core/ContextAwareReceiptService.swift` with structured `Logger.receiptWorkflow` usage for active project-context updates and receipt-processing start events.
- Replaced raw `print(...)` tracing in `Shared/Features/Receipts/ReceiptScannerView.swift` with structured `Logger.receiptWorkflow` / `Logger.receiptOCR` usage for scanner upgrade prompts, OCR extraction, AI fallback, completion summaries, and parse failures.
- Restored `Shared/Features/Receipts/ReceiptScannerView.swift` logger compatibility by routing view-side OCR logs through `Logger.receiptWorkflow` in the compiled target.
- Replaced raw `print(...)` tracing in `Shared/Features/Projects/EditProjectView.swift` with structured `Logger.project` usage for edit-project save start, validation failures, prepared-save summaries, async update start, and completion events.
- Replaced raw `print(...)` tracing in `Shared/Features/TimeEntry/LogHoursView.swift` with structured `Logger.labor` / `Logger.teamMember` usage for fallback team-member discovery, rate autofill, appearance diagnostics, validation failures, save start, and completion events.
- Replaced raw `print(...)` tracing in `Shared/Features/Projects/NewProjectView.swift` with structured `Logger.project` usage for invalid-budget validation, intelligence-loading status, intelligence-load completion, and AI suggestion application.
- Removed the unused `intelligenceData` binding warning from `Shared/Features/Projects/NewProjectView.swift`.
- Replaced raw `print(...)` tracing in `Shared/Features/Projects/ProjectDetailview.swift` with structured `Logger.project` usage for missing-organization validation and project-sharing placeholder events.
- Replaced raw `print(...)` tracing in `Shared/Features/TimeEntry/AddTeamMemberView.swift` with structured `Logger.teamMember` usage for default-rate changes and team-member create/update save events.
- Replaced raw `print(...)` tracing in `Shared/Features/Receipts/ScannedReceiptEntryView.swift` with structured `Logger.receiptWorkflow` usage for AI-enhanced vendor sync, AI-enhanced payment-method sync, and company-settings sync completion events.
- Replaced raw `print(...)` tracing in `Shared/Features/Receipts/ReceiptsView.swift` with structured `Logger.receiptWorkflow` usage for receipt deletion start/completion events.
- Replaced raw `print(...)` tracing in `Shared/Views/Components/UniversalHeaderView.swift` with structured `Logger.settingsSupport` / `Logger.company` usage for hidden debug-panel access and header subscription-tier changes.
- Replaced raw `print(...)` tracing in `Shared/Features/Progress/TaskDetailViewWrapper.swift` with structured `Logger.cloudKitPhoto` usage for task-photo load failures in grid and full-screen detail views.
- Replaced raw `print(...)` tracing in `Shared/Features/Progress/DailyProgressComponents.swift` with structured `Logger.cloudKitPhoto` usage for progress-photo load failures in card and full-screen detail views.
- Replaced raw `print(...)` tracing in `Shared/Features/Directory/DirectoryEmployeeRowView.swift` with structured `Logger.teamMember` usage for invitation success/failure events.
- Removed the preview-only `print(...)` tracing from `Shared/Views/Components/SubscriptionBadgeView.swift`.
- Removed the preview-only `print(...)` tracing from `Shared/Utilities/Shared/FAB.swift`.
- Replaced raw `print(...)` tracing in `Shared/Features/TeamMembers/EnhancedTeamMemberDetailView.swift` with structured `Logger.teamMember` usage for team-member detail save events.
- Replaced raw `print(...)` tracing in `Shared/Features/Tasks/TaskCreateEditView.swift` with structured `Logger.project` usage for task-save events.
- Replaced raw `print(...)` tracing in `Shared/Features/Receipts/ReceiptScannerCoordinator.swift` with structured `Logger.receiptWorkflow` usage for legacy document-camera failure events.
- Replaced raw `print(...)` tracing in `Shared/Features/Receipts/ReceiptEditView.swift` with structured `Logger.receiptWorkflow` usage for receipt-update save events.
- Replaced raw `print(...)` tracing in `Shared/Features/Receipts/ReceiptDetailView.swift` with structured `Logger.receiptWorkflow` usage for receipt-delete completion events.
- Removed the preview-only `print(...)` tracing from `Shared/Features/Receipts/QuickVendorCreateView.swift`.
- Removed the preview-only `print(...)` tracing from `Shared/Features/Receipts/QuickPaymentMethodCreateView.swift`.
- Replaced raw `print(...)` tracing in `Shared/Features/Receipts/ManualReceiptEntryView.swift` with structured `Logger.receiptWorkflow` usage for manual receipt company-settings sync completion events.
- Removed the preview-only `print(...)` tracing from `Shared/Features/Projects/CommunicationLogsView.swift`.
- Added `SHIP_READINESS_CHECKLIST.md` as the repo-tracked release plan for the remaining foundation, hardening, promo, and submission work.
- Added focused persistence/session tests in `RHEIRTests/RHEIRTests.swift` for invite parsing, legacy cache migration, project storage, receipt intelligence retention, cache clearing, labor aggregation/validation, company-state bucketing, team-member store behavior, and receipt project-resolution behavior.
- Added focused parity for project access normalization and assignment filtering in `RHEIRTests/RHEIRTests.swift`.

## In Progress
- Keep phase-1 hardening moving with `Shared/Features/Budget/CategoryReceiptsView.swift` as the next code slice after the current checkpoint.
- Continue shrinking the remaining oversized active state owners around the new sync and access store boundaries.
- Expand deterministic parity beyond the focused `RHEIRTests` suite.

## Blockers
- Raw ad hoc `xcodebuild` commands are still less reliable than the `xcodebuildmcp` path in this environment; the phase-1e direct CLI gate still faults against CoreSimulator even when the MCP build/test path passes.
- Device-targeted Gate A remains blocked by signing because automatic provisioning is disabled for `com.RheirHome.RHEIR`.

## Latest Evidence
- Gate A: `mcp__xcodebuildmcp__build_sim` with `extraArgs=["-derivedDataPath","/tmp/rheir_gateA_phase1bq_mcp_dd"]` -> PASS
- Focused parity: `mcp__xcodebuildmcp__test_sim` with `extraArgs=["-derivedDataPath","/tmp/rheir_parity_phase1bq_mcp_dd","-only-testing:RHEIRTests"]` -> PASS (`27/27`)
- Direct CLI gate path remains less stable than the MCP simulator path in the local simulator environment

## Next Milestone
- Checkpoint the `CommunicationLogsView.swift` preview-tracing cleanup slice, then continue with `Shared/Features/Budget/CategoryReceiptsView.swift`, the next highest-value remaining production seam in the active tree.
