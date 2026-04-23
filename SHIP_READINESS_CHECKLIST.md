# RHEIR Ship Readiness Checklist

## Current Status
- Branch: `gm/rheir-hardening-phase1`
- Status: in `Release Hardening`
- Release posture: narrowed to a fast-ship v1 single-user contractor release

## Phase 1: Foundation Completion
Exit criteria: architecture is stable, noisy legacy behavior is reduced, and warning debt is controlled.

- Finish remaining high-residue service cleanup:
  - `Shared/Services/ChatGPTService.swift`
  - `Shared/Services/TeamMemberService.swift`
  - `Shared/Services/Core/AuthenticationService.swift`
  - `Shared/Services/EnhancedReceiptService.swift`
- Reduce remaining raw `print(...)` usage in active production code.
- Clear known warning debt:
  - `Shared/Models/WorkHour.swift`
  - `Shared/Features/Receipts/ReceiptScannerView.swift`
  - `Shared/Features/Projects/NewProjectView.swift`
  - `Shared/Views/Settings/PersonalSettingsView.swift`
- Continue shrinking oversized active state owners.
- Keep simulator Gate A and focused parity green on every checkpoint.

## Phase 2: Release Hardening
Exit criteria: a single user can move through the core contractor workflows predictably, with the simplified v1 shell, stable persistence, and clean App Store posture.

- Add UI smoke coverage for:
  - sign in
  - simplified ready shell with no collaboration/admin detour
  - choose project
  - add receipt
  - log labor
  - task management
  - estimator draft/approve plus live actual-cost mapping
- Validate end-to-end workflows for:
  - project switching
  - receipt OCR and AI analysis
  - labor logging
  - task create/complete
  - estimator baseline review
  - relaunch restore and cache fallback
- Keep invite, org-selection, team/admin, company-management, proposal-service, live-price research, and legacy AI-key entry hidden behind the fast-ship release profile unless they are explicitly re-enabled post-launch.
- Validate same-user iCloud restore only as an optional launch enhancement; if it is not green by cutoff, ship with local-device persistence as the authoritative expectation.
- Remove or isolate debug-only behavior from release flows and user-facing copy.

## Phase 3: Promo Candidate
Exit criteria: the build is realistic QA and release-candidate material.

- Run clean simulator gate with no new active-target warnings.
- Run focused parity plus smoke suite.
- Run authenticated manual QA on the fast-ship contractor flows.
- Re-verify privacy and logging posture:
  - no token dumps
  - no raw OCR dumps
  - no raw user/org identifiers in production logs
- Confirm there are no dead active implementation paths left in the tree.
- Cut a `promo/*` candidate only after these are green.

## Phase 4: App Store Submission
Exit criteria: release candidate is validated on real hardware and ready for submission.

- Use the now-working physical-device path for real-hardware validation of the release candidate.
- Run device validation for:
  - Sign in with Apple
  - same-user project restore and persistence
  - receipt capture
  - permissions
  - offline/online transitions
- Verify release configuration behavior.
- Verify App Store metadata, assets, and privacy answers.
- Freeze scope and submit.

## Immediate Next Steps
1. Re-run the fast-ship real-device acceptance pack starting with the post-Sign in with Apple restored-session path, now that duplicate restored-organization activation has been deduped and session-store workspace resolution waits for org loading to finish.
2. Continue the selected-project flow on device through first scan, scanned-receipt return/reopen, and relaunch restore once the restored-session freeze no longer reproduces.
3. Validate same-user iCloud restore on real hardware; if it is not clean by release cutoff, keep the shell but de-scope cross-device expectations from launch.
4. Only after the device acceptance pack is green, decide whether any remaining shell polish is still launch-critical.
