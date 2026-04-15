# GM Testing Grounds Runbook

## Purpose
Define the local gate requirements for work performed on `gm/*` branches in this repo.

## Required Pre-Commit Evidence
- Gate A build must pass.
- The smallest deterministic parity scope related to the change must pass.
- `RHEIR.xcodeproj/project.pbxproj` drift must be reported as `NONE`, `INTENTIONAL`, or `UNINTENTIONAL`.
- If runtime tests are blocked by a known infrastructure issue, record the exact failure mode and fall back to the narrowest successful compile/build-for-testing evidence available.

## Default Gate A
```bash
xcodebuild -project /Users/kevinbarrett/Dev/RHEIR/RHEIR.xcodeproj \
  -scheme RHEIR \
  -destination 'generic/platform=iOS Simulator' \
  clean build
```

## Default Parity Guidance
- Session/routing changes: run `build-for-testing` and targeted test bundles where possible.
- Store/repository changes: run the smallest unit-test scope that covers the new boundary.
- UI-only changes: at minimum, pass Gate A and capture the relevant simulator/runtime note if a screenshot is not practical.

## Stop Conditions
- Missing Gate A evidence.
- Missing parity evidence without a documented runtime blocker.
- Unintentional `project.pbxproj` drift.
