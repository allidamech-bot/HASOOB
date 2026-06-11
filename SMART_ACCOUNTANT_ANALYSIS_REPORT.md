# 📊 HASOOB Smart Accountant Discovery & Reconstruction Report

---

## 1. Executive Summary

**Smart Accountant Status: 🟡 Partially Implemented**

HASOOB contains two distinct AI-powered financial modules:
- **Smart Financial Advisor (SmartCalculatorScreen)** - Fully implemented, local AI module
- **AI Accountant (AiAccountantScreen)** - Partially implemented, intended for Firestore/Gemini integration

The AI Accountant module exists in code but is **incomplete** - it's disconnected from real financial data and only provides pricing simulations with mock data. The actual production implementation relies on `MockAiAccountantRepository` when testing mode is enabled.

---

## 2. System Architecture Map

```
┌─────────────────────────────────────────────────────────────────┐
│                        PRESENTATION LAYER                        │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────┐ │
│  │ SmartCalculator  │  │   AiAccountant   │  │   Reports    │ │
│  │   Screen         │  │   Screen         │  │   Screen     │ │
│  └────────┬─────────┘  └────────┬─────────┘  └──────┬───────┘ │
│           │                     │                    │         │
├───────────┼───────────────────────┼────────────────────┼─────────┤
│           │                     │                    │         │
│  ┌────────▼─────────┐  ┌────────▼──────────┐  ┌────▼────────┐  │
│  │ SmartCalculator  │  │ FirestoreAiAcnt   │  │ ReportService│  │
│  │ Service          │  │ Repository        │  │              │  │
│  └────────┬─────────┘  └────────┬──────────┘  └──────┬──────┘  │
│           │                     │                    │        │
├───────────┼───────────────────────┼────────────────────┼─────────┤
│           │                     │                    │         │
│  ┌────────▼─────────┐  ┌────────▼──────────┐  ┌────▼────────┐  │
│  │ SmartIntentParser│  │ AiAccountantRepo  │  │ DBHelper      │  │
│  │ SmartCalcEngine  │  │ Factory           │  │ (SQLite)      │  │
│  └────────┬─────────┘  └────────┬──────────┘  └──────┬──────┘  │
│           │                     │                    │        │
├───────────┼───────────────────────┼────────────────────┼─────────┤
│           │                     │                    │         │
│  ┌────────▼─────────┐  ┌────────▼──────────┐  ┌────▼────────┐  │
│  │  Product/        │  │  Firebase         │  │  SQLite       │  │
│  │  Customer/       │  │  Firestore        │  │  sqflite      │  │
│  │  Invoice Repos   │  │  google_generative│  │  sqflite_ffi   │  │
│  │                  │  │  _ai              │  │  sqflite_web   │  │
│  └──────────────────┘  └───────────────────┘  └───────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

**Data Flow:**
- Local SQLite DB → Repositories → Services → UI Layer
- Firebase Firestore integration for cloud sync
- Gemini AI API for production AI responses (when configured)

---

## 3. AI Accountant Status

| Component | Status | Evidence |
|-----------|--------|----------|
| Repository Interface | ✅ Exists | `ai_accountant_repository.dart` defines 3 methods |
| Firestore Implementation | 🟡 Partial | Integrates with Gemini but uses mock fallbacks |
| Mock Implementation | ✅ Exists | `mock_ai_accountant_repository.dart` |
| UI Screen | ✅ Exists | `ai_accountant_screen.dart` - 613 lines |
| Data Model | ✅ Exists | `ai_proposal_model.dart` |
| Navigation | ✅ Integrated | `main_navigation_screen.dart:132-138` |
| **Real Financial Data Connection** | ❌ **Missing** | No integration with invoices/expenses/customers |

---

## 4. Technical Findings

### 4.1 Relevant Files

| File | Purpose | Lines |
|------|---------|-------|
| `lib/features/ai_accountant/domain/repositories/ai_accountant_repository.dart` | Abstract repository | 13 |
| `lib/features/ai_accountant/data/repositories/firestore_ai_accountant_repository.dart` | Firestore + Gemini implementation | 240 |
| `lib/features/ai_accountant/data/repositories/mock_ai_accountant_repository.dart` | Mock for testing | 49 |
| `lib/features/ai_accountant/presentation/screens/ai_accountant_screen.dart` | UI screen | 613 |
| `lib/features/ai_accountant/data/models/ai_proposal_model.dart` | Data model | 79 |

### 4.2 Services Used

- **Firebase**: `firebase_core`, `cloud_firestore`, `firebase_auth`
- **AI**: `google_generative_ai` (Gemini 1.5-flash)
- **Database**: `sqflite` with FFI for desktop, web variants
- **State**: `provider` package

### 4.3 AI-Related Logic

**System Prompt (from `firestore_ai_accountant_repository.dart:12-56`):**
- Arabic/English natural language parsing
- Intent classification: purchase, pricing_simulation, calculateTax
- Container logistics calculations (33.2 CBM capacity)
- Landed cost calculations using `LogisticsMathEngine`

**Supported Action Types:**
```dart
'purchase' | 'sale' | 'pricing_simulation' | 'calculateTax' | 'unknown'
```

### 4.4 Financial Modules

| Module | Entity | Status |
|--------|--------|--------|
| Products | `product_model.dart`, `product_repository.dart` | ✅ Complete |
| Customers | `customer_model.dart`, `customer_repository.dart` | ✅ Complete |
| Invoices | `invoice_model.dart`, `invoice_repository.dart` | ✅ Complete |
| Quotations | `quotation_model.dart`, `quotation_repository.dart` | ✅ Complete |
| Expenses | Via `SmartAssistantIntent.createExpenseDraft` | ⚠️ Draft support only |
| Trial Balance | `accounting/trial_balance_screen.dart` | ✅ Complete |

### 4.5 Strengths

1. **Clean architecture separation** - Domain/Repository patterns
2. **Dual AI paths** - Local mock + cloud Gemini integration
3. **Logistics math engine** - Production-ready calculations
4. **Chat-based UI** - Modern conversational interface
5. **Multi-language support** - Arabic/English with RTL support
6. **Ledger visualization** - Real-time spreadsheet updates

### 4.6 Weaknesses

1. **No real-time financial data retrieval** - AI doesn't query invoices/expenses
2. **Missing tool-calling layer** - No `get_income()`, `get_expenses()` tools
3. **No chat history persistence** - Only mock pricing simulations
4. **One-way data flow** - Can create proposals but not retrieve historical data
5. **No balance sheet capability** - Missing financial summary tools

---

## 5. Proposed Full Design

### 5.1 System Prompt for AI Accountant

```dart
static const String _systemInstruction = '''
You are the elite AI Accountant for HASOOB. Your mandate:
1. Analyze financial queries and retrieve REAL data using tools
2. Never hallucinate - always verify against system data
3. Respond in Arabic for Arabic queries, English for English queries
4. Use tools: get_income(), get_expenses(), get_balance_sheet(), create_invoice(), add_expense()
5. Return ONLY valid JSON matching contract
''';
```

### 5.2 Tools Layer Specification

| Tool | Signature | Description |
|------|-----------|-------------|
| `get_income()` | `Future<List<Map>> getIncome({DateTime? from, DateTime? to})` | Returns sales/income transactions |
| `get_expenses()` | `Future<List<Map>> getExpenses({DateTime? from, DateTime? to})` | Returns expense records |
| `create_invoice()` | `Future<String> createInvoice(Map<String, dynamic> data)` | Creates new invoice draft |
| `add_expense()` | `Future<String> addExpense(Map<String, dynamic> data)` | Creates new expense record |
| `get_balance_sheet()` | `Future<Map<String, double>> getBalanceSheet()` | Returns current financial position |
| `financial_summary()` | `Future<Map<String, dynamic>> getFinancialSummary()` | High-level KPI summary |

### 5.3 Data Layer Architecture

```
┌──────────────────────────────────────────────┐
│           Smart Accountant Layer             │
│  ┌───────────────────┐ ┌─────────────────┐ │
│  │ AiAccountantBloc  │ │ AiChatProvider  │ │
│  └─────────┬─────────┘ └────────┬──────────┘ │
├────────────┼─────────────────────┼────────────┤
│            │                     │            │
│  ┌─────────▼─────────┐ ┌────────▼──────────┐ │
│  │ AiAccountantRepo  │ │ ToolCallAdapter   │ │
│  └─────────┬─────────┘ └────────┬──────────┘ │
├────────────┼─────────────────────┼────────────┤
│            │                     │            │
│  ┌─────────▼─────────────────────▼──────────┐ │
│  │         Repository Layer                  │ │
│  │  (Invoice, Product, Customer, Expense)   │ │
│  └─────────┬─────────────────────┬──────────┘ │
├────────────┼─────────────────────┼────────────┤
│            │                     │            │
│  ┌─────────▼─────────────────────▼──────────┐ │
│  │         Local SQLite DB                  │ │
│  │  (sqflite) + Cloud Sync                 │ │
│  └──────────────────────────────────────────┘ │
└────────────────────────────────────────────────┘
```

### 5.4 Implementation Requirements

```yaml
# Required additions to pubspec.yaml
dependencies:
  ai_tools: # Custom package for tool-calling
  freezed_annotation: ^2.4.0
  json_annotation: ^4.9.0

dev_dependencies:
  build_runner: ^2.4.0
  freezed: ^2.4.0
```

---

## 6. Implementation Plan

### Phase 1: Tool Layer (Week 1)
1. Create `lib/features/ai_accountant/data/tools/financial_tools.dart`
2. Implement `get_income`, `get_expenses`, `get_balance_sheet`
3. Add unit tests for tools

### Phase 2: Repository Enhancement (Week 2)
1. Extend `AiAccountantRepository` with tool-call methods
2. Update `FirestoreAiAccountantRepository` with function calling
3. Connect to `InvoiceRepository`, `ProductRepository`, `CustomerRepository`

### Phase 3: Chat Interface Upgrade (Week 3)
1. Replace single-input with multi-turn chat
2. Add message history state management
3. Implement streaming response UI

### Phase 4: Integration & Testing (Week 4)
1. End-to-end integration tests
2. Gemini function calling validation
3. Performance optimization

---

## 7. Risks & Gaps

| Risk | Severity | Mitigation |
|------|----------|------------|
| API key exposure | High | Use environment variables, never commit keys |
| Gemini costs | Medium | Implement caching, rate limiting |
| Offline capability | High | Fallback to SmartCalculator for offline |
| Data privacy | High | Process locally when possible |
| SQLite async issues | Low | Already handled via existing patterns |
| Missing expense module | Medium | Expense records exist but no dedicated screen |

---

## Next Implementation Step

**Immediate Action: Create `financial_tools.dart`** in the AI Accountant data layer to provide real data access for the AI Assistant.

```bash
# File to create:
lib/features/ai_accountant/data/tools/financial_tools.dart
```

This will bridge the gap between AI intent parsing and actual financial data operations.