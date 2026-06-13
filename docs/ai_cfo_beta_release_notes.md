# HASOOB AI CFO Beta Release Notes

## Scope

The AI Accountant is ready for internal beta use as an advisory AI CFO workspace.
It can analyze available business records, produce evidence-backed CFO answers,
and prepare guarded proposals for review.

## Capabilities

- Executive CFO briefings with business health, cash status, risks, opportunities, and decision packs.
- Customer credit intelligence for risky customers, overdue behavior, payment delay, and concentration exposure.
- Import/export shipment analysis with landed cost, margin, break-even point, scenario impacts, and recommendations.
- Long-term CFO memory for evidence-backed customer, cashflow, inventory, recommendation, and shipment patterns.
- Forecasting and scenario-oriented decision support through the existing CFO decision flow.
- Proposal and workflow guardrails for purchase, sale, pricing, and execution-related actions.

## Safety Rules

- AI CFO recommendations are advisory.
- The AI must not directly create invoices, payments, inventory changes, or approvals from conversation alone.
- Executable actions must remain routed through the existing proposal, workflow, and approval guards.
- Low-confidence answers should ask for missing data instead of inventing facts.

## Current Limitations

- Analysis quality depends on available business data.
- Import/export decisions are strongest when purchase cost, freight, customs, storage, selling price, expected volume, and currency assumptions are provided.
- Customer credit analysis depends on customer records and invoice/payment history.
- Long-term memory stores only evidence-backed items with source, timestamp, confidence, category, and references.
- Beta users should validate recommendations before taking business action.

## Data Needed For Best Results

- Invoices, due dates, payment status, and remaining balances.
- Customer records and outstanding balances.
- Products, stock quantities, low-stock thresholds, purchase costs, and sales behavior.
- Expense records and financial summary data.
- Shipment costs including purchase, freight, customs, storage, currency, selling price, and expected volume.

## Internal Beta Checklist

- Start with business health, top risks, customer risk, shipment pricing, or weekly CFO actions.
- Confirm evidence and confidence are visible before using advice.
- Treat decision packs as review material, not automatic approvals.
- Use guarded proposal flows for execution.
