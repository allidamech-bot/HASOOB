# HASOOB AI CFO Beta Demo Runbook

## Purpose

Use this runbook to demo and regression-check the AI CFO beta safely. The beta should show evidence-backed CFO guidance, proposal review, guarded execution handoff, and recovery states without changing accounting behavior outside the existing execution path.

## Safe Demo Assumptions

- Use local, staging, or disposable demo data.
- Treat AI CFO output as advisory until a human reviews the evidence and proposal.
- Keep execution demos limited to data that can be reset after the session.
- Confirm that proposal execution still routes through the existing repository and execution engine.

## Do Not Test On Production Data

- Do not run purchase, sale, invoice, inventory, payment, or pricing execution demos against production businesses.
- Do not test with real customer financial exposure unless the data is approved for demo use.
- Do not add credentials, secrets, migration steps, or production database instructions to demo notes.
- Do not bypass proposal review, confirmation, or guarded execution prompts.

## Recommended Demo Flow

1. Open the AI Accountant workspace.
2. Ask for a read-only CFO briefing, such as business health, customer risk, inventory risk, or cashflow review.
3. Confirm that the response includes evidence, confidence, and missing-data notes when data is incomplete.
4. Prepare a proposal, such as a sale, purchase, or pricing simulation.
5. Open review details before approving or executing.
6. Approve the proposal only after checking the proposed action and evidence.
7. Trigger execution only through the guarded screen action or approved execution intent.
8. Confirm the screen shows started/running as waiting, not executed.
9. Confirm success appears only after the external execution result succeeds.
10. Confirm failed, blocked, skipped, or deferred states remain non-success states.

## Proposal Lifecycle Checklist

- No active proposal plus approve or execute should show a guard message.
- Generated proposal should appear as reviewable, not automatically executed.
- Reviewed proposal may continue to approval according to current policy.
- Approved/executable proposal may delegate to the existing execution path.
- Deferred proposal should stay deferred and not appear ready to execute.
- Blocked proposal should show follow-up wording, not completion wording.
- Failed proposal should show follow-up wording, not success wording.
- Executed proposal should not delegate duplicate execution.

## Expected Guardrail Behavior

- Controller is session-only orchestration.
- Controller does not execute proposals.
- Controller does not persist proposal history.
- Presentation helper only computes labels and delegation eligibility.
- Real execution remains delegated through the AI Accountant repository and existing ProposalExecutionEngine path.
- Started/running means waiting for an external result.
- Executed means the external execution result succeeded.
- Skipped, blocked, failed, and deferred outcomes cannot fabricate execution state.

## Validation Checklist

- Static analysis passes.
- Proposal flow E2E tests pass.
- Proposal session controller tests pass.
- Proposal execution presentation state tests pass.
- Execution outcome normalizer tests pass.
- Proposal state reducer tests pass.
- Proposal command adapter and decision policy tests pass.
- Beta screen smoke test passes.
- Web release build passes before sharing a demo build.

## Rollback Or Hotfix Note

If CI, static analysis, tests, or the web build fail, do not demo a new build. Keep the last known good beta build, capture the failing validation name and error, and make a small hotfix that preserves the same safety boundaries: no auth changes, no schema changes, no ledger/database write changes, no fake execution, and no fake persistence.
