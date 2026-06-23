# HASOOB Launch Candidate Cutline

## Launch Scope

This cutline evaluates HASOOB as a controlled MVP launch candidate. The MVP scope is the authenticated app shell, core navigation, dashboard visibility, inventory/product management, sales history, customer management, documents for invoices and quotations, reports, and the AI Accountant / AI CFO workspace as a clearly bounded beta feature.

## Not Included / Deferred Scope

- Production AI CFO autonomous execution claims.
- Any unreviewed ledger, accounting, invoice-numbering, sync queue, or repository execution changes.
- Auth architecture changes, hidden demo users, or AuthGate bypasses.
- Database schema changes or migrations.
- Real execution smoke unless a disposable environment is confirmed.
- Production-data demo or smoke evidence.

## Launch Cutline Result

`READY_WITH_LIMITATIONS`

The codebase can continue toward a controlled MVP launch only with the listed limitations and blockers tracked. Static inspection found the main app shell, navigation, and core modules present. AI CFO must remain `BETA` because safe manual execution smoke and disposable real execution evidence are not confirmed.

## Must-Fix Before Launch

| Area | Severity | Status | Required action |
| --- | --- | --- | --- |
| Safe launch environment | Blocker | BLOCKED | Confirm whether Firebase/app data target is production, staging, emulator, or disposable. |
| Manual smoke on device/browser | Blocker | BLOCKED | Run observed smoke for auth/session stability, navigation, inventory, customers, sales, documents, reports, and AI CFO beta in a safe environment. |
| AI CFO real execution evidence | Blocker for production execution claims | BLOCKED | Keep AI CFO execution beta-labeled until real guarded execution is validated with disposable records. |
| Production data protection | Blocker | BLOCKED | Confirm no launch validation uses production customer, invoice, inventory, payment, ledger, or business records. |

## Can-Launch-With-Warning Items

| Area | Status | Launch warning |
| --- | --- | --- |
| AI Accountant / AI CFO | BETA | Advisory and proposal-review workflow only unless guarded execution is validated in disposable data. |
| Reports and analytics widgets | READY_WITH_LIMITATIONS | Useful for MVP visibility, but launch validation should verify real data freshness and empty states. |
| Local/degraded mode | READY_WITH_LIMITATIONS | May support app access when Firebase bootstrap is unavailable, but must not be represented as production sync readiness. |
| Mock repositories | UI_ONLY | Useful for UI checks only; mock success is not real persistence or execution evidence. |

## Beta-Labeled Features

- AI CFO guidance, evidence, and recommendations.
- AI CFO proposal review and recovery states.
- AI CFO guarded execution handoff until real execution smoke is completed in a disposable environment.
- Advanced analytics and diagnostic panels where data completeness has not been manually verified.

## AI CFO Launch Status

`BETA`

AI CFO has controller, lifecycle, proposal, outcome, and presentation guardrails in place, and automated proposal tests exist. It is not production-execution-ready from this cutline alone because manual smoke and disposable real execution evidence remain unconfirmed. No fake execution or mock persistence should be accepted as launch proof.

## Risk Boundaries

- Do not bypass `AuthGate`.
- Do not add hidden demo users.
- Do not change database schema or add migrations without explicit review.
- Do not change ledger/accounting write semantics.
- Do not change repository execution semantics.
- Do not change `ProposalExecutionEngine` semantics.
- Do not present mock execution as real execution.
- Do not use production data for launch validation.

## Acceptance Checklist

| Check | Status | Notes |
| --- | --- | --- |
| Auth/session does not auto-log out during smoke | BLOCKED | Requires observed safe app run. |
| Main navigation opens all MVP destinations | BLOCKED | Requires observed safe app run. |
| Dashboard loads or shows recoverable empty/error state | BLOCKED | Requires observed safe app run. |
| Inventory/product flows are not obviously broken | BLOCKED | Requires observed safe app run. |
| Sales/customer/document flows are not obviously broken | BLOCKED | Requires observed safe app run. |
| Reports load or show recoverable empty/error state | BLOCKED | Requires observed safe app run. |
| AI CFO is clearly bounded as beta | READY_WITH_LIMITATIONS | Existing docs/tests support beta framing; real execution remains blocked. |
| Mock execution is not presented as real | READY | Existing AI CFO safety docs preserve this boundary. |
| Ledger/database behavior unchanged in this cutline | READY | No schema, migration, ledger, repository, or execution-engine changes made. |
| Static analysis passes | READY | Recorded during this cutline. |

## Release-Blocker Table

| Blocker | Severity | Owner action | Recommended sprint |
| --- | --- | --- | --- |
| Safe environment not confirmed | P0 | Identify staging/emulator/disposable target and reset path. | Launch Safe Environment Confirmation |
| Human/device smoke not run | P0 | Execute MVP checklist with screenshots/notes against safe data. | Launch Manual Smoke Execution |
| AI CFO real execution not proven | P1 | Validate guarded execution only with disposable records. | AI CFO Disposable Execution Verification |
| Production data exposure risk unresolved | P0 | Confirm validation data source and screenshot policy. | Launch Data Safety Gate |

## Safe Fixes Applied In This Cutline

| File | Fix | Risk |
| --- | --- | --- |
| `lib/screens/auth/auth_gate.dart` | Passive cloud/local banner now renders its provided status message instead of hardcoded text. | Presentation-only; no auth behavior changed. |

## Recommended Next Sprint If Blocked

Run a Launch Manual Smoke Execution sprint after confirming a safe environment. The sprint should observe auth/session stability, navigation, dashboard, inventory, products, sales, customers, documents, reports, and AI CFO beta boundaries without production data and without changing ledger/database/execution semantics.