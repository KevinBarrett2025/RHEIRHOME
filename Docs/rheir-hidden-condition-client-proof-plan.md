# RHEIR Hidden Condition / Client Proof Plan

Date: 2026-05-24
Status: Future workflow planning, documentation only
Scope: Product and technical planning for a future hidden-condition and client-proof workflow

## Purpose

The Hidden Condition / Client Proof workflow should help builders document unexpected site conditions, protect margin, and communicate clearly with clients before field changes become disputes.

The workflow should fit the Modern Builder Ledger / Calm Jobsite Command Center direction: field-fast capture, calm review, clear client output, and durable proof underneath.

## Contractor Problem

Renovation work often exposes issues that were not visible during estimating:

- damaged framing
- concealed water damage
- electrical or plumbing surprises
- code corrections
- failed prep by prior trades
- missing client decisions
- materials that need replacement or return

Today, this evidence often lives across photos, texts, notes, receipts, and memory. RHEIR should give contractors one structured way to capture what happened, what it means, and what needs approval.

## Client Trust Goal

The client-facing goal is not to make the app sound automated or defensive. The goal is to make the builder's reasoning visible:

1. What was found.
2. Why it matters.
3. What proof exists.
4. What it may cost or delay.
5. What approval is needed before proceeding.

The builder should remain in control of anything sent to the client.

## Proposed User Flow

1. Document Hidden Condition
   - Start from Today, Tasks, Progress, Budget, or Receipts when a field issue is discovered.
   - Capture the project, location/context, status, and whether the condition blocks work.

2. Add Photos
   - Attach proof photos from camera or existing project media.
   - Keep photo captions editable.
   - Preserve original media references and timestamps where available.

3. Add Internal Note
   - Capture jobsite context, crew observations, trade notes, uncertainty, and next internal action.
   - Internal notes must not be client-facing by default.

4. Add Client-Facing Note
   - Draft a clear, neutral explanation suitable for a homeowner or client.
   - Keep the client note separate from the internal note.
   - Require explicit user review before it can be sent/exported.

5. Estimate Cost/Time Impact
   - Capture a rough cost range, time impact, or "unknown pending review."
   - Avoid implying precision when only an allowance or estimate exists.
   - Link later to change order, receipt, labor, or budget category work if approved.

6. Mark Approval Needed
   - Flag whether client approval is needed before work continues.
   - Track approval status separately from task completion.
   - Make pending approval visible in Today / Project Health surfaces.

7. Generate/Send Client Summary Later
   - Generate a client-ready summary only after the builder reviews proof, cost/time impact, and wording.
   - Support export/share later, but do not auto-send.

8. Preserve Audit Trail
   - Keep timestamps, author/source, edited versions, linked media, and approval state changes.
   - Make it easy to answer: "What did we know, when did we know it, and what was approved?"

## Suggested Future Components

- `HiddenConditionCard`
  - Compact status card for Today, Project Overview, or Budget context.
  - Shows condition title, status, approval need, linked photos, and cost/time impact.

- `ProofPhotoCard`
  - Reusable proof media tile with caption, timestamp, source, and review state.
  - Must not change task/photo persistence behavior without a separate storage design.

- `ClientApprovalCard`
  - Shows approval need, status, requested date, approved date, and next action.
  - Should make "approval needed" visible without requiring navigation into a deep detail screen.

- `ChangeNoteCard`
  - Separates internal note from client-facing note.
  - Should make privacy state obvious.

- `ClientSummaryCard`
  - Review surface for the generated/exportable client explanation.
  - Must support edit-before-send.

## Local-First / Privacy-First Requirements

- Default to local-first capture so proof can be recorded on site.
- Do not require network access to document a condition.
- Keep internal notes private by default.
- Do not expose proof photos, captions, or internal notes to client-facing output without explicit user action.
- If CloudKit sharing is later involved, treat it as a separate reviewed slice with explicit privacy rules.
- Do not write hidden-condition data into broad app storage without a migration and rollback plan.

## Audit Trail Requirements

The future implementation should preserve:

- created date and last edited date
- author/source where available
- linked project, task, receipt, labor entry, budget category, or progress log
- original photo timestamps and captions
- internal note history or last-reviewed state
- client note review state
- cost/time estimate history
- approval requested, approved, declined, or needs revision
- export/share history if client summaries are sent later

Audit data should be reviewable, not buried.

## Editable Before Client Output

Before anything becomes client-facing, the builder should be able to review and edit:

- title
- location/context
- proof photo selection
- photo captions
- internal note exclusion
- client-facing note
- cost estimate/range
- time impact
- approval request wording
- linked budget/category/change-order context

## What Not To Automate Without User Approval

RHEIR should not automatically:

- send messages to clients
- create or approve change orders
- alter budget numbers
- mark client approval as granted
- expose internal notes
- choose which photos are client-facing
- convert rough estimates into final pricing
- change task, receipt, labor, or project state

The app can suggest, draft, and organize, but the builder must approve outward-facing communication and money-impacting changes.

## App Store / Privacy Considerations If AI Is Added Later

If AI is later used to draft client-facing explanations:

- Make AI drafting opt-in and clearly labeled.
- Show the generated text for review before use.
- Do not send private project data to third-party services without explicit disclosure and policy review.
- Avoid using AI to infer facts not present in the record.
- Keep internal notes separate from AI client summaries unless the user explicitly includes them.
- Update privacy disclosures if project data, photos, notes, or client information are processed externally.
- Provide a non-AI manual path for all critical workflows.

## Risks And Open Questions

- How should hidden conditions relate to change orders without prematurely changing budget math?
- Should hidden conditions be first-class project records or derived from progress/task/change-order records?
- What photo storage rules apply if proof photos are shared with clients?
- How should approval state sync across CloudKit shared projects?
- What is the minimum audit trail needed for trust without making the UI feel legalistic?
- Should client summaries be export-only at first, before in-app sending?
- Which surfaces should show pending approval: Today, Project Health, Budget, Tasks, or all of them?

## Recommended Implementation Phases

1. Documentation and UX framing
   - Keep this as a planning artifact until the data boundary is approved.

2. Read-only proof surfacing
   - Reuse existing photos/tasks/progress records to show proof context without new storage.

3. Local model design
   - Design a minimal hidden-condition record with Codable compatibility, tests, and migration safety.

4. Mutation and persistence helpers
   - Add narrow local-first create/update/delete helpers with save/reload tests.

5. Capture UI
   - Add a focused "Document Hidden Condition" flow with internal/client note separation.

6. Client summary review
   - Add review-only summary generation/export, with no auto-send behavior.

7. Change order and budget linkage
   - Link approved conditions to change orders or budget categories only after math and audit rules are explicit.

8. CloudKit/share behavior
   - Add shared-project behavior only after local behavior is proven and privacy rules are documented.
