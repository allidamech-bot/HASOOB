# AI Accountant Conversation Phase A

This document locks the next AI Accountant direction for HASOOB.

## Goal

Move the AI Accountant from a command-only proposal screen toward a natural conversational financial advisor experience.

The user should be able to discuss, ask, compare, object, and refine decisions before any financial mutation is executed.

## Product Principle

The AI Accountant is not only a parser for commands. It should behave as a professional accounting and business advisor:

- Ask follow-up questions.
- Suggest practical options.
- Compare conservative, balanced, and aggressive scenarios.
- Explain trade-offs.
- Convert a finished discussion into a proposal only when enough information exists.
- Execute only after explicit review and confirmation.

## Execution Safety

The existing ProposalExecutionEngine remains the final action layer.

Do not execute database mutations from vague conversation.

Safe flow:

```text
Natural discussion
→ assistant recommendation/question
→ optional scenario comparison
→ proposal card when data is complete
→ explicit user confirmation
→ ProposalExecutionEngine
→ execution result card
```

## Phase A Scope

Phase A should be UI/state-layer focused:

- Chat timeline.
- User message bubbles.
- Assistant message bubbles.
- Proposal cards inside the timeline.
- Execution result cards inside the timeline.
- Suggested reply chips.
- Composer that supports natural text, not only direct commands.
- Keep current ledger/context preview.

## Do Not Change Yet

- Do not change accounting mutation logic.
- Do not change database schema.
- Do not persist chat history yet.
- Do not weaken chart-of-accounts guards.
- Do not bypass product/customer confirmation.

## Recommended Message Model

```dart
enum AiChatRole {
  user,
  assistant,
}

enum AiChatMessageType {
  normal,
  recommendation,
  question,
  scenarioComparison,
  proposal,
  confirmation,
  executionResult,
  error,
}

class AiChatMessage {
  final String id;
  final AiChatRole role;
  final AiChatMessageType type;
  final String text;
  final DateTime timestamp;
  final AiProposalModel? proposal;
  final ProposalExecutionResult? executionResult;
  final List<String> suggestedReplies;

  const AiChatMessage({
    required this.id,
    required this.role,
    required this.type,
    required this.text,
    required this.timestamp,
    this.proposal,
    this.executionResult,
    this.suggestedReplies = const [],
  });
}
```

## Advisor Examples

### Export discussion

User:

```text
بدي أصدّر شوكولاتة للسعودية، شو بتنصحني؟
```

Assistant:

```text
خلينا نبني القرار خطوة بخطوة. أحتاج أعرف تكلفة الكرتون، تكلفة الشحن، الجمارك، وهل هدفك دخول السوق بسرعة أم هامش أعلى؟
```

### Margin discussion

User:

```text
هل هامش 25% مناسب؟
```

Assistant:

```text
25% قد يكون مناسبًا إذا الطلب مستقر والمنافسة ليست قوية. للدخول الأول أقترح مقارنة 3 سيناريوهات: محافظ، متوازن، وهجومي.
```

### Execution guard

User:

```text
نفذ
```

Assistant when no active proposal exists:

```text
أحتاج مقترحًا واضحًا قبل التنفيذ. هل تريد تجهيز عملية شراء، بيع، أو دراسة تسعير؟
```

## Desktop Layout Recommendation

- Chat/advisor area should be primary.
- Ledger/context panel should stay visible but secondary.
- Suggested ratio: 60% chat, 40% context.

## Mobile Layout Recommendation

- Chat first.
- Ledger/context below or collapsible.

## Acceptance Criteria

- User can continue conversation after a result.
- Advice questions do not trigger database mutation.
- Clear transaction commands still create proposals.
- Proposal execution still uses the existing execution engine.
- Result cards appear in the conversation.
- Missing context leads to a clarification question, not execution.
