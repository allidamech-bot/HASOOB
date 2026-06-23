# HASOOB AI CFO Mock/UI-Only Smoke Access Audit

## Purpose

This document audits whether the AI CFO experience can be reached safely in mock/UI-only mode for navigation, copy, labels, proposal review, and guard-state observation. It is an `AUDIT_ONLY` record based on repository and documentation inspection.

This audit did not run the app, did not perform human/device smoke, did not create demo data, did not bypass authentication, and did not exercise real proposal execution.

## Audit Status

| Item | Status | Notes |
| --- | --- | --- |
| Audit type | AUDIT_ONLY | Code and documentation inspection only. |
| Real app run performed | No | No manual smoke observations were collected. |
| Human smoke PASS evidence produced | No | PASS evidence requires an observed run in a safe environment. |
| Real execution evidence produced | No | Mock execution cannot prove real ledger, database, repository, or execution-engine behavior. |

## Findings

| Question | Finding | Impact |
| --- | --- | --- |
| Is mock repository mode present? | Yes. `AppConfig.isTestingMode` is controlled by `HASOOB_USE_MOCK_REPOSITORIES`, and repository factories use it to select mock repositories. | Mock mode is available as a repository selection path. |
| Is it documented enough for safe smoke? | Partially. The flag and mock repository behavior are visible in code and readiness notes, but a full safe runbook for auth/session access and data isolation is not confirmed. | Mock/UI-only smoke should remain `NOT_RUN` until the safe access path is documented and observed. |
| Can AI CFO be safely reached without production auth/data? | Not confirmed. The app still starts through Firebase bootstrap and `AuthGate`; mock repositories do not by themselves document a safe authenticated or degraded access path. | Do not claim production-safe access until the auth/session path is confirmed isolated. |
| Was a real app run performed? | No. | This document is not manual smoke evidence. |
| Can mock mode prove real execution? | No. `MockAiAccountantRepository.executeProposalDetailed` returns a mock success result with mock sync/audit data. | Mock success must not be counted as real guarded execution, persistence, ledger, or database evidence. |
| Can human smoke be marked PASS from this audit? | No. | Human smoke remains `NOT_RUN` until a safe environment exists and is observed. |

## Access Path Notes

- AI Accountant uses `AiAccountantRepositoryFactory.make()` to select the AI Accountant repository.
- With `HASOOB_USE_MOCK_REPOSITORIES`, the AI Accountant repository factory can select `MockAiAccountantRepository`.
- The same testing-mode flag is also used by other repository factories across the app, so mock mode is broader than the AI CFO screen alone.
- Mock repository mode does not remove startup, Firebase bootstrap, or `AuthGate` considerations.
- AI CFO screen access still depends on reaching the authenticated or safe degraded app navigation path.
- No production auth, production customer data, production ledger data, or production business records should be used to test access.

## What Mock/UI-Only Mode Can Support

Mock/UI-only mode is a candidate for observing presentation and session behavior after a safe app access path is confirmed:

| Area | Classification | Notes |
| --- | --- | --- |
| AI Accountant workspace navigation | UI-only mock candidate | Candidate only after safe auth/session or degraded access is confirmed. |
| AI CFO copy, labels, and empty states | UI-only mock candidate | Useful for visual review, not data correctness proof. |
| Proposal review presentation | UI-only mock candidate | Can inspect proposal copy and guarded UI states if safely reachable. |
| Review, defer, approve labels | UI-only mock candidate | Can observe session-facing labels without proving real execution. |
| No-active-proposal guard copy | UI-only mock candidate | Can verify guard text and disabled/non-delegated states if reachable. |
| Running/waiting guard labels | UI-only mock candidate | Can inspect presentation states if safely produced. |
| Real execution success | Real disposable environment required | Mock success is not valid real execution evidence. |
| Ledger/database side effects | Real disposable environment required | Requires disposable records and approved smoke scope. |
| Repository/execution-engine behavior | Real disposable environment required | Must use the real repository/execution path in an isolated environment. |

## Checklist Classification

| Smoke item | Classification | Required before PASS |
| --- | --- | --- |
| Open AI Accountant workspace | UI-only mock candidate | Safe auth/session or degraded access path confirmed and observed. |
| Read AI CFO briefing text | UI-only mock candidate | Safe app access and observed screen evidence. |
| Review evidence, confidence, and missing-data copy | UI-only mock candidate | Safe app access and observed screen evidence. |
| Show proposal review details | UI-only mock candidate | Safe app access and observed proposal state. |
| Approve after review | UI-only mock candidate | Safe app access; approval copy/state only, not real execution evidence. |
| Guarded execute intent delegates externally | Real disposable environment required | Must observe real delegation through the existing repository/execution-engine path. |
| Started/running outcome does not mark executed | UI-only mock candidate for labels; real disposable environment required for real flow | Mock-only labels do not prove external execution behavior. |
| External success marks executed | Real disposable environment required | Must be observed after real external completion in disposable data. |
| Failed outcome records failure without execution | UI-only mock candidate for labels; real disposable environment required for real flow | Mock-only failure/copy evidence is not real execution evidence. |
| Deferred proposal cannot be treated as executed | UI-only mock candidate | Safe app access and observed session state required. |
| Skipped/no-op cannot fabricate execution | UI-only mock candidate | Safe app access and observed state required. |
| Duplicate execution after executed is blocked or non-delegated | Real disposable environment required | Requires a real executed state in a safe disposable environment. |

## Items That Remain NOT_RUN

- Any manual smoke row that requires app observation.
- Any real execution success, failure, duplicate-execution, ledger, persistence, or database side-effect check.
- Any claim that AI CFO can be reached without production auth/data.
- Any screenshot or demo evidence that has not been observed in a safe environment.

## Recommended Safe Path Before Manual Smoke

1. Confirm a non-production access path: emulator, staging, disposable demo user, or safe degraded/local mode.
2. Confirm the business scope and data are disposable and resettable.
3. Run mock mode only for UI-only navigation, copy, labels, proposal review, and guard-state checks.
4. Keep all real execution checks as `NOT_RUN` unless a disposable real execution environment is explicitly approved.
5. Record observed results in the manual smoke evidence/findings documents only after a real observed run.

## Boundary Confirmation

- No code changed for this audit.
- No UI layout or design changed.
- No tests changed.
- No authentication behavior changed.
- No database schema, migrations, ledger writes, repository behavior, or execution-engine behavior changed.
- No fake execution or fake persistence was added.
- No production-data instructions were added.
- Mock execution success remains UI/demo-only evidence and must not be treated as real execution evidence.

## Conclusion

Mock repository mode is present and can be a useful UI-only candidate after safe access is confirmed. It is not enough by itself to prove that AI CFO can be safely reached without production auth/data, and it cannot prove real proposal execution. Human/device smoke remains `NOT_RUN` until a safe environment is documented and observed.
