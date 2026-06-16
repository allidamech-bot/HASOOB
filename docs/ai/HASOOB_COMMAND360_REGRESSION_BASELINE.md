# HASOOB Command360 Regression Safety Baseline

## A. Critical Behaviors That Must Not Break

The following behaviors must remain intact during any future Command360 refactor:

### Screen-Level Behaviors

| Behavior | Verification | Notes |
|----------|--------------|-------|
| AI Accountant screen opens correctly | `ai_cfo_beta_release_test.dart` | Widget renders without errors |
| Conversation input remains usable | `ai_cfo_beta_release_test.dart` | TextField present and interactable |
| Message list/state behavior remains stable | `ai_accountant_screen.dart` local state | IndexedStack preserves state between tabs |
| Quick actions render correctly | `ai_cfo_beta_release_test.dart` | Action chips visible |

### State Management Behaviors

| Behavior | Verification | Notes |
|----------|--------------|-------|
| Intent classification behavior remains preserved | `ai_tool_planner_test.dart` | Plans correctly for different intents |
| Proposal creation behavior remains preserved | `ai_workflow_manager_test.dart` | Workflows create valid proposals |
| Active proposal state behavior remains preserved | `ai_accountant_screen.dart` | Proposal persists through chat |
| Proposal execution calls remain preserved | `ai_accountant_execution_engine_test.dart` | Engine executes correctly |
| Ledger preview behavior remains preserved | `ai_accountant_execution_engine_test.dart` | Preview rows added correctly |

### Data/Repository Behaviors

| Behavior | Verification | Notes |
|----------|--------------|-------|
| Existing financial tools remain callable | `ai_accountant_financial_tools_test.dart` | Tools return correct data |
| Existing repository factory behavior preserved | `ai_accountant_repository_factory.dart` | Mock vs Firestore selection works |
| Existing Firestore/Gemini fallback preserved | `firestore_ai_accountant_repository.dart` | Falls back to mock when needed |
| Existing mock/dev behavior preserved | `MockAiAccountantRepository` | Safe for testing/development |

### External Dependency Behaviors

| Behavior | Verification | Notes |
|----------|--------------|-------|
| PDF/printing/image_picker dependencies untouched | `pubspec.yaml` | No changes to assets |
| Firebase + SQLite accounting flows untouched | Multiple tests | Execution engine tests verify this |

## B. Safety Assertions Before Refactor

These assertions have been verified by existing tests and must continue to hold:

```dart
// unknown action must not execute
// - ProposalExecutionEngine returns error for unknown action types

// purchase requires valid payload
// - Financial payload must have quantity > 0, costPrice >= 0
// - Product identity must be resolvable

// sale requires product match
// - Product must exist or be identifiable
// - RequiresUserConfirmation when ambiguous

// pricing simulation saves safely
// - Saves to pricing_simulations table + sync queue

// tool response does not change accounting data
// - Read-only operations, no DB mutations

// audit failure does not crash execution
// - Local transaction succeeds even if Firestore audit fails

// AI screen still renders
// - Workspace mode and normal mode both work
```

## C. Protected Execution Paths

| Path | Entry Point | Safety Net | Must Preserve |
|------|-------------|------------|---------------|
| `parseNaturalLanguage` | `FirestoreAiAccountantRepository` | JSON response validation | Returns valid `AiProposalModel` |
| `executeProposal` | `AiAccountantRepository` | Database transactions | Creates journal entries, invoices correctly |
| `executeProposalDetailed` | `ProposalExecutionEngine` | Guard accounts + product match | Full audit trail maintained |
| `handleMessage` | `AiWorkflowManager` | Step-by-step collection | Workflows complete properly |
| `generateResponse` | `AiConversationOrchestrator` | Intent classification | Returns structured response |