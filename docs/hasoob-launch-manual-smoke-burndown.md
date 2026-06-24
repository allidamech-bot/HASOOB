# HASOOB Launch Manual Smoke Burn-down

## What Was Inspected

- App startup and `AuthGate` session routing.
- Main navigation shell and MVP destinations.
- Dashboard, inventory/products, sales, customers, documents/invoices/quotations, and reports surfaces.
- AI Accountant / AI CFO beta labels, proposal guardrails, and existing safety docs.

## Safe-Fixed

| Area | Fix | Why safe |
| --- | --- | --- |
| AuthGate login banner | Changed the no-user banner from cloud-sync preparation wording to sign-in-required wording. | Copy-only; no auth/session behavior, Firebase config, sync queue, or data writes changed. |

## Launch-Blocking Items

| Blocker | Severity | Status |
| --- | --- | --- |
| Safe launch environment not confirmed | P0 | BLOCKED |
| Real manual smoke not performed in this sprint | P0 | BLOCKED |
| Production data isolation not confirmed | P0 | BLOCKED |
| AI CFO real execution evidence not confirmed | P1 | Keep AI CFO as BETA |

## Deferred After Launch

- AI CFO production execution claims.
- Advanced analytics completeness hardening.
- Any ledger, repository, sync, invoice-numbering, or accounting behavior changes.
- Cosmetic UI polish that does not block MVP use.

## Manual Smoke Checklist

Run only with a confirmed safe environment and disposable data.

| Area | Check | Expected |
| --- | --- | --- |
| Startup | App opens without startup crash. | Login or authenticated shell appears. |
| Auth/session | Sign in, idle briefly, navigate, and refresh if applicable. | User remains signed in unless explicitly signing out. |
| Navigation | Open every main destination. | No dead destination or crash. |
| Dashboard | Load dashboard with empty or seeded data. | Recoverable content, empty, or error state appears. |
| Inventory/products | Add/view/search product if safe. | Product flow works without obvious presentation breakage. |
| Sales | Open sales history and create sale only if disposable data is approved. | No production data touched. |
| Customers | Add/view customer if safe. | Customer flow works with disposable data. |
| Documents | Open invoices and quotations; create only if safe. | Numbering and document behavior observed, not changed. |
| Reports | Open reports. | Report page loads or shows recoverable state. |
| AI CFO beta | Ask/read advisory flow and proposal states. | Clearly beta/advisory; no fake execution presented as real. |

## Final Launch Status

`READY_WITH_LIMITATIONS`

The app can continue toward MVP launch review, but launch evidence remains blocked until safe-environment confirmation and observed manual smoke are completed. AI CFO remains `BETA`.
