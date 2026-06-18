# HASOOB Command360 Refactor Risk Register

## Critical Risk Areas Before Refactor

### 1. AiAccountantScreen Mixed Responsibilities

| Field | Value |
|-------|-------|
| **Risk description** | The screen contains conversation UI, state management, intent classification, proposal handling, and ledger preview all in one widget |
| **Affected files** | `lib/features/ai_accountant/presentation/screens/ai_accountant_screen.dart` |
| **Possible regression** | Extracting logic may break message rendering, proposal display, or execution flow |
| **Detection method** | `ai_cfo_beta_release_test.dart`, `ai_cfo_full_validation_test.dart`, widget tests |
| **Safe mitigation** | Keep original screen intact; build overlays; extract only via composition; maintain backward compatibility |

### 2. Conversation State Coupling

| Field | Value |
|-------|-------|
| **Risk description** | `_messages` list is tightly coupled to `List<Widget>` builders; state mutation triggers rebuilds |
| **Affected files** | `ai_accountant_screen.dart` lines 129-143 |
| **Possible regression** | Message addition/loss; scrolling behavior; chat history reset on navigation |
| **Detection method** | Visual test; check if welcome message persists; check if messages accumulate |
| **Safe mitigation** | Move to `AiWorkspaceController` gradually; preserve `List<AiChatMessage>` structure; add provider wrapper |

### 3. Proposal State Coupling

| Field | Value |
|-------|-------|
| **Risk description** | `_activeProposal` and `_confirmationProposal` are local screen state; lost on screen disposal |
| **Affected files** | `ai_accountant_screen.dart` lines 113-116 |
| **Possible regression** | Proposal disappears on navigation; cannot resume proposal review; double-submit |
| **Detection method** | Execute a proposal; navigate away and back; verify proposal state |
| **Safe mitigation** | Move to `AiWorkspaceController`; add TODO(UI.4.3) markers; preserve setter/getter pattern |

### 4. Intent Classification Inside UI

| Field | Value |
|-------|-------|
| **Risk description** | `_processAiCommand()` handles classification, workflow, tool planning inline |
| **Affected files** | `ai_accountant_screen.dart` lines 179-308 |
| **Possible regression** | Wrong proposal type; missing tool calls; wrong response format |
| **Detection method** | `ai_tool_planner_test.dart`; `ai_cfo_orchestrator_integration_test.dart` |
| **Safe mitigation** | Extract to `Command360Orchestrator`; maintain existing method signatures; delegate from screen |

### 5. Ledger Preview Coupling

| Field | Value |
|-------|-------|
| **Risk description** | `_ledgerRows` is local state; `_addPreviewLedgerRow()` manipulates in-place |
| **Affected files** | `ai_accountant_screen.dart` lines 145-170, 393-416 |
| **Possible regression** | Preview rows not added; wrong styling; row not cleared after execution |
| **Detection method** | Create proposal; verify "PENDING-AI" row appears in ledger panel |
| **Safe mitigation** | Move to `AiWorkspaceController`; preserve row structure; add `LedgerEntry` model alias |

### 6. Execution Engine Call Chain

| Field | Value |
|-------|-------|
| **Risk description** | `_executeProposal()` calls repository; handles results; updates UI state |
| **Affected files** | `ai_accountant_screen.dart` lines 473-536 |
| **Possible regression** | Execution not triggered; result not displayed; error swallowed |
| **Detection method** | `ai_accountant_execution_engine_test.dart` |
| **Safe mitigation** | Keep screen method calling existing engine; do not modify engine call contract |

### 7. Repository Selection and Fallback Behavior

| Field | Value |
|-------|-------|
| **Risk description** | `AiAccountantRepositoryFactory.make()` chooses between Mock and Firestore |
| **Affected files** | `lib/features/ai_accountant/data/repositories/ai_accountant_repository_factory.dart` |
| **Possible regression** | Wrong repository used; null responses; missing fallback |
| **Detection method** | Check `AiAccountantRepositoryFactory.make()` returns non-null; verify mock mode works |
| **Safe mitigation** | Preserve factory; add optional logging; do not change selection logic |

### 8. Firebase/Gemini Dependency Boundaries

| Field | Value |
|-------|-------|
| **Risk description** | Firestore repository depends on Gemini; both may fail; fallback to mock essential |
| **Affected files** | `firestore_ai_accountant_repository.dart`, `mock_ai_accountant_repository.dart` |
| **Possible regression** | Gemini key missing; Firestore unavailable; no response; crash on API error |
| **Detection method** | Run without network; verify mock responses work; check error handling |
| **Safe mitigation** | Preserve both implementations; maintain try/catch fallback; test offline mode |

### 9. SQLite/Accounting Data Safety

| Field | Value |
|-------|-------|
| **Risk description** | Execution engine interacts with SQLite; transactions must be atomic; audit must not fail transaction |
| **Affected files** | `proposal_execution_engine.dart`, `database_helper.dart` |
| **Possible regression** | Partial writes; inconsistent state; stock mismatch; missing audit |
| **Detection method** | `ai_accountant_execution_engine_test.dart` (especially rollback test) |
| **Safe mitigation** | Do not modify DBHelper; preserve transaction behavior; test edge cases |

### 10. Web/Mobile Layout Stability

| Field | Value |
|-------|-------|
| **Risk description** | Screen uses `LayoutBuilder` with 1024px breakpoint; IndexedStack preserves state |
| **Affected files** | `ai_workspace_screen.dart`, `ai_accountant_screen.dart` |
| **Possible regression** | Sidebar broken on resize; mobile drawer missing; content overflow |
| **Detection method** | UI resize test; check both desktop/mobile rendering paths |
| **Safe mitigation** | Preserve LayoutBuilder; maintain desktop/mobile branches; test with different screen widths |

### 11. Existing Golden Test Sensitivity

| Field | Value |
|-------|-------|
| **Risk description** | `golden_screenshot_test.dart` may detect visual changes as failures |
| **Affected files** | `test/golden_screenshot_test.dart` |
| **Possible regression** | Layout changes cause false-positive test failures |
| **Detection method** | Run golden tests after any UI change |
| **Safe mitigation** | Do not modify UI in this phase; golden tests are informational only |

### 12. Widget Test Fragility

| Field | Value |
|-------|-------|
| **Risk description** | `widget_test.dart` tests app rendering; changes to any widget may cause failures |
| **Affected files** | `test/widget_test.dart` |
| **Possible regression** | Theme changes; font loading; navigation breaks |
| **Detection method** | `flutter test test/widget_test.dart` |
| **Safe mitigation** | Do not modify widget hierarchy; preserve theme values |

## Risk Summary Table

| Risk # | Area | Severity | Detection Test | Mitigation Strategy |
|--------|------|----------|---------------|-------------------|
| 1 | Screen mixed responsibilities | High | `ai_cfo_beta_release_test.dart` | Gradual extraction |
| 2 | Conversation state coupling | High | `ai_cfo_full_validation_test.dart` | Provider pattern |
| 3 | Proposal state coupling | High | Manual + `ai_accountant_execution_engine_test.dart` | Controller ownership |
| 4 | Intent classification | Medium | `ai_tool_planner_test.dart` | Orchestrator layer |
| 5 | Ledger preview coupling | Medium | Manual | Controller move |
| 6 | Execution call chain | High | `ai_accountant_execution_engine_test.dart` | Preserve contract |
| 7 | Repository factory | Low | Unit test | No changes |
| 8 | Firebase/Gemini boundaries | Medium | Integration test | Fallback preserved |
| 9 | SQLite data safety | Critical | `ai_accountant_execution_engine_test.dart` | Atomic transactions |
| 10 | Layout stability | Medium | `ui_responsive_test.dart` | Preserve branches |
| 11 | Golden tests | Low | `golden_screenshot_test.dart` | No UI changes |
| 12 | Widget tests | Low | `widget_test.dart` | No hierarchy changes |