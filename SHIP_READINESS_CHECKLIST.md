# RHEIR Ship Readiness Checklist

## Current Status
- Branch: `gm/rheir-hardening-phase1`
- Status: in `Release Hardening`
- Release posture: Fast-Ship Hybrid single-user contractor release with hidden CloudKit/personal-workspace infrastructure
- Governing plan: `RHEIR_FAST_SHIP_HYBRID_WORKING_APP_PLAN.md`

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

- Preserve the Fast-Ship Hybrid shell:
  - no visible organization setup/admin/team onboarding
  - no Receipts/Labor/Tasks tabs until a project is selected
  - completed projects remain visible through an Active/Completed project view
- Restore Business Resources without exposing Company/Organization:
  - workers/team members
  - job titles and labor rates
  - vendors
  - payment methods/cards
- Make contractor job-costing accurate:
  - itemized receipt categories drive category totals and budget actuals
  - labor logs drive project cost and payroll summaries
  - tasks drive progress, overdue state, and completion proof
  - project reports show profitability, vendor spend, payment-method spend, and closeout summaries
- Fix global refresh as a release blocker:
  - mutations update selected project, project lists, budget analytics, receipt filters, labor totals, task counts, reports, local storage, and CloudKit sync from one source of truth
  - no stale UI that only refreshes after a scan/add/manual mutation
- Remove dead or redundant UI:
  - no placeholder sheets
  - no duplicate action buttons when a menu owns the action
  - no redundant choose/change project controls
  - no broken links or unimplemented "coming soon" actions in v1
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
1. Preserve the Fast-Ship Hybrid Working-App Plan in repo docs and commit it as a docs-only checkpoint with Gate A plus focused documentation/parity evidence.
2. Start the implementation sequence with the global project mutation/refresh contract so later Projects, Receipts, Labor, Tasks, Budget, Resources, and Reports work from one source of truth.
3. Restore completed-project visibility and Business Resources before expanding Labor and Tasks, because those flows depend on reusable workers, rates, vendors, and payment methods.
4. Rework Labor and Tasks to shippable contractor workflows with focused unit/UI parity for each slice.
5. Finish Reports and device acceptance after the underlying data flows refresh immediately and persist across relaunch.
