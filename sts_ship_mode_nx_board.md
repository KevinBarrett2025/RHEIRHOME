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
- Stable simulator evidence is green on the staged checkpoint:
  - Gate A `build_sim`: PASS (`mcp__xcodebuildmcp__build_sim` with `-derivedDataPath /tmp/rheir_gateA_phase1j_mcp_dd`)
  - Focused parity `test_sim -only-testing:RHEIRTests`: PASS (`mcp__xcodebuildmcp__test_sim` with `-derivedDataPath /tmp/rheir_parity_phase1j_mcp_dd`, `27/27`)

## Open Work
- Finish replacing raw `print(...)` tracing in legacy services, models, onboarding, and other non-hardened production seams.
- Continue shrinking the remaining oversized active state owners.
- After the hidden-debug logging checkpoint commit, continue the next company/project coordination cleanup or the legacy logging cleanup slice.

## Blockers
- Device-targeted Gate A remains blocked by signing for `com.RheirHome.RHEIR`.
- Raw in-sandbox `xcodebuild` remains less reliable than the stable `xcodebuildmcp` simulator path in this environment.
