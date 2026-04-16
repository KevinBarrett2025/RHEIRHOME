# RHEIR Ship Readiness Checklist

## Current Status
- Branch: `gm/rheir-hardening-phase1`
- Status: in `Release Hardening`
- Release posture: not ship-ready yet

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
Exit criteria: main contractor workflows are predictable, test-covered, and role-correct.

- Add UI smoke coverage for:
  - sign in
  - choose organization
  - choose project
  - add receipt
  - log labor
  - company admin access
- Validate end-to-end workflows for:
  - admin onboarding
  - invite acceptance
  - project switching
  - receipt OCR and AI analysis
  - labor logging
  - vendor and payment method updates
- Validate role-based behavior for admin and non-admin users.
- Validate relaunch restore, cache fallback, and cross-organization isolation.
- Remove or isolate debug-only behavior from release flows.

## Phase 3: Promo Candidate
Exit criteria: the build is realistic QA and release-candidate material.

- Run clean simulator gate with no new active-target warnings.
- Run focused parity plus smoke suite.
- Run authenticated manual QA on core contractor flows.
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
  - CloudKit org/project flows
  - receipt capture
  - permissions
  - offline/online transitions
- Verify release configuration behavior.
- Verify App Store metadata, assets, and privacy answers.
- Freeze scope and submit.

## Immediate Next Steps
1. Re-run the previously failing device project update / scanned-receipt persistence flow now that serialized project payloads and startup legacy `UserDefaults` project blobs strip inline receipt image data.
2. Continue broader selected-project receipt runtime QA once the device rerun is clean.
3. Validate end-to-end contractor flows such as receipt OCR and AI analysis, labor logging, and vendor/payment-method updates.
4. Expand focused parity as simulator and device seams stabilize.
