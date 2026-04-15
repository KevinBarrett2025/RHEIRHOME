# RHEIR Ship Mode NX Board

## Active Lane
- `Phase 1 Foundation Hardening`

## Current Checkpoint
- Canonical tree cleanup completed in the working branch.
- Session flow consolidated around `AppSessionSupport.swift`.
- `ProjectStore`, `ProjectRepository`, `OrganizationProjectSyncStore`, `ReceiptProjectStore`, `ReceiptIntelligenceStore`, `LaborStore`, `CompanyStore`, and `TeamMemberStore` are active seams in compiled code.
- Active organization directory, vendor intelligence, and payment intelligence services now use structured logging.
- Active invite routing, organization setup/selection, and Sign in with Apple coordination now use structured logging.
- Active offline sync/storage, CloudKit project service, CloudKit zone management, and top-level CloudKit runtime coordination now use structured logging.
- Stable simulator evidence is green on the staged checkpoint:
  - Gate A `build_sim`: PASS (`mcp__xcodebuildmcp__build_sim` with `-derivedDataPath /tmp/rheir_gateA_phase1e_mcp_dd`)
  - Focused parity `test_sim -only-testing:RHEIRTests`: PASS (`mcp__xcodebuildmcp__test_sim` with `-derivedDataPath /tmp/rheir_parity_phase1e_mcp_dd`, `26/26`)

## Open Work
- Finish replacing raw `print(...)` tracing in the remaining active production paths outside the hardened project/receipt flow.
- Continue shrinking the remaining oversized active state owners.
- After the runtime sync logging checkpoint commit, take the next company/project coordination split on top of `OrganizationProjectSyncStore`.

## Blockers
- Device-targeted Gate A remains blocked by signing for `com.RheirHome.RHEIR`.
- Raw in-sandbox `xcodebuild` remains less reliable than the stable `xcodebuildmcp` simulator path in this environment.
