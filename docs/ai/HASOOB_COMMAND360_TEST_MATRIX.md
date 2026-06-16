# HASOOB Command360 Test Matrix

## AI Accountant Screen Tests

| Test File | Subsystem Protected | Command360 Relevance | Run Safety | Command |
|---------|---------------------|--------------------|------------|---------|
| `test/ai_cfo_beta_release_test.dart` | UI rendering, TextField, basic layout | High | Fast | `flutter test test/ai_cfo_beta_release_test.dart` |

## Execution Engine Tests

| Test File | Subsystem Protected | Command360 Relevance | Run Safety | Command |
|---------|---------------------|--------------------|------------|---------|
| `test/ai_accountant_execution_engine_test.dart` | Proposal execution, purchase/sale, pricing, audit | Critical | Fast | `flutter test test/ai_accountant_execution_engine_test.dart` |

## Workflow Manager Tests

| Test File | Subsystem Protected | Command360 Relevance | Run Safety | Command |
|---------|---------------------|--------------------|------------|---------|
| `test/ai_workflow_manager_test.dart` | Multi-step workflows, purchase/sale/pricing workflows | High | Fast | `flutter test test/ai_workflow_manager_test.dart` |

## Financial Tools Tests

| Test File | Subsystem Protected | Command360 Relevance | Run Safety | Command |
|---------|---------------------|--------------------|------------|---------|
| `test/ai_accountant_financial_tools_test.dart` | getExpenses, getInvoices, getCustomers | High | Fast | `flutter test test/ai_accountant_financial_tools_test.dart` |

## Decision Engine Tests

| Test File | Subsystem Protected | Command360 Relevance | Run Safety | Command |
|---------|---------------------|--------------------|------------|---------|
| `test/ai_financial_decision_engine_test.dart` | Decision detection, scenario comparison | Medium | Fast | `flutter test test/ai_financial_decision_engine_test.dart` |

## Decision Questionnaire Tests

| Test File | Subsystem Protected | Command360 Relevance | Run Safety | Command |
|---------|---------------------|--------------------|------------|---------|
| `test/ai_decision_questionnaire_test.dart` | Multi-question decision flows | Medium | Fast | `flutter test test/ai_decision_questionnaire_test.dart` |

## Business Memory Tests

| Test File | Subsystem Protected | Command360 Relevance | Run Safety | Command |
|---------|---------------------|--------------------|------------|---------|
| `test/ai_business_memory_manager_test.dart` | Memory storage, retrieval, deduplication | High | Fast | `flutter test test/ai_business_memory_manager_test.dart` |
| `test/ai_long_term_cfo_memory_test.dart` | Long-term memory persistence | Medium | Fast | `flutter test test/ai_long_term_cfo_memory_test.dart` |
| `test/ai_conversation_memory_integration_test.dart` | Memory integration with conversation | Medium | Fast | `flutter test test/ai_conversation_memory_integration_test.dart` |

## Orchestrator Tests

| Test File | Subsystem Protected | Command360 Relevance | Run Safety | Command |
|---------|---------------------|--------------------|------------|---------|
| `test/ai_cfo_orchestrator_integration_test.dart` | Full conversation flow, decision integration | High | Fast | `flutter test test/ai_cfo_orchestrator_integration_test.dart` |

## Tool Planner Tests

| Test File | Subsystem Protected | Command360 Relevance | Run Safety | Command |
|---------|---------------------|--------------------|------------|---------|
| `test/ai_tool_planner_test.dart` | Intent classification, tool planning | High | Fast | `flutter test test/ai_tool_planner_test.dart` |

## Insight & Risk Tests

| Test File | Subsystem Protected | Command360 Relevance | Run Safety | Command |
|---------|---------------------|--------------------|------------|---------|
| `test/ai_insight_generator_test.dart` | Risk/insight/recommendation generation | Medium | Fast | `flutter test test/ai_insight_generator_test.dart` |
| `test/ai_response_metadata_test.dart` | Response metadata structure | Low | Fast | `flutter test test/ai_response_metadata_test.dart` |
| `test/ai_evidence_bundle_test.dart` | Evidence bundle construction | Low | Fast | `flutter test test/ai_evidence_bundle_test.dart` |

## Policy & Autonomy Tests

| Test File | Subsystem Protected | Command360 Relevance | Run Safety | Command |
|---------|---------------------|--------------------|------------|---------|
| `test/ai_cfo_policy_test.dart` | Policy evaluation for decisions | Medium | Fast | `flutter test test/ai_cfo_policy_test.dart` |
| `test/ai_executive_cfo_autonomy_test.dart` | Executive CFO behavior, risk detection | High | Fast | `flutter test test/ai_executive_cfo_autonomy_test.dart` |

## Integration Tests

| Test File | Subsystem Protected | Command360 Relevance | Run Safety | Command |
|---------|---------------------|--------------------|------------|---------|
| `test/ai_cfo_full_validation_test.dart` | End-to-end validation | High | Fast | `flutter test test/ai_cfo_full_validation_test.dart` |
| `test/ai_import_export_cfo_advisor_test.dart` | Import/export CFO logic | Medium | Fast | `flutter test test/ai_import_export_cfo_advisor_test.dart` |
| `test/ai_customer_credit_intelligence_test.dart` | Customer credit analysis | Medium | Fast | `flutter test test/ai_customer_credit_intelligence_test.dart` |

## Sync Tests (Not Directly Command360)

| Test File | Subsystem Protected | Command360 Relevance | Run Safety | Command |
|---------|---------------------|--------------------|------------|---------|
| `test/sync_*` tests | Sync operations, offline handling | Low | Fast | `flutter test test/sync_specific_test.dart` |

## Other Tests (Not Command360 Related)

| Test File | Subsystem Protected | Command360 Relevance | Run Safety | Command |
|---------|---------------------|--------------------|------------|---------|
| `test/auth_repository_test.dart` | Authentication | Low | Fast | `flutter test test/auth_repository_test.dart` |
| `test/startup_coordinator_test.dart` | App startup | Low | Fast | `flutter test test/startup_coordinator_test.dart` |
| `test/repository_sync_integration_test.dart` | Repository sync | Low | Fast | `flutter test test/repository_sync_integration_test.dart` |