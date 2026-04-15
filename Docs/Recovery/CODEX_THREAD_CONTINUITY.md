# CODEX Thread Continuity

## Repo Truth
- Repo Root: `/Users/kevinbarrett/Dev/RHEIR`
- Active Branch: `gm/rheir-hardening-phase1`
- HEAD SHA: `73acce26662e6bacdc55375009e14b867b1f4e36`
- Last Commit: `73acce2 Fucked and back to onboard Fails`

## Current Objective
- Stabilize the streamlined repo after the file-tree cleanup and first session-flow consolidation.
- Checkpoint the current phase 1 hardening slice with green simulator build/test evidence, then continue shrinking the remaining oversized state owners.

## Current Working Set
- Session flow now routes through `Shared/Views/Auth/AppSessionSupport.swift`.
- Active app entry points are under `App/` and `Shared/`.
- The repo cleanup removed duplicate source trees and backup directories from the active working tree.
- `ProjectViewModel` now contains the active `ProjectStore` and `ProjectRepository` seams so the target can compile without `project.pbxproj` edits.
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
- The current staged checkpoint has exact simulator evidence recorded:
  - Gate A `clean build`: PASS (`/tmp/rheir_gateA_20260415.log`)
  - Focused parity `test -only-testing:RHEIRTests`: PASS (`/tmp/rheir_parity_RHEIRTests_20260415.log`, `22/22`)

## Known Constraints
- `Shared/Views/Auth/LoginView.swift` already contained user edits before this thread resumed.
- `rheir_knowledge_database.json` and `RHEIRmemories.csv` are user-owned artifacts and should not be modified unless explicitly requested.
- This repo follows a repo-local STS equivalent defined in the root governance docs because the original STS spine docs were not present here.

## Next Required Action
1. Commit the current GM checkpoint without staging `Shared/Views/Auth/LoginView.swift`, `rheir_knowledge_database.json`, or `RHEIRmemories.csv`.
2. After the checkpoint, extract organization/project synchronization out of `ProjectViewModel`.
3. Continue the logging/privacy cleanup into the remaining active non-debug production files that still emit raw `print(...)` output.
4. Preserve the repo-local STS docs as the source of workflow truth until a canonical authority/promo structure exists for this repository.
