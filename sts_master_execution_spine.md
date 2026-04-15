# RHEIR Execution Spine

## Mission
Ship an App Store-ready contractor operations app by hardening the existing codebase before adding new features.

## Current Phase
- Phase 1: repo cleanup, session-flow consolidation, state ownership split, and release gate restoration.

## Active Work Order
1. Preserve the cleaned canonical tree: `App/`, `Shared/`, `RHEIR.xcodeproj`, `RHEIRTests/`, `RHEIRUITests/`.
2. Route launch, auth, invite handling, organization selection, onboarding, and ready-state through one session layer.
3. Break oversized state owners into smaller stores and repository boundaries.
4. Require deterministic build and test evidence for every meaningful change.
5. Remove privacy-hostile logging and unsafe debug behavior from active production code.

## Scope Guardrails
- Prefer archaeology over reinvention.
- Patch the active compiled files first.
- Do not expand cleanup into cosmetic refactors.
- Keep each implementation slice small enough to verify with a focused build/test gate.
