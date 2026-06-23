# HASOOB AI CFO Beta Manual Smoke Evidence

## Purpose

Use this checklist to capture practical evidence for an AI CFO beta demo or release smoke pass. The goal is to verify the cockpit flow, proposal guardrails, and recovery states without changing accounting behavior or relying on production data.

After a smoke pass, record observed results in the companion findings document: [AI CFO Beta Manual Smoke Findings](ai-cfo-beta-manual-smoke-findings.md).

## Safe Data Assumptions

- Use local, staging, or disposable demo data only.
- Use demo businesses that can be reset after the smoke pass.
- Do not use production customer balances, invoices, inventory, payment data, or credentials.
- Do not treat generated AI CFO advice as approval to mutate records.

## Environment Assumptions

- Current branch and commit are recorded before the smoke pass.
- Static analysis and relevant AI CFO/proposal tests have passed for the build under review.
- The tester can access the AI Accountant workspace with safe demo data.
- Screenshots are optional. If unavailable, capture clear written notes instead.

## Pre-Demo Checklist

| Item | Status | Evidence / Notes |
| --- | --- | --- |
| Current branch recorded | TODO | |
| Current commit recorded | TODO | |
| Static analysis result recorded | TODO | |
| Relevant AI CFO/proposal tests recorded | TODO | |
| Web/demo build result recorded, if used | TODO | |
| Demo data confirmed non-production | TODO | |
| Tester understands no guardrails should be bypassed | TODO | |

## Manual Smoke Checklist

| Step | Expected Result | Status | Evidence / Notes |
| --- | --- | --- | --- |
| Open AI Accountant workspace | Workspace loads without blocking errors | TODO | |
| Ask for a read-only CFO briefing | Response is advisory and evidence-backed | TODO | |
| Verify evidence, confidence, and missing-data notes | Missing data is shown instead of invented facts | TODO | |
| Generate or review a proposal | Proposal appears reviewable, not executed | TODO | |
| Open proposal review details | Proposal details are inspectable before approval | TODO | |
| Approve proposal only after review | Approval does not execute by itself | TODO | |
| Trigger guarded execution through approved flow | Delegation occurs only through the guarded screen path | TODO | |
| Observe started/running state | Running means waiting, not executed | TODO | |
| Observe successful execution result, if safely tested | Success appears only after external execution succeeds | TODO | |
| Observe failed/blocked/deferred/skipped state, if safely tested | State remains non-success and follow-up-oriented | TODO | |
| Try duplicate execution after executed, if safely tested | Duplicate execution is blocked or non-delegated | TODO | |
| Try approve/execute with no active proposal | Guard message appears and no execution delegates | TODO | |

## AI CFO Beta Flow Checklist

1. Open the AI Accountant workspace.
2. Ask for a read-only CFO briefing such as business health, customer risk, cashflow review, or inventory risk.
3. Verify evidence, confidence, and missing-data notes.
4. Generate or review a proposal.
5. Open proposal review details before approval.
6. Approve the proposal only after review.
7. Trigger guarded execution only through the approved proposal flow.
8. Verify started/running means waiting for an external result, not executed.
9. Verify success appears only after external execution success.
10. Verify failed, blocked, deferred, and skipped states remain non-success states.
11. Verify duplicate execution does not delegate twice.
12. Verify no active proposal plus approve or execute shows a guard message.

## Expected Evidence To Capture

- Branch and commit under test.
- Validation results used for the demo build.
- Screenshots or notes for read-only briefing, proposal review, approval, running/waiting, success, and recovery states.
- Observed proposal state labels.
- Execution guard messages.
- Failed, blocked, deferred, or skipped behavior, if safely exercised.
- Any unexpected UI copy, confusing transition, or mismatch between state and label.
- Final demo result: `PASS`, `PASS_WITH_NOTES`, or `FAIL`.

## Result Summary

| Outcome | Use When | Selected |
| --- | --- | --- |
| PASS | All required smoke checks match expected behavior | |
| PASS_WITH_NOTES | Core guardrails pass, but wording or demo notes need follow-up | |
| FAIL | Any state is misrepresented, execution delegates unsafely, or validation fails | |

## Known Non-Goals

- Do not validate production data.
- Do not test production credentials or secrets.
- Do not test migrations, schema changes, or database upgrade paths.
- Do not bypass review, approval, confirmation, or guarded execution.
- Do not accept fake execution or fake persistence as a successful demo result.
- Do not add a persistent proposal history or timeline during manual smoke.

## Risk Boundaries

- Controller is session-only orchestration.
- Controller must not execute proposals or persist proposal history.
- Presentation helper computes labels and delegation eligibility only.
- Real execution remains delegated through the AI Accountant repository and existing ProposalExecutionEngine path.
- Manual smoke must not use production data.
- Manual smoke must not bypass review, approval, or guarded execution.
- Started/running means waiting for an external result.
- Executed means the external execution result succeeded.
- Failed, blocked, deferred, skipped, or none outcomes must not render as success.

## Next-Step Triage Guidance

- If validation fails, stop the demo and record the failing validation name and error.
- If a label misrepresents state, capture the screen or note the exact copy and proposal state.
- If execution delegates twice or bypasses approval, mark the smoke pass `FAIL`.
- If a recovery state is confusing but safe, mark `PASS_WITH_NOTES` and file a wording follow-up.
- If any fix would require auth, schema, migration, ledger/database write, repository, or execution-engine changes, stop and escalate instead of broadening the smoke scope.
