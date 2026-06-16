# HASOOB Command360 Targeted Regression Command Map

## Tier 0 - Preflight

`bash
git status --short
git diff --check
flutter analyze 2>&1 | head -50
`

**Notes:**
- flutter analyze may show pre-existing issues unrelated to Command360
- Skip full suite until after targeted tests pass
- Working tree must be clean before any test run

## Tier 1 - Fast Domain Safety Tests

These tests verify core domain/service behavior without database mutations or UI rendering.

`bash
# Workflow manager tests (fast, no DB)
flutter test test/ai_workflow_manager_test.dart --timeout 30s

# Financial tools tests (requires DB setup but fast)
flutter test test/ai_accountant_financial_tools_test.dart --timeout 30s

# Tool planner tests (fast, no DB)
flutter test test/ai_tool_planner_test.dart --timeout 30s

# Business memory manager tests (fast, no DB)
flutter test test/ai_business_memory_manager_test.dart --timeout 30s

# UI responsive tests (fast, no DB)
flutter test test/ui_responsive_test.dart --timeout 30s

# Widget smoke test (minimal UI)
flutter test test/widget_test.dart --timeout 30s
`

## Tier 2 - AI Accountant / Execution Safety Tests

These tests protect the proposal creation, execution engine, tools, and repository-related behavior.

`bash
# Core execution engine tests (DB required, guarded)
flutter test test/ai_accountant_execution_engine_test.dart --timeout 60s

# Evidence bundle tests (fast)
flutter test test/ai_evidence_bundle_test.dart --timeout 30s

# Response metadata tests (fast)
flutter test test/ai_response_metadata_test.dart --timeout 30s
`

**Critical behaviors verified:**
- Purchase/sale execution with journal entries
- Product match confirmation flow
- Missing chart accounts guard
- Transaction rollback on failure
- Audit log creation attempts
- Inventory stock validation
- Pricing simulation persistence

## Tier 3 - CFO / Workflow / Memory Safety Tests

Tests for CFO, workflow, memory, decision, and advisor components.

`bash
# Beta/release gate test (UI rendering, fast)
flutter test test/ai_cfo_beta_release_test.dart --timeout 60s

# Executive CFO autonomy tests (fast, no DB)
flutter test test/ai_executive_cfo_autonomy_test.dart --timeout 60s

# CFO orchestrator integration tests (async network potential)
flutter test test/ai_cfo_orchestrator_integration_test.dart --timeout 60s

# Long-term CFO memory tests (fast, no DB)
flutter test test/ai_long_term_cfo_memory_test.dart --timeout 60s

# Financial decision engine tests (fast)
flutter test test/ai_financial_decision_engine_test.dart --timeout 60s

# Decision questionnaire tests (fast)
flutter test test/ai_decision_questionnaire_test.dart --timeout 30s

# Customer credit intelligence tests (fast)
flutter test test/ai_customer_credit_intelligence_test.dart --timeout 60s

# Import/export CFO advisor tests (fast)
flutter test test/ai_import_export_cfo_advisor_test.dart --timeout 60s
`

**Known timeout-risk tests:**
- ai_cfo_orchestrator_integration_test.dart - May involve async operations

## Tier 4 - UI / Golden / Expensive Tests

Tests that are expensive, flaky, platform-sensitive, or golden-sensitive.

`bash
# Golden screenshot tests (platform-sensitive)
flutter test test/golden_screenshot_test.dart --timeout 120s --tags golden

# Financial snapshot tests (may be slow)
flutter test test/ai_financial_snapshot_test.dart --timeout 120s
`

**When to run:**
- Before major releases only
- In CI visual-golden-tests job
- When UI layout changes are made
- Never by default during development

## Tier 5 - Full Suite

The full flutter test suite may timeout on Windows due to platform-specific delays.

`bash
# Full suite with generous timeout (CI preferred)
flutter test --timeout 300s 2>&1 | tee test_full_output.log
`

**When to use:**
- Before major releases
- In CI/CD pipeline
- After any refactor touching core execution paths
- Do not run on Windows development machines routinely

## Future Refactor Gate Checklist

After each future refactor type, run the indicated tier before proceeding.

### Documentation-only change
- **Tier 0 only**
- No test run required

### Pure extraction with no behavior change
- **Tier 0 + Tier 1**
- Verify workflow and tools unchanged

### Conversation state extraction
- **Tier 0 + Tier 2**
- Verify execution behavior unchanged
- Verify proposal creation unaffected

### Intent classification extraction
- **Tier 0 + Tier 1 + Tier 2**
- Verify ai_tool_planner_test.dart passes
- Verify execution engine unchanged

### Proposal state extraction
- **Tier 0 + Tier 1 + Tier 2**
- Verify execution engine behavior unchanged
- Verify audit logging continues

### Execution call-chain change
- **Tier 0 + Tier 2**
- Critical: Run ai_accountant_execution_engine_test.dart
- Verify all action types still work

### Ledger preview extraction
- **Tier 0 + Tier 2**
- Verify before/after state in execution results

### UI layout/widget extraction
- **Tier 0 + Tier 4**
- Run golden tests if layout changed
- Run ai_cfo_beta_release_test.dart

### Repository/factory/tool change
- **Tier 0 + Tier 1 + Tier 2**
- Verify ai_accountant_repository_factory.dart behavior
- Verify all tool calls still function
- Critical: Run financial tools tests

## Quick Reference Commands

`bash
# Quick pre-commit verification
git status --short && flutter test test/ai_workflow_manager_test.dart --timeout 30s

# Before merge to main
git status --short && flutter analyze && flutter test --timeout 300s

# When execution logic changes
flutter test test/ai_accountant_execution_engine_test.dart --timeout 60s

# When intent changes
flutter test test/ai_tool_planner_test.dart test/ai_executive_cfo_autonomy_test.dart --timeout 60s
`
