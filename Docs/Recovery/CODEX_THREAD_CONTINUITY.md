# CODEX Thread Continuity

## Repo Truth
- Repo Root: `/Users/kevinbarrett/Dev/RHEIR`
- Active Branch: `gm/rheir-hardening-phase1`
- HEAD SHA: `12c38c0cf2ec69a6ddef025a03585f1da1a03bcb`
- Last Commit: `12c38c0 Phase 1: replace auth session entry print tracing`

## Current Objective
- Stabilize the streamlined repo after the file-tree cleanup and sync-store extraction checkpoints.
- Continue phase 1 hardening by reducing the remaining oversized active state owners and checkpoint the runtime sync logging cleanup slice.

## Current Working Set
- Session flow now routes through `Shared/Views/Auth/AppSessionSupport.swift`.
- Active app entry points are under `App/` and `Shared/`.
- The repo cleanup removed duplicate source trees and backup directories from the active working tree.
- `ProjectViewModel` now contains the active `ProjectStore` and `ProjectRepository` seams so the target can compile without `project.pbxproj` edits.
- `OrganizationProjectSyncStore` now owns organization-scoped project filtering, snapshot persistence, CloudKit merge/fetch/save helpers, zone setup, and assignment gating previously embedded in `ProjectViewModel`.
- Active organization directory, vendor intelligence, and payment intelligence services now use structured `Logger` calls instead of raw `print(...)` tracing.
- Active invite routing, organization creation, organization selection, and Sign in with Apple coordination now use structured `Logger` calls instead of raw `print(...)` tracing.
- Active offline sync/storage, CloudKit project service, CloudKit zone management, and top-level CloudKit runtime coordination now use structured `Logger` calls instead of raw `print(...)` tracing.
- Project persistence, organization snapshots, and project assignment caching are now organization-scoped through `ProjectStore`.
- Team-member directory mutations, organization verification, cache building, and logged-hour cleanup now route through `TeamMemberStore`.
- Receipt-to-project resolution and project-list resynchronization now route through `ReceiptProjectStore`.
- Labor aggregation and validation now route through `LaborStore` instead of living inline inside `recomputeLaborData()`.
- Company team-member bucketing and organization summary logic now route through `CompanyStore` instead of staying embedded in `MasterCompanySettingsView.swift`.
- Receipt intelligence persistence now routes through `ReceiptIntelligenceStore` instead of raw `UserDefaults` dictionaries.
- Auth cache clearing now routes through `LocalCacheStore.clearAllKnownSessionKeys()` instead of ad hoc `UserDefaults` removals.
- Active auth/session logging now uses structured `Logger` calls instead of raw `print(...)` tracing in `AuthViewModel.swift`.
- Active labor/time-entry logging now uses `Logger.labor` instead of raw `print(...)` calls in `ProjectViewModel+TimeEntry.swift` and `LaborModuleView.swift`.
- Active project-lifecycle and landing-page refresh logs now use structured `Logger.project` in the main organization/project flow.
- Active receipt entry, cache recomputation, and receipt-intelligence flows now use structured `Logger.receiptWorkflow` / `Logger.receiptIntelligence` instead of raw `print(...)` tracing in the compiled receipt paths.
- Focused tests for invite parsing, cache migration, project-store persistence, receipt-intelligence retention, cache clearing, labor aggregation/validation, company-state bucketing, team-member store behavior, and receipt project-resolution behavior now live in `RHEIRTests/RHEIRTests.swift`.
- The current working slice has exact simulator evidence recorded:
  - Gate A `build_sim`: PASS (`mcp__xcodebuildmcp__build_sim` with `-derivedDataPath /tmp/rheir_gateA_phase1e_mcp_dd`)
  - Focused parity `test_sim -only-testing:RHEIRTests`: PASS (`mcp__xcodebuildmcp__test_sim` with `-derivedDataPath /tmp/rheir_parity_phase1e_mcp_dd`, `26/26`)
  - Direct `xcodebuild` CLI evidence for this slice is still unstable in the current local CoreSimulator environment (`/tmp/rheir_gateA_20260415_phase1e.log`)

## Known Constraints
- `Shared/Views/Auth/LoginView.swift` already contained user edits before this thread resumed.
- `rheir_knowledge_database.json` and `RHEIRmemories.csv` are user-owned artifacts and should not be modified unless explicitly requested.
- This repo follows a repo-local STS equivalent defined in the root governance docs because the original STS spine docs were not present here.

## Next Required Action
1. Commit the runtime sync logging cleanup slice without staging `Shared/Views/Auth/LoginView.swift`, `rheir_knowledge_database.json`, or `RHEIRmemories.csv`.
2. Continue the next oversized-state split on top of `OrganizationProjectSyncStore`, likely around company/project coordination.
3. Replace the remaining raw `print(...)` tracing in the active production files outside the hardened sync/runtime slice.
4. Preserve the repo-local STS docs as the source of workflow truth until a canonical authority/promo structure exists for this repository.
