# HASOOB Command360 Structural Roadmap

## Track A — Foundation

### Phase 0 — Command360 Constitution

Documentation-only product rules defining:
- AI personality and behavior standards
- Permission levels and approval flows
- Audit and traceability requirements
- Source-of-truth rules
- Report and proposal standards

Status: COMPLETE

### Phase 1 — Current Architecture Lock

Documentation-only architecture inspection documenting:
- Existing Flutter/Firebase/SQLite foundation
- Current AI repository contract
- Proposal model limitations
- Execution engine capabilities
- UI integration points
- Risks and strengths

Status: COMPLETE

### Phase 2 — Regression Safety Baseline

Add tests/checks before refactoring. Required safety areas:

- unknown action must not execute
- purchase requires valid payload
- sale requires product match
- pricing simulation saves safely
- tool response does not change accounting data
- audit failure does not crash execution
- AI screen still renders
- mock mode still works

## Track B — Core Refactor

### Phase 3 — Business Context Layer

Create:

```text
BusinessContextService
BusinessSnapshot
DailyBusinessSummary
MonthlyBusinessSummary
InventorySnapshot
CustomerRiskSnapshot
CashFlowSnapshot
ReceivablesSnapshot
ExpenseSnapshot
ProductProfitabilitySnapshot
DataQualityStatus
SourceReference
```

Purpose: Real business data must be loaded through structured services, not raw LLM access.

### Phase 4 — Command360 Orchestrator

Create:

```text
Command360Orchestrator
```

Purpose: Move conversation decision logic out of the UI.

Flow:

```
User message
→ classify intent
→ load business context
→ choose response mode
→ create report/advice/proposal
→ return structured response
```

### Phase 5 — Command Response Model

Create:

```text
Command360Response
```

Fields:

```text
id              — Unique response identifier
message         — Human-readable response
responseType    — greeting, chat, analysis, recommendation, report, proposal, error
confidenceScore — 0.0 to 1.0
riskLevel       — low, medium, high, unknown
sources         — List of SourceReference
warnings        — Data quality warnings
report          — Report data (if report type)
proposal        — Proposal data (if proposal type)
suggestedReplies— Follow-up action chips
requiresApproval — Whether user must approve
createdAt       — Timestamp
metadata        — Additional context
```

## Track C — Financial Intelligence

### Phase 6 — Reports Engine

Create:

```text
ReportEngine
ReportRequest
ReportResult
```

Reports to support:

- Daily report
- Weekly report
- Monthly report
- Annual report
- Profit and loss report
- Sales report
- Expense report
- Inventory report
- Customer receivables report
- Cash flow report
- Product profitability report
- Risk report
- Executive summary report

Each report must include:
- Executive summary
- Key numbers
- Period comparisons
- What improved/decline
- Contributing factors
- Risks
- Recommendations
- Data quality warnings

### Phase 7 — Financial Reasoning Engine

Create:

```text
FinancialReasoningEngine
```

Calculations to support:

- Gross profit
- Net profit
- Profit margin
- Cash flow analysis
- Receivables aging
- Expense trends
- Revenue trends
- Product profitability
- Inventory value
- Slow-moving stock identification
- Customer risk assessment
- Expense anomaly detection
- Period comparisons

All reasoning must be based on actual data with source references.

### Phase 8 — Data Quality & Source of Truth

Create:

```text
SourceReference
DataQualityWarning
DataQualityStatus
ConfidenceScore
TraceableMetric
```

Purpose: Every number must be traceable. Missing data must reduce confidence.

Rules:
- Each metric traces to a data source
- Incomplete data reduces confidence score
- Data quality warnings must be explicit
- Source references must be queryable

## Track D — Governed Execution

### Phase 9 — Proposal Model v2

Create:

```text
CommandProposalModel
```

Fields:

```text
proposalId        — UUID identifier
proposalType      — purchase, sale, pricing, expense, adjustment, etc.
title             — Clear action description
reason            — Why this action is suggested
beforeState       — Current values snapshot
afterState        — Projected values snapshot
financialImpact   — Profit, cash, obligation changes
operationalImpact — What changes operationally
riskLevel         — low, medium, high
confidenceScore   — How certain the AI is
sourceReferences  — Where data originated
requiresApproval  — Approval level needed
approvalStatus    — draft, pendingApproval, approved, rejected, expired, executed, failed, cancelled
createdAt         — Timestamp
createdBy         — User or AI action
auditMetadata     — Linkage to audit events
```

### Phase 10 — Approval Engine

Create:

```text
ApprovalEngine
ExecutionPolicy
RiskClassifier
```

Approval states:

```text
draft              — Initial state
pendingApproval    — Waiting for owner approval
approved           — Owner approved, ready to execute
rejected           — Owner rejected
expired            — Approval window closed
executed           — Successfully executed
failed             — Execution failed
cancelled          — Cancelled via user request
```

Approval policies:
- High-risk actions may require explicit written confirmation
- Pricing changes may auto-expire after period
- Multi-step workflows maintain approval context

### Phase 11 — Execution Engine Hardening

Extend guarded execution gradually for:

- Create expense
- Update expense
- Create customer
- Update customer
- Edit invoice
- Inventory adjustment
- Save report
- Create task/reminder
- Register uploaded invoice
- Correct detected data issue

Each new action type must:
- Define safety guards
- Require explicit approval
- Log complete audit trail
- Provide before/after state comparison

## Track E — Intelligence Expansion

### Phase 12 — Business Memory Engine

Create:

```text
BusinessMemoryEngine
DecisionJournal
BusinessPreferenceMemory
RiskPatternMemory
FollowUpMemory
```

Memory focus:
- Business decisions, not casual chat
- Decision outcomes and lessons
- Risk patterns and avoidance
- Follow-up items from discussions

Memory must:
- Be queryable for future context
- Link to source conversations
- Retain across sessions
- Support preference learning

### Phase 13 — Proactive CFO Briefing

The AI opens with useful business insights:

- Sales status (trend, comparison)
- Profit status (margin, pressure points)
- Cash flow status (working capital)
- Receivables (aging, collection needs)
- Inventory warnings (low stock, slow-moving)
- Customer risks (overdue, large exposure)
- Product margin issues

Briefings must:
- Be data-driven
- Include confidence scores
- Reference specific data sources
- Suggest follow-up actions

### Phase 14 — Owner Challenge Mode

AI must challenge risky decisions professionally.

Trigger conditions:
- Risk level would increase significantly
- Confidence below threshold
- Data quality insufficient
- Financial impact crosses boundaries

Response format:

```
I do not recommend [action] because [reason].

Impact analysis:
- Risk: [specific risk]
- Financial: [projected impact]

Safer alternatives:
1. [Option] — [Impact]
2. [Option] — [Impact]
3. [Option] — [Impact]
```

### Phase 15 — Decision Simulator

Support questions like:

- Should I buy this shipment?
- Should I hire a new employee?
- Should I increase prices?
- Should I give this customer credit?
- Should I open a new branch?
- Should I import this product?

Simulator must:
- Load relevant business context
- Present multiple scenarios
- Show financial projections
- Assess risks clearly
- Recommend based on data

## Track F — Documents & Workflows

### Phase 16 — File & Image Intelligence

Create:

```text
DocumentIngestionService
InvoiceExtractionService
DocumentReviewProposal
DocumentLinkingService
```

Flow:

```
Upload
→ Extract
→ Identify type
→ Compare with existing data
→ Detect missing fields
→ Detect duplicates
→ Recommend action
→ Create proposal
→ User approves
→ Execute
→ Audit
```

Document intelligence must:
- Extract real data from invoices
- Identify potential duplicates
- Flag missing required fields
- Propose correct accounting treatment

### Phase 17 — Monthly & Annual Close Workflow

Support:

```text
Start monthly close
Start annual close
Prepare year-end closing
```

Workflow steps:

- Missing invoices identification
- Unpaid invoices review
- Uncategorized expenses
- Inventory movements
- Tax/VAT review
- Duplicate checks
- Anomalies detection
- Close report generation
- Proposed corrections
- Final approval

### Phase 18 — Smart Inventory Count

Support:

```text
Start annual inventory count
Start inventory audit
Start stock count for this category
```

Workflow:

- Freeze count date
- Extract inventory snapshot
- Generate count sheets
- Accept physical count entry
- Compare physical vs system quantity
- Calculate differences
- Propose adjustments
- Execute after approval
- Audit the count

## Track G — Premium Experience

### Phase 19 — Command360 Workspace UI

Target structure:

```
Command360Workspace
  ├── CommandChatPanel
  ├── BusinessBriefingPanel
  ├── ProposalReviewPanel
  ├── ReportPreviewPanel
  ├── AuditTimelinePanel
  └── ContextDrawer
```

Approach:
- Do not rewrite entire screen at once
- Extract components gradually
- Preserve existing behavior during extraction
- Use workspace controller for shared state

### Phase 20 — Executive Web Workspace

Build dedicated sections:

- AI Command Chat
- Executive Dashboard
- Report Center
- Approval Center
- Document Center
- Audit Log
- Inventory Count Workspace
- Monthly Close Workspace
- Annual Close Workspace
- Decision Simulator
- File Upload Review
- Settings and Permissions

Web-first design considerations:
- Responsive layouts
- Keyboard shortcuts
- Multi-user awareness
- Real-time updates

### Phase 21 — Multi-User Roles & Permissions

Roles:

- Owner — Full access
- Admin — Business management, no owner-only actions
- Accountant — Financial operations only
- Sales Employee — Sales/customer focused
- Inventory Manager — Stock/inventory focused
- Viewer/Auditor — Read-only with audit access

AI must respect:
- Role-based query filtering
- Role-based proposal generation
- Role-based execution permissions
- Role-based audit visibility

### Phase 22 — Voice CFO

Add later:

- Voice input for commands
- Voice replies for briefings
- Voice reports playback
- Voice discussion flow
- Voice-triggered proposals
- Confirmation before execution
- Session summary generation

Voice must:
- Not bypass approval requirements
- Require explicit confirmation for actions
- Support multi-language recognition
- Record voice intent for audit

---

## Readiness Checklist

Each phase prepares for the next by:

1. Preserving existing working paths
2. Adding structured abstractions
3. Maintaining test coverage
4. Ensuring audit traceability
5. Respecting permission levels
6. Documenting behavior changes