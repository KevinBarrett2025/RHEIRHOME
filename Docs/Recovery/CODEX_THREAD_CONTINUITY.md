# CODEX Thread Continuity

## Repo Truth
- Repo Root: `/Users/kevinbarrett/Dev/RHEIR`
- Active Branch: `gm/rheir-hardening-phase1`
- HEAD SHA: `0978ecd30fde489fc36735330106cd695239f31c`
- Last Commit: `0978ecd Phase 1: replace org auth invite print tracing`

## Current Objective
- Stabilize the streamlined repo after the file-tree cleanup and sync-store extraction checkpoints.
- Continue phase 1 hardening by replacing the remaining raw `print(...)` tracing in `OrganizationZoneService.swift` and the other non-hardened seams.

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
- `OrganizationZoneService.swift`, `ScalableCloudKitArchitecture.swift`, and other non-hardened seams still contain raw `print(...)` tracing.
- Focused tests for invite parsing, cache migration, project-store persistence, receipt-intelligence retention, cache clearing, labor aggregation/validation, company-state bucketing, team-member store behavior, and receipt project-resolution behavior now live in `RHEIRTests/RHEIRTests.swift`.
- Focused tests for project access normalization and assignment filtering now live in `RHEIRTests/RHEIRTests.swift`.
- The current working slice has exact simulator evidence recorded:
  - Gate A `build_sim`: PASS (`mcp__xcodebuildmcp__build_sim` with `-derivedDataPath /tmp/rheir_gateA_phase1r_mcp_dd`)
  - Focused parity `test_sim -only-testing:RHEIRTests`: PASS (`mcp__xcodebuildmcp__test_sim` with `-derivedDataPath /tmp/rheir_parity_phase1r_mcp_dd`, `27/27`)
  - Direct `xcodebuild` CLI evidence remains less stable than the MCP simulator path in the current local CoreSimulator environment

## Known Constraints
- `Shared/Views/Auth/LoginView.swift` already contained user edits before this thread resumed.
- `rheir_knowledge_database.json` and `RHEIRmemories.csv` are user-owned artifacts and should not be modified unless explicitly requested.
- This repo follows a repo-local STS equivalent defined in the root governance docs because the original STS spine docs were not present here.

## Next Required Action
1. Replace the remaining raw `print(...)` tracing in `OrganizationZoneService.swift`.
2. Gate that narrowed zone-service slice with `build_sim` and focused `RHEIRTests` parity.
3. Commit the slice without staging `Shared/Views/Auth/LoginView.swift`, `rheir_knowledge_database.json`, or `RHEIRmemories.csv`.
4. Preserve the repo-local STS docs as the source of workflow truth until a canonical authority/promo structure exists for this repository.
