# RHEIR Repo Workflow Read First

This repository uses a repo-local equivalent of the STS enterprise workflow.

## Scope
- This repo is currently operating as a `gm/*` sandbox branch environment.
- Work must stay on GM branches until a later promotion path is explicitly established.
- There is no repo-local `promo/*` or `authority/main` run active in this thread.

## Hard Rules
- Do not skip build/test gates.
- Do not commit or promote on failing or missing evidence.
- Do not remove user-owned files or revert unrelated edits.
- Use the repo-local continuity anchor at `Docs/Recovery/CODEX_THREAD_CONTINUITY.md`.
- Keep the active production tree limited to `App/`, `Shared/`, `RHEIR.xcodeproj`, `RHEIRTests/`, and `RHEIRUITests/`.

## Required Companion Docs
- `sts_master_execution_spine.md`
- `10_GM_TESTING_GROUNDS_RUNBOOK.md`
- `20_GM_TO_MAIN_PROMOTION_RUNBOOK.md`
- `STS_Rule_of_Law.md`
- `STS_Status.md`

If these docs conflict, follow `STS_Rule_of_Law.md` first, then the runbooks, then the execution spine.
