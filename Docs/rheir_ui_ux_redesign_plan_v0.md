# RHEIR UI/UX Redesign Plan v0

Date: 2026-05-23
Status: Durable product direction, documentation only
Scope: UI/UX redesign planning and handoff memory

## Executive Summary

RHEIR has the right feature set for a small construction and renovation project assistant, but the current user experience still feels too much like a database or admin console. The product direction is to make RHEIR feel like a jobsite command center:

> Open app -> see today's job status -> know the next action -> record proof/money/labor fast.

The app should prioritize what a contractor needs while standing in the field: what is due, what is late, what needs proof, what money or labor changed, and what must be handled next. The goal is not visual polish by itself. The deeper goal is to simplify the mental model so the app answers the user's daily operating question first:

> What do I need to deal with today?

Future implementation should move carefully because RHEIR has high persistence and data-loss risk. The redesign should begin with documentation and display-only adapters before any storage, CloudKit, or model migration work.

## Current UX Diagnosis

1. The app has strong pieces, but the hierarchy is confusing.
2. Tasks, Timeline, and Project Brief currently compete with each other.
3. A contractor should not need to think: "Is this a task, timeline event, checklist, brief item, shopping item, or labor item?"
4. The app should answer one simple question first: "What do I need to deal with today?"
5. High-frequency field actions should be obvious and one tap away.
6. Low-frequency and admin features should still exist, but should not dominate the daily field workflow.
7. Visual polish alone is not enough. Navigation and mental model simplification must come first.
8. Counts and metadata without navigation create distrust because users cannot verify what the app is counting.
9. The app already has useful contractor tools, but many are surfaced as separate destinations instead of one coherent operating flow.
10. Project screens need stronger priority ordering: daily work first, admin detail second.

## Target Mental Model

RHEIR should feel less like a collection of modules and more like a daily operating assistant for an active job.

The target mental model is:

1. Open RHEIR.
2. Immediately see today's job status.
3. Understand the next action.
4. Quickly record proof photos, receipts, labor, shopping needs, returns, or changes.
5. Trust that budget, labor, documents, and closeout data are being organized underneath.

Primary contractor priorities:

- Today's work
- Past due or needs review
- Receipts and returns
- Labor and unpaid balances
- Proof photos
- Client and project context
- Budget health

Lower-frequency workflows should remain available, but should not lead the daily surface:

- Estimator
- Deep company/admin resources
- Reports
- Formal close-out
- Advanced settings
- Rare workflows

## Recommended Navigation Model

The app should eventually organize around four high-frequency surfaces:

### 1. Today

The jobsite command center. This should eventually replace or absorb the current Brief mental model.

Today should answer:

- What is due now?
- What is late?
- What needs review?
- What should I do next?
- What proof or money needs to be recorded?

### 2. Receipts

Fast money capture and review.

Receipts should focus on:

- Scan/import/manual entry
- Returns
- Receipt review
- Category spending
- Proof status
- Payment method context

### 3. Labor

Crew time and pay tracking.

Labor should focus on:

- Log hours
- Review unpaid balances
- Pay workers
- View labor cost against project budget
- Keep worker balances clear

### 4. Plan

A unified schedule/work plan that combines existing data into one daily planning surface.

Plan should eventually combine:

- Tasks
- Timeline events
- Pickups
- Deliveries
- Inspections
- Client payment reminders
- Checklist prep
- Shopping needs
- Return reminders
- Labor context

## Naming Direction

These are candidate user-facing renames to evaluate later. Do not implement them in this documentation pass.

| Current Name | Candidate Name |
| --- | --- |
| Brief | Today |
| Breakdown | Budget |
| Timeline | Schedule or Plan |
| Docs | Files |
| Company | Resources |
| Attention | Needs Review |
| Overdue Tasks | Past Due |
| Task Checklists | Prep Lists or Checklists |

## Core UX Recommendation

Eventually merge the user-facing experience of Tasks, Timeline, and Checklist Prep into a unified Plan/Today layer.

Initial implementation should be display-only. Do not migrate storage or data models first. Create a UI adapter later that reads existing data and presents it through a unified plan surface.

Existing data sources to read from:

- `ProjectTask`
- `ProjectCalendarEvent`
- `WorkHour`
- `ProjectChecklist`
- `ProjectShoppingListItem`
- `ProjectPaymentMilestone`

Proposed display-only model:

```swift
ProjectPlanItem
ProjectPlanItemKind
ProjectPlanStatus
```

Suggested item kinds:

- `task`
- `pickup`
- `delivery`
- `payment`
- `inspection`
- `labor`
- `checklist`
- `shopping`
- `return`
- `changeOrder`

Suggested statuses:

- `pastDue`
- `dueToday`
- `upcoming`
- `completed`
- `needsReview`
- `planned`

## Screen-by-Screen Redesign Notes

### Projects

Projects should feel like a job launcher, not an admin list.

Recommended direction:

- The current project card should clearly show project, client, budget, status, and today's alert count.
- Active jobs should remain secondary but easy to switch.
- The screen should help the user get into the right job quickly.
- Project switching should be clear, but should not overpower the active job.
- Avoid making the first screen feel like a company database.

### Today / Brief

Today should become the emotional center of the app.

Recommended direction:

- Rename mentally from Brief toward Today.
- Show "Today at a glance."
- Prioritize Past Due, Due Today, Returns, Budget Health, and Next Action.
- The first visible content should be actionable items, not abstract stats only.
- Every count should be tappable and lead to the underlying filtered data.
- The user should never see "8 items need attention" without being able to tap and see those 8 items.
- Recent completed progress can remain useful, but should be collapsible so it does not consume daily operating space.

### Tasks

Tasks are essential, but the current surface has too many controls before the work.

Recommended direction:

- Simplify top-level task filters to Today / Past Due / All / Done.
- Consider a view switch for List and Calendar later.
- Task rows should show only the most important scan data:
  - Title
  - Category
  - Due state
  - Assigned person
  - Checklist/photo state
  - Completion control
- Details belong in the sheet, not the row.
- Add Task should stay fast and obvious, but should not crowd the filter bar.
- Sorting should include date due and optional custom/manual ordering.

### Task Detail

Preserve functionality. Improve hierarchy.

Recommended hierarchy:

1. Title
2. Status/actions
3. Due/category/assigned summary
4. Checklist
5. Before photos
6. After photos
7. Completion notes

Additional direction:

- Keep Mark Complete sticky only when useful.
- Photo empty/loading states should not visually dominate.
- Camera and photo import should feel like normal task proof tools, not oversized callouts.
- Checklist items linked to the task should be checkable from the task detail.
- Users should be able to link an existing checklist to a task or add a task checklist from the task.

### Labor

Labor is one of the clearer areas of the app.

Recommended direction:

- Keep the current model.
- Make unpaid amount the primary alert.
- Show unpaid total, next payroll context if available, and worker balances.
- Avoid making blue, green, and orange numbers compete equally.
- Logged hours must be editable and deletable when entered by mistake.
- Shared project worker identity should avoid duplicate "Owner" style worker records by supporting worker claiming and clear "not me" dismissal.

### Receipts

Receipts are powerful but visually crowded.

Recommended direction:

- Scan should be the primary action.
- Manual entry should be secondary.
- Refund filters should be calmer or grouped under Returns.
- Receipt rows should focus on:
  - Vendor
  - Amount
  - Category
  - Date
  - Payment method
  - Proof status
- Filter clearing must be obvious. Users should not have to remember which filter row is still active.
- Receipt item/SKU interpretation should be surfaced when available, especially for Home Depot and similar vendor receipts.

### Budget / Breakdown

Budget should be the mental model instead of Breakdown.

Recommended direction:

- Start with Budget Health:
  - Spent
  - Remaining
  - Percent used
  - On track / watch / over
- Then show category bars.
- Reports can live closer to Budget because reports explain where spending is going.
- Close-out should not be a constant red primary action unless it is contextually relevant.
- Labor cost, receipt cost, returns, contingency, and possible change orders must reconcile clearly.

### Docs / Files

Docs should move mentally toward Files.

Recommended direction:

- Keep import, scan, and add link.
- Make categories feel like a project file cabinet.
- Project files should be easy to browse quickly by category:
  - Contracts
  - Budgets
  - Pickup confirmations
  - Delivery orders
  - Design references
  - Permits
  - Other files
- Document scan should support camera-based scanning and later summary/category assignment.
- A category tap should move users directly to visible documents, not leave them wondering where the list is.

### Client

The Client direction is good: view first, edit intentionally.

Recommended direction:

- Contact actions should stay obvious:
  - Tap phone to call or text
  - Tap email to email
  - Tap address to open maps based on preference
- Questionnaire should be positioned as pre-start/site logistics.
- Client details should not open as editable by default.
- The client card should stay focused on job communication and decision-making context.

### Timeline

Timeline should eventually become part of Plan.

Recommended direction:

- Pickups, deliveries, inspections, payments, and dated tasks should appear together in the user-facing plan.
- Timeline and Tasks should not feel like competing places to look for date-based work.
- A calendar view can help users see what is coming up and adjust work around actual field progress.

### Shopping List

Shopping list is high-frequency field work and should not be hidden beside rare workflows.

Recommended direction:

- Shopping list should have Current and Completed tabs.
- Items should be checkable and uncheckable.
- Items should be organizable by store.
- Items should support long press/context menu actions for edit and delete.
- User-facing helper text can explain long press behavior.

### Change Orders

Change orders are important but lower frequency than shopping.

Recommended direction:

- Do not place change order controls beside shopping as if they are equal daily actions.
- Keep possible change orders accessible from Budget/Plan/Today where they affect cost, scope, or schedule.
- Make change orders clear enough for contractor/accounting review, but do not dominate daily field work.

## Visual Design Direction

Keep the dark, premium, field-ready appearance, but reduce visual competition.

Color guidance:

- Blue: primary action and selection
- Green: success, money, active, paid
- Orange: warning, unpaid, attention
- Red: overdue, destructive, true urgent state only

Typography and layout:

- Reduce all-caps usage.
- Reduce oversized bold text everywhere.
- Use more whitespace.
- Prefer system text styles and Dynamic Type-friendly hierarchy.
- Keep large touch targets.
- Let the first visible content be actionable, not decorative.
- Avoid making every number feel equally important.

Card hierarchy:

- Hero card
- Metric cards
- Primary actions
- Secondary admin/detail cards

The UI should feel professional, calm, and usable on a jobsite. It should not feel like an admin dashboard covered in equal-weight cards.

## Design System Components To Add Later

Potential reusable components:

- `RheirTheme`
- `RheirScreen`
- `RheirCard`
- `RheirHeroCard`
- `RheirMetricCard`
- `RheirStatusChip`
- `RheirSectionHeader`
- `RheirPrimaryActionButton`
- `RheirEmptyState`
- `RheirProjectHeader`
- `RheirPlanItemRow`

These should be introduced carefully. The first implementation pass should apply the components to one low-risk screen or section before broad adoption.

## Proposed Phased Implementation Plan

### Phase 0 - Documentation / Memory

- Create this UI/UX redesign plan.
- Update continuity.
- Commit docs only.

### Phase 1 - Design System Foundation

- Add reusable visual components.
- Apply to one low-risk screen or section.
- Avoid behavior changes.
- Avoid persistence changes.

### Phase 2 - Label and Hierarchy Cleanup

- Consider safer naming improvements.
- Improve visible labels and information hierarchy.
- Avoid large navigation changes until visual components exist.

### Phase 3 - Unified Plan Display Adapter

- Create a display-only `ProjectPlanItem` model.
- Combine tasks, timeline events, labor entries, checklist prep, shopping/returns/payment context for display only.
- Do not migrate persistence.
- Do not change existing model ownership.

### Phase 4 - Today Screen Redesign

- Rework Project Brief into Today/jobsite command center.
- Make top cards actionable.
- Surface next best action.
- Make every count navigable to filtered underlying data.

### Phase 5 - Task Detail Polish

- Preserve existing task completion, photos, checklists, notes, and assignment.
- Improve hierarchy and empty/loading states.
- Make proof photo capture/import feel like a natural part of task review.

### Phase 6 - Receipts, Labor, Budget, Files Polish

- Apply design system consistently.
- Keep high-frequency actions prominent.
- Keep admin/rare actions accessible but quieter.

### Phase 7 - Navigation Simplification

- Consider making Today / Receipts / Labor / Plan the main mental model.
- Move Budget, Client, Files, Reports, Estimate, and Resources into a project menu or secondary workspace.
- Do not do this until prior phases are stable.

## Safety Constraints

RHEIR has high persistence and data-loss risk. UI work must avoid accidental behavior changes in persistence-critical code.

Do not touch these areas in a UI-only pass unless the task explicitly requires it and has tests:

- `ProjectViewModel` mutation logic
- `OfflineDataManager`
- CloudKit services
- CloudKit sharing/import/save/refresh
- Task photo persistence
- Receipt image persistence
- Receipt math
- Labor payment ledger logic
- Worker claim logic
- Project aggregate serialization
- App entitlements
- `PrivacyInfo.xcprivacy`
- Real app container data
- `.xcappdata` files
- Production user/job data

When changing UI around persisted data, keep the first implementation display-only wherever possible.

## Validation Expectations

For this docs-only pass:

- Run `git diff --check`.
- Confirm only documentation files were changed for this pass.
- Confirm no Swift/source files were changed for this pass.
- Confirm no app data, generated files, containers, `xcuserdata`, `DerivedData`, or private artifacts were changed for this pass.
- Confirm continuity was updated in the existing continuity location.
- Commit the docs-only change.

For future UI implementation passes:

- Add or update focused tests for any changed behavior.
- Use simulator/device validation for navigation and field workflows.
- Validate persistence when a screen changes saved project data.
- Test relaunch persistence for tasks, dates, photos, labor, receipts, and shopping list items.
- Keep CloudKit/sharing behavior out of scope unless explicitly targeted.

## Explicit Non-Goals

This document does not approve or implement:

- Screen redesigns
- Swift source edits
- Behavior changes
- Model migrations
- Persistence changes
- CloudKit schema changes
- CloudKit sharing changes
- Receipt math changes
- Labor ledger changes
- Photo persistence changes
- Production data edits
- Entitlement changes
- Privacy manifest changes

This is a durable product direction and handoff document only.
