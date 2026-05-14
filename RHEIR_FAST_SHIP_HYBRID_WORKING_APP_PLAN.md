# RHEIR Fast-Ship Hybrid Working-App Plan

## Summary
- Keep the current Fast-Ship Hybrid direction: visible single-user contractor app, Apple sign-in, CloudKit/personal workspace internals retained, no visible org/admin/team onboarding.
- The release bar is not just hiding collaboration; v1 must make Projects, Receipts, Labor, Tasks, Budget, Resources, and Reports work coherently with immediate refresh and Apple-grade UI.
- Prioritize correctness before expansion: fix broken refresh, restore missing core workflows, remove placeholders/redundancy, and only ship surfaces that are actually wired.
- Think like a contractor: the app must answer "what did I spend, who worked, what is unpaid, what is late, am I profitable, and what can I hand my accountant?"

## Key Decisions
- Project selection remains the app entry gate: no Receipts/Labor/Tasks tab bar until a project is selected.
- Organizations stay as hidden infrastructure only. User-facing copy uses Personal Workspace only where unavoidable, otherwise plain contractor/project language.
- Completed projects return as a first-class project state. Projects gets Active and Completed views so closed jobs are never lost.
- Shared business setup moves back into v1 as Business Resources, not Company or Organization.
- Active project detail uses Breakdown, Resources, and Reports as primary project-management areas. Estimator becomes a secondary action for setup/revisions, not a dominant active-project tab.
- Receipts remain the strongest current module, but receipt itemization must continue to drive category totals, budget actuals, reports, and filtered summaries.

## Implementation Plan
- Add a tracked release hardening checklist that covers global refresh, completed projects, business resources, labor, tasks, reports, UI cleanup, and device acceptance.
- Create one project mutation path so create/update/delete actions update selected project, project lists, budget analytics, receipt filters, labor totals, task counts, reports, local storage, and CloudKit sync from the same source of truth.
- Restore completed/past projects by preserving completed projects in storage and showing them in a clear Projects segmented control or archive section.
- Reintroduce Business Resources under Projects/settings and project detail Resources: workers/team members, job titles, labor rates, vendors, and payment methods/cards.
- Rework Labor into a shippable flow: top-aligned UI, add/edit workers, rates/titles, log hours, assign work, mark paid, partial/split payments, check/reference details, edit payment, and unpay/reissue.
- Rework Tasks into a shippable flow: add multiple tasks, edit/delete, assign owner, due dates, status, completion timestamp, completion photo, overdue state, and in-app badge/alert behavior.
- Finish Reports as practical contractor outputs: project summary, category spend, vendor spend, payment method spend, labor payroll, profit/loss, and completed-project closeout/export.
- Remove or wire all placeholder actions, including "coming soon" sheets, dead links, duplicate edit/delete controls, redundant choose/change controls, and extra navigation affordances.
- Standardize UI across all core screens: one header style, one empty-state style, one primary CTA rule, consistent safe areas, consistent sheet/full-screen patterns, and immediate visual refresh after mutations.

## Contractor Validation Track
- Validate every core workflow against real contractor job-costing needs: materials, labor, subcontractors/vendors, payment method, task progress, and project profitability.
- Keep field capture simple: scan receipt, log labor, update task, mark paid, see totals immediately.
- Make itemized receipts authoritative for cost-code/category spend, because mixed Home Depot receipts cannot be counted as one grand-total category.
- Make labor useful for payroll and job costing, not just hours: rate, title, paid/unpaid state, payment split, check/reference, and reversal.
- Make tasks useful for field control: assignment, due/overdue state, completion proof, and downstream project impact visibility.
- Make reports accountant/owner friendly: payroll summary, vendor spend, category/cost-code spend, payment-method spend, project profit/loss, completed-job closeout, and tax-year summaries.

## Data Contracts
- Project status supports active and completed, with completed projects persisted and recoverable in the UI.
- Business resources are available without exposing org/admin UI: workers, vendors, and payment methods remain reusable across projects.
- Labor payments support multiple payment entries per labor item, including amount, method, optional reference/check number, date, paid/unpaid status, and edit/reversal.
- Tasks support assignment, due/overdue state, completion metadata, and optional completion photos.
- Receipt itemized categories remain authoritative for category-filter totals and budget actuals. A mixed-category receipt must never count the full receipt total toward one selected item category.

## Test Plan
- Add unit tests for project mutation propagation, completed project visibility, receipt itemized category totals, labor payment splits/reversals, task overdue state, and report totals.
- Add deterministic UI smoke tests for no org onboarding, project selection gate, active/completed project switching, Business Resources entry, labor worker/payment flows, task CRUD, and report access.
- Device acceptance must cover Apple sign-in, project select/relaunch restore, receipt scan/relaunch restore, itemized category totals, labor log/payment edit/unpay, task edit/complete/photo, completed project archive, and reports.
- Every implementation slice still needs Gate A build, focused parity tests for the touched module, pbxproj drift check, and continuity doc update before commit.

## Assumptions
- v1 remains single-user visible, with hidden CloudKit/personal workspace internals retained for stability.
- Collaboration, invites, org admin, managed estimator backend, live price research, and client-side OpenAI key setup remain hidden for launch.
- Labor and Tasks are release blockers, not post-launch polish.
- Reports can start with in-app summaries and local exports; advanced year-over-year analytics can follow after the core reports are accurate.
