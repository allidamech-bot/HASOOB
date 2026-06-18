# HASOOB Command360 Current Architecture

## 1. Repository Overview

### Current App Foundation

The HASOOB application is built on:

| Technology | Version/Notes |
|------------|---------------|
| **Flutter** | SDK >=3.1.0 <4.0.0 |
| **Firebase** | Firestore, Auth, Analytics, Core |
| **SQLite** | sqflite with FFI support (desktop/web) |
| **PDF/Printing** | pdf: ^3.11.1, printing: ^5.12.0 |
| **Image Support** | image_picker: ^1.1.2 |
| **AI SDK** | google_generative_ai: ^0.4.7 |
| **State Management** | provider: ^6.1.2 |

The app follows a standard Flutter architecture with:
- Feature-based file organization
- Repository pattern for data access
- ChangeNotifier for service state
- InheritedWidget for cross-component communication

## 2. Main App Bootstrap

### Startup Flow (lib/main.dart)

The application bootstrap follows a deferred-initialization pattern:

1. **Error Handlers** — Global Flutter and Platform error handlers
2. **Theme Controller** — `AppThemeController.load()` with timeout fallback
3. **Locale Controller** — `AppLocaleController.load()` with timeout fallback
4. **Date Formatting** — `initializeDateFormatting()` with timeout
5. **Firebase Bootstrap** — `FirebaseBootstrap.initialize()` with timeout
6. **Providers Setup** — Lazy creation via MultiProvider:
   - `Provider<AuthService>` — Authentication service
   - `Provider<ProductRepository>` — Product data access
   - `ChangeNotifierProvider<SyncManager>` — Sync state management
7. **App Launch** — `HasoobApp` widget with `StartupCoordinator` handling post-frame initialization

### AuthGate

The `AuthGate` (lib/screens/auth/auth_gate.dart) controls navigation based on:
- Firebase configuration status
- User authentication state
- Bootstrap result information

## 3. AI Repository Contract

### lib/features/ai_accountant/domain/repositories/ai_accountant_repository.dart

The `AiAccountantRepository` abstract class defines the contract for AI operations:

```dart
abstract class AiAccountantRepository {
  Future<AiProposalModel> parseNaturalLanguage(String text);
  Future<AiProposalModel> parseInvoiceImage(Uint8List imageBytes, String mimeType);
  Future<bool> executeProposal(AiProposalModel proposal);
  Future<ProposalExecutionResult> executeProposalDetailed(AiProposalModel proposal);
}
```

**Purpose:**
- `parseNaturalLanguage` — Converts user text into a proposal model
- `parseInvoiceImage` — Extracts invoice data from images (OCR)
- `executeProposal` — Executes a proposal (simplified)
- `executeProposalDetailed` — Executes with full result and optional confirmation requirement

## 4. AI Repository Factory

### lib/features/ai_accountant/data/repositories/ai_accountant_repository_factory.dart

The factory provides repository selection based on runtime mode:

```dart
class AiAccountantRepositoryFactory {
  static AiAccountantRepository make() {
    if (AppConfig.isTestingMode) {
      return MockAiAccountantRepository();
    }
    try {
      return FirestoreAiAccountantRepository();
    } catch (_) {
      return MockAiAccountantRepository();
    }
  }
}
```

This enables testing with mock data while using real Firestore in production.

## 5. AI Proposal Model

### lib/features/ai_accountant/data/models/ai_proposal_model.dart

**Current Fields:**

| Field | Type | Purpose |
|-------|------|---------|
| `actionType` | String | 'purchase', 'sale', 'pricing_simulation', 'unknown', 'tool_response' |
| `explanation` | String | Human-readable description of the proposal |
| `confidenceScore` | double | AI confidence in the proposal (0.0-1.0) |
| `inventoryPayload` | Map? | Product/inventory related data |
| `customerPayload` | Map? | Customer related data |
| `financialPayload` | Map? | Financial amounts and payment data |
| `pricingPayload` | Map? | Dynamic pricing simulation data |

**Current Limitations:**

- No proposal ID — Cannot track or reference proposals
- No approval state — Cannot track proposal lifecycle
- No before/after state — Cannot show clear impact
- No explicit risk level — Only implicit via confidence
- No source references — Cannot trace data origins
- No lifecycle tracking — Draft/review/approved/executed states missing
- No audit metadata — No audit linkage in the model itself

## 6. Firestore AI Repository

### lib/features/ai_accountant/data/repositories/firestore_ai_accountant_repository.dart

**Gemini Integration:**
- Uses `gemini-1.5-flash` model
- System instruction requests JSON responses
- Handles function calling for financial tools
- Falls back to mock pricing for Arabic keywords

**Response Contract:**
- Expects JSON matching `AiProposalModel` contract
- Has fallback for `tool_response` action type
- Pricing simulation fallback for import/export keywords

**Current Risks:**

- System instruction is too narrow for Command360 scope
- Mock/fallback behavior may produce non-real business analysis
- Image parsing (`parseInvoiceImage`) is not real document intelligence
- AI output contract lacks strength for complex workflows
- No explicit data quality assessment in response

## 7. AI Tool Executor

### lib/features/ai_accountant/domain/services/ai_tool_executor.dart

**Supported Tools:**

| Tool | Purpose |
|------|---------|
| `getIncome` | Loads income from sales records |
| `getExpenses` | Loads expenses from journal entries |
| `getInvoices` | Loads invoices for business ID |
| `getCustomers` | Loads customers for business ID |
| `getProducts` | Loads products for business ID |
| `getFinancialSummary` | Combined financial snapshot |

All tools require `businessId` from `BusinessContext`.

**Tool Planning:**
- `AiToolPlanner` handles intent classification
- `AiToolPlan` defines tool execution steps
- Safety levels categorized per intent

## 8. Financial Tools

### lib/features/ai_accountant/data/tools/financial_tools.dart

**Current Data Access:**

- Income from sales records via `DBHelper`
- Expenses from journal entries via `DBHelper`
- Invoices from `DBHelper.getInvoicesForBusiness()`
- Customers from `DBHelper.getCustomers()`
- Products from `DBHelper.getProducts()`
- Financial summary combines all above

**Current Limitations:**

- Not yet a full Business Context Layer (no unified service)
- Limited data quality status reporting
- No source references in returned data
- Limited customer risk logic (basic aging)
- Limited inventory intelligence (low stock only)
- Data not yet report-ready structure

## 9. Proposal Execution Engine

### lib/features/ai_accountant/domain/services/proposal_execution_engine.dart

**Supported Action Types:**

| Action | Behavior |
|--------|----------|
| `tool_response` | Logs tool call results to audit |
| `pricing_simulation` | Saves to `ai_pricing_simulations` + audit |
| `purchase` | Executes purchase via `DBHelper.executeAiPurchase()` + audit |
| `sale` | Executes sale via `DBHelper.executeAiSale()` + audit |

**Safety Behavior:**

- Required account guards via `_guardRequiredAccounts()`
- Product match confirmation (`requiresUserConfirmation`)
- Safe failure results with error messages
- Audit logging attempt after execution
- Before/after state captured in result

**Limitations:**

- Approval is not a dedicated independent engine
- Risk classification is limited (implicit via context)
- Proposal lifecycle tracking missing
- More action types needed for full Command360 (expenses, adjustments, inventory)

## 10. AI Accountant Screen

### lib/features/ai_accountant/presentation/screens/ai_accountant_screen.dart

**Current Responsibilities:**

- Chat UI with message bubbles
- Message state management (`_messages` list)
- User input handling and submission
- Conversation orchestrator integration
- Intent classification handling
- Advisory response rendering
- Proposal state management (`_activeProposal`, `_confirmationProposal`)
- Proposal card rendering with approval buttons
- Execution result cards
- Ledger preview with uncommitted entries
- Quick actions chips
- Context summary panel
- Business health score calculation

**Architectural Risk:**

The screen currently contains too much business logic. Future phases should extract:

- `Command360Orchestrator` — Conversation decision logic
- `BusinessContextService` — Business data aggregation
- `ReportEngine` — Structured report generation
- `ProposalReviewPanel` — Dedicated proposal UI
- `CommandChatPanel` — Chat-only UI component
- `AuditTimelinePanel` — Audit event timeline

## 11. Existing Strengths

| Strength | Location |
|----------|----------|
| AI repository abstraction | `ai_accountant_repository.dart` |
| Proposal execution engine | `proposal_execution_engine.dart` |
| Guarded execution flow | `ProposalExecutionEngine` |
| Financial tools | `financial_tools.dart` |
| Tool executor | `ai_tool_executor.dart` |
| Audit log attempts | `FirestoreAiAccountantRepository`, `ProposalExecutionEngine` |
| Proposal card UI | `ai_accountant_screen.dart::_buildProposalCard()` |
| Mock/testing mode | `MockAiAccountantRepository`, `AppConfig.isTestingMode` |
| Flutter/Firebase/SQLite foundation | `pubspec.yaml`, `lib/main.dart` |

## 12. Existing Risks

| Risk | Location |
|------|----------|
| AI logic too concentrated in UI | `ai_accountant_screen.dart` |
| Proposal model too limited | `ai_proposal_model.dart` |
| Financial tools not full business context | `financial_tools.dart` |
| No unified Command360 response model | Missing |
| No dedicated approval engine | `proposal_execution_engine.dart` (limited) |
| No full trust/source reference layer | Missing |
| No real document intelligence | `parseInvoiceImage` placeholder |
| No long-term business memory | `ai_business_memory.dart` (ephemeral) |

## 13. What Must Not Be Broken

The following must remain functional throughout Command360 evolution:

- Existing accounting logic in `ProposalExecutionEngine`
- Existing purchase execution in `_executePurchase()`
- Existing sale execution in `_executeSale()`
- Existing pricing simulation saving in `DBHelper.saveAiPricingSimulation()`
- Existing product match safety in `_guardRequiredAccounts()`
- Existing audit logging attempts
- Existing mock mode operation
- Existing app startup flow
- Existing AI screen rendering

Any refactor must preserve these working paths.