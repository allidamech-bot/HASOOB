# 🚀 Smart Accountant - Day-by-Day Build Plan

---

## Week 1: Foundation Layer (Days 1-7)

### Day 1-2: Financial Tools Layer
**Target:** `lib/features/ai_accountant/data/tools/financial_tools.dart`

Tasks:
1. Create `FinancialTools` class with static methods
2. Implement `getIncome(businessId, {from, to})`
3. Implement `getExpenses(businessId, {from, to})`
4. Implement `getInvoices(businessId, {status})`
5. Implement `getCustomers(businessId)`
6. Implement `getProducts(businessId)`
7. Unit tests for all tools

```dart
// Example signature
Future<List<Map<String, dynamic>>> getIncome({
  required String businessId,
  DateTime? from,
  DateTime? to,
}) async {
  return DBHelper.getSalesRecords(businessId, from: from, to: to);
}
```

### Day 3: Tool Registry
**Target:** `lib/features/ai_accountant/data/tools/financial_tool_registry.dart`

Tasks:
1. Create `FinancialToolRegistry` with tool descriptions
2. Export tool schemas for Gemini function calling
3. Map tool names to implementations

### Day 4-5: AI Tool Executor
**Target:** `lib/features/ai_accountant/domain/services/ai_tool_executor.dart`

Tasks:
1. Create `AiToolExecutor` class
2. Implement `executeTool(String toolName, Map<String, dynamic> params)`
3. Handle tool discovery via registry
4. Add error handling and validation
5. Return structured `ToolResult`

### Day 6-7: Unit Tests & Integration
**Target:** `test/ai_accountant_tools_test.dart`

Tasks:
1. Test each tool with real SQLite data
2. Test tool executor with mock tools
3. Integration test with existing repositories

---

## Week 2: AI Integration Layer (Days 8-14)

### Day 8-9: Gemini Function Calling Setup
**Target:** Update `firestore_ai_accountant_repository.dart`

Tasks:
1. Define function declarations for tools
2. Modify `parseNaturalLanguage` to use tool-calling loop
3. Add tool response handling
4. Implement multi-turn conversation

### Day 10-11: Proposal Entity
**Target:** `lib/features/ai_accountant/domain/entities/ai_proposal.dart`

Tasks:
1. Extend `AiProposalModel` with execution metadata
2. Add `executionPlan` field
3. Add `status` enum (pending, validated, executed)
4. Add `auditTrail` list

### Day 12-14: Reasoning Engine
**Target:** `lib/features/ai_accountant/domain/services/ai_reasoning_engine.dart`

Tasks:
1. Create `AiReasoningEngine` class
2. Implement tool-calling loop
3. Add conversation state management
4. Create final proposal from AI analysis

---

## Week 3: Execution Layer (Days 15-21)

### Day 15-16: Proposal Execution Engine
**Target:** `lib/features/ai_accountant/domain/services/proposal_execution_engine.dart`

Tasks:
1. Create `ProposalExecutionEngine` class
2. Implement `createTransaction()`
3. Implement `updateInvoice()`
4. Implement `adjustExpense()`

### Day 17-18: Sync Integration
**Target:** `proposal_execution_engine.dart`

Tasks:
1. Add `syncToFirestore()` method
2. Add `updateSQLite()` method
3. Ensure atomic operations

### Day 19-20: Audit System
**Target:** `lib/features/ai_accountant/data/repositories/ai_audit_repository.dart`

Tasks:
1. Create audit table in SQLite
2. Implement `writeAuditLog()`
3. Add audit trail to each execution

### Day 21: Error Handling
Tasks:
1. Add rollback on failed executions
2. Add retry logic
3. Add validation before execution

---

## Week 4: UI & Testing (Days 22-28)

### Day 22-23: Chat Interface
**Target:** `ai_accountant_screen.dart`

Tasks:
1. Convert to multi-turn chat UI
2. Add message bubbles
3. Add typing indicators
4. Add tool result visualization

### Day 24-25: Execution Flow
Tasks:
1. Connect UI to execution engine
2. Add confirmation dialogs
3. Add success/error feedback

### Day 26-27: Full Integration Tests
**Target:** `test/smart_accountant_e2e_test.dart`

Tasks:
1. Test complete flow: user query → tool calls → execution
2. Test Firestore sync
3. Test audit logging

### Day 28: Documentation
Tasks:
1. Update README
2. Add inline documentation
3. Create usage examples

---

## 🔧 Key Files to Create/Modify

| Day | File | Action |
|-----|------|--------|
| 1 | `financial_tools.dart` | Create |
| 3 | `financial_tool_registry.dart` | Create |
| 4 | `ai_tool_executor.dart` | Create |
| 8 | `firestore_ai_accountant_repository.dart` | Modify |
| 10 | `ai_proposal.dart` | Create/Extend |
| 12 | `ai_reasoning_engine.dart` | Create |
| 15 | `proposal_execution_engine.dart` | Create |
| 19 | `ai_audit_repository.dart` | Create |
| 22 | `ai_accountant_screen.dart` | Modify |

---

## ✅ Success Criteria (End of Week 4)

- [ ] AI can query real financial data
- [ ] Tool-calling loop works end-to-end
- [ ] Proposals are executable
- [ ] All actions are audit-logged
- [ ] Firestore sync completes successfully
- [ ] UI shows full conversation history