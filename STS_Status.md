# STS Status

## Repo
- Root: `/Users/kevinbarrett/Dev/RHEIR`
- Branch: `gm/rheir-hardening-phase1`
- HEAD: `2e8b62329642867f02d851c2b577e992ff6abec8`

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
- Added `TeamMemberStore` for team-member directory merges, organization verification, cache building, and logged-hour cleanup.
- Added `ReceiptProjectStore` for receipt target resolution, cross-list project resynchronization, and hardened project-scoped receipt updates.
- Added `LaborStore` for labor-hour aggregation, totals, and validation.
- Added `CompanyStore` for company team-member bucketing, project assignment categorization, and organization summary logic.
- Added `ReceiptIntelligenceStore` for typed receipt intelligence and organizational insight persistence.
- Removed direct `UserDefaults` access and manual `objectWillChange.send()` from the project persistence/selection path in `ProjectViewModel`.
- Removed inline team-member merge/update/remove logic from the active project/team-member path and routed it through `TeamMemberStore`.
- Removed inline labor recomputation logic and the forced `objectWillChange.send()` refresh from `recomputeLaborData()`.
- Removed inline company/team categorization logic from `MasterCompanySettingsView.swift`.
- Removed direct `UserDefaults` access and forced refresh hacks from the active receipt intelligence path.
- Routed AuthViewModel cache clearing through `LocalCacheStore` instead of raw session-key deletion.
- Replaced raw `print(...)` tracing in active auth/session flows with structured `Logger` usage and masked org/user identifiers where applicable.
- Replaced raw `print(...)` tracing in active labor/time-entry flows with `Logger.labor`.
- Replaced raw `print(...)` tracing in the active project lifecycle and landing-page refresh paths with `Logger.project`.
- Replaced raw `print(...)` tracing in the active receipt entry, receipt cache recompute, and receipt-intelligence paths with `Logger.receiptWorkflow` / `Logger.receiptIntelligence`.
- Replaced raw company-settings prints with structured `Logger.company` usage in the active organization settings flow.
- Replaced raw `print(...)` tracing in the active organization directory, vendor intelligence, and payment intelligence services with structured `Logger` usage.
- Replaced raw `print(...)` tracing in the active deep-link, organization-entry, and Sign in with Apple coordination flow with structured `Logger` usage.
- Added focused persistence/session tests in `RHEIRTests/RHEIRTests.swift` for invite parsing, legacy cache migration, project storage, receipt intelligence retention, cache clearing, labor aggregation/validation, company-state bucketing, team-member store behavior, and receipt project-resolution behavior.

## In Progress
- Replace remaining unsafe logging/state hacks in the rest of the active codebase.
- Continue shrinking the remaining oversized active state owners around the new sync store boundary.
- Expand deterministic parity beyond the focused `RHEIRTests` suite.

## Blockers
- Raw ad hoc `xcodebuild` commands are still less reliable than the `xcodebuildmcp` path in this environment.
- Device-targeted Gate A remains blocked by signing because automatic provisioning is disabled for `com.RheirHome.RHEIR`.

## Latest Evidence
- Gate A: `xcodebuild -project /Users/kevinbarrett/Dev/RHEIR/RHEIR.xcodeproj -scheme RHEIR -destination 'platform=iOS Simulator,id=DD0211FE-8732-4DA9-9E9E-78C61F0734DC' -derivedDataPath /tmp/rheir_gateA_phase1d_dd clean build` -> PASS (`/tmp/rheir_gateA_20260415_phase1d.log`)
- Focused parity: `xcodebuild -project /Users/kevinbarrett/Dev/RHEIR/RHEIR.xcodeproj -scheme RHEIR -destination 'platform=iOS Simulator,id=DD0211FE-8732-4DA9-9E9E-78C61F0734DC' -derivedDataPath /tmp/rheir_parity_phase1d_dd test -only-testing:RHEIRTests` -> PASS (`/tmp/rheir_parity_RHEIRTests_20260415_phase1d.log`, `26/26`)

## Next Milestone
- Checkpoint the auth/session-entry logging cleanup slice, then continue the remaining production logging cleanup and the next oversized-state split around company/project coordination.
