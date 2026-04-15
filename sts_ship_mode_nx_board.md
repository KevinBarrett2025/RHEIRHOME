# RHEIR Ship Mode NX Board

## Active Lane
- `Phase 1 Foundation Hardening`

## Current Checkpoint
- Canonical tree cleanup completed in the working branch.
- Session flow consolidated around `AppSessionSupport.swift`.
- `ProjectStore`, `ProjectRepository`, `ReceiptProjectStore`, `ReceiptIntelligenceStore`, `LaborStore`, `CompanyStore`, and `TeamMemberStore` are active seams in compiled code.
- Stable simulator evidence is green on the staged checkpoint:
  - Gate A `clean build`: PASS (`/tmp/rheir_gateA_20260415.log`)
  - Focused parity `test -only-testing:RHEIRTests`: PASS (`/tmp/rheir_parity_RHEIRTests_20260415.log`, `22/22`)

## Open Work
- Finish replacing raw `print(...)` tracing in the remaining active production paths outside the hardened project/receipt flow.
- Continue shrinking the remaining oversized active state owners.
- After the checkpoint commit, extract organization/project synchronization out of `ProjectViewModel`.

## Blockers
- Device-targeted Gate A remains blocked by signing for `com.RheirHome.RHEIR`.
- Raw in-sandbox `xcodebuild` remains less reliable than the escalated simulator path in this environment.
