# HASOOB AI CFO Safe Demo Environment Readiness

## Purpose

This audit records what is needed before the AI CFO beta human/device smoke can run safely. It does not create demo data, change configuration, run app smoke, or approve any production-data workflow.

## Current Blocker

Human/device smoke is not currently runnable as PASS evidence because the repo does not confirm a safe local, staging, or disposable app environment with disposable demo data. The app is local-first but can synchronize through Firebase after authentication, so manual smoke must not proceed until the auth/session path and data scope are known to be disposable.

## Required Environment

- A clearly identified local, staging, emulator, or disposable demo environment.
- A disposable authenticated user or session path whose business records can be reset.
- A disposable business scope with seeded or manually prepared demo records.
- A known way to prevent accidental use of production customer, invoice, inventory, payment, ledger, or pricing data.
- A documented decision on whether guarded execution may be tested, and exactly which disposable records it may affect.
- A validation record for static analysis and relevant AI CFO/proposal checks before the human smoke run.

## Safe Data Requirements

- Demo products, customers, invoices, accounts, and balances must be synthetic.
- Any purchase, sale, pricing simulation, invoice, inventory, or ledger-affecting smoke must be limited to disposable records.
- Demo data must be resettable or removable after the smoke run.
- Screenshots and notes must not include real customer data, real balances, production identifiers, secrets, or credentials.

## What Must Not Be Used

- Production Firebase users, businesses, customers, invoices, inventory, ledgers, payment data, or credentials.
- Real customer financial exposure.
- Real business balances or stock.
- Mock execution success as proof of real guarded execution.
- Undocumented local database files whose ownership or data source is unknown.
- Any path that bypasses proposal review, approval, confirmation, or guarded execution.

## Current Evidence From Repo Inspection

| Area | Evidence | Readiness impact |
| --- | --- | --- |
| App architecture | README describes local-first SQLite writes with Firebase synchronization. | Local data can still sync after auth; environment must be isolated. |
| Firebase config | `.firebaserc` points to `hasoob-4a281`; no staging/emulator project is documented. | Staging/disposable Firebase target is not confirmed. |
| Firestore rules | Rules allow authenticated users to access their own user documents. | Auth/session identity matters for smoke safety. |
| Auth gate | App routes through `AuthGate` after Firebase bootstrap. | Demo access requires a safe authenticated user or safe degraded/local path. |
| Business context | Sync initializes `BusinessContext` from authenticated user UID. | Disposable auth UID/business scope must be confirmed. |
| Mock repositories | `HASOOB_USE_MOCK_REPOSITORIES` can select mock repositories. | Useful for UI/demo isolation, but mock execution success is not valid real execution evidence. |
| AI Accountant execution | Screen delegates real execution through the repository/execution-engine path. | Execution smoke can affect data unless the environment is disposable. |
| Test fixtures | Automated tests seed temporary `qa-business` style data. | Useful as examples, but not documented as a runnable human-smoke data setup. |

## Candidate Environment Options

| Option | Description | Readiness |
| --- | --- | --- |
| Firebase emulator suite | Use local Auth/Firestore emulators with synthetic demo records. | Preferred if wiring and setup are documented before smoke. |
| Separate staging Firebase project | Use a non-production Firebase project with disposable accounts and data. | Acceptable if project identity, access, and reset process are documented. |
| Local-only degraded mode | Run without configured Firebase and use only safe local disposable SQLite data. | Acceptable only if auth/session access and AI Accountant workspace access are confirmed. |
| Mock repository mode | Run with `HASOOB_USE_MOCK_REPOSITORIES` for UI-only checks. | Useful for label/navigation smoke, but not valid for real execution success evidence. |
| Production project with test account | A test user inside the production Firebase project. | Not acceptable unless the project, records, and sync scope are explicitly disposable and isolated; default to not ready. |

## Recommended Next Setup Path

1. Choose an isolated environment: emulator or staging is preferred.
2. Document the Firebase/auth target and confirm it is not production.
3. Create or identify one disposable demo user and one disposable business scope.
4. Seed synthetic products, customers, invoices, accounts, and balances needed for AI CFO read-only and proposal flows.
5. Decide which execution checks are safe to run and which must remain `NOT_RUN`.
6. Record reset instructions for all demo data before running smoke.
7. Run static analysis and relevant AI CFO/proposal validations.
8. Run the manual smoke checklist and record only observed results in the findings document.

## What Remains Unknown

- Whether `hasoob-4a281` is production, staging, or disposable.
- Whether a Firebase emulator setup is currently configured for manual app runs.
- Whether a safe demo user already exists.
- Whether a disposable business scope and reset process already exist.
- Whether local SQLite data on this machine is synthetic or tied to real business records.
- Whether guarded execution can be safely tested on this machine without affecting non-disposable data.

## Runnable Human Smoke Checklist

Human smoke can be marked runnable only when every item below is confirmed:

| Requirement | Status | Notes |
| --- | --- | --- |
| Environment type identified as local, staging, emulator, or disposable | NOT_CONFIRMED | |
| Firebase/auth target confirmed non-production or isolated | NOT_CONFIRMED | |
| Demo user/session confirmed disposable | NOT_CONFIRMED | |
| Business scope confirmed disposable | NOT_CONFIRMED | |
| Demo data confirmed synthetic | NOT_CONFIRMED | |
| Reset/removal process documented | NOT_CONFIRMED | |
| Guarded execution scope explicitly approved for disposable records | NOT_CONFIRMED | |
| Screenshots/notes policy excludes real data and secrets | NOT_CONFIRMED | |
| Automated validation completed for the build under smoke | NOT_CONFIRMED | |

## Risk Boundaries

- Do not touch authentication to create this readiness plan.
- Do not change database schema, migrations, ledger writes, repository behavior, or execution-engine behavior.
- Do not add fake execution, fake persistence, or fake demo data into production paths.
- Do not run manual smoke against production data.
- Do not mark execution checks as PASS unless observed in a safe disposable environment.
- Do not accept mock execution success as proof of real guarded execution.
- Keep controller behavior session-only and real execution repository/execution-engine delegated.
