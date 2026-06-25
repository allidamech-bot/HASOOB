import '../data/models/ai_proposal_model.dart';
import 'ai_cfo_context_snapshot.dart';
import 'ai_cfo_conversation_intent.dart';
import 'ai_cfo_conversation_response.dart';
import 'ai_cfo_evidence.dart';

class AiCfoConversationRouter {
  const AiCfoConversationRouter();

  AiCfoConversationIntent classify(
    String input, {
    AiProposalModel? activeProposal,
    bool hasApprovedProposal = false,
  }) {
    final normalized = _normalize(input);
    if (normalized.isEmpty) return AiCfoConversationIntent.unsupported;

    if (_containsAny(normalized, _deferTerms)) {
      return AiCfoConversationIntent.deferProposal;
    }
    if (_containsAny(normalized, _approvalTerms)) {
      return AiCfoConversationIntent.approveProposal;
    }
    if (_containsAny(normalized, _executionTerms)) {
      return AiCfoConversationIntent.executeProposal;
    }
    if (_containsAny(normalized, _proposalTerms)) {
      return AiCfoConversationIntent.createProposal;
    }
    if (_containsAny(normalized, _evidenceTerms)) {
      return AiCfoConversationIntent.explainEvidence;
    }
    if (_containsAny(normalized, _cashflowTerms)) {
      return AiCfoConversationIntent.cashflowReview;
    }
    if (_containsAny(normalized, _inventoryTerms)) {
      return AiCfoConversationIntent.inventoryReview;
    }
    if (_containsAny(normalized, _profitTerms)) {
      return AiCfoConversationIntent.profitReview;
    }
    if (_containsAny(normalized, _receivablesTerms)) {
      return AiCfoConversationIntent.receivablesReview;
    }
    if (_containsAny(normalized, _businessHealthTerms)) {
      return AiCfoConversationIntent.businessHealth;
    }
    return AiCfoConversationIntent.unsupported;
  }

  AiCfoConversationResponse respond(
    String input, {
    required AiCfoContextSnapshot context,
    AiProposalModel? activeProposal,
    bool hasApprovedProposal = false,
  }) {
    final intent = classify(
      input,
      activeProposal: activeProposal,
      hasApprovedProposal: hasApprovedProposal,
    );
    return responseForIntent(
      intent,
      context: context,
      activeProposal: activeProposal,
      hasApprovedProposal: hasApprovedProposal,
    );
  }

  AiCfoConversationResponse responseForIntent(
    AiCfoConversationIntent intent, {
    required AiCfoContextSnapshot context,
    AiProposalModel? activeProposal,
    bool hasApprovedProposal = false,
  }) {
    return switch (intent) {
      AiCfoConversationIntent.businessHealth => _evidenceAnswer(
          intent: intent,
          title: 'Business health review',
          area: AiCfoContextArea.businessHealth,
          context: context,
          missingMessage:
              'I need real ledger, sales, inventory, invoice, or receivables data before I can assess business health.',
        ),
      AiCfoConversationIntent.cashflowReview => _evidenceAnswer(
          intent: intent,
          title: 'Cash-flow review',
          area: AiCfoContextArea.cash,
          context: context,
          missingMessage:
              'I need cash, invoice collection, or ledger evidence before I can review cash flow.',
        ),
      AiCfoConversationIntent.inventoryReview => _evidenceAnswer(
          intent: intent,
          title: 'Inventory review',
          area: AiCfoContextArea.inventory,
          context: context,
          missingMessage:
              'I need product or stock records before I can make an inventory claim.',
        ),
      AiCfoConversationIntent.profitReview => _evidenceAnswer(
          intent: intent,
          title: 'Profit review',
          area: AiCfoContextArea.sales,
          context: context,
          missingMessage:
              'I need sales and expense evidence before I can review profit.',
        ),
      AiCfoConversationIntent.receivablesReview => _evidenceAnswer(
          intent: intent,
          title: 'Receivables review',
          area: AiCfoContextArea.receivables,
          context: context,
          missingMessage:
              'I need customer balances or invoice records before I can review receivables.',
        ),
      AiCfoConversationIntent.explainEvidence => _explainEvidence(context),
      AiCfoConversationIntent.createProposal => const AiCfoConversationResponse(
          type: AiCfoResponseType.proposal,
          intent: AiCfoConversationIntent.createProposal,
          title: 'Proposal requires review',
          message:
              'Any accounting action must be prepared as a reviewable proposal before execution.',
          requiresApproval: true,
          canExecute: false,
        ),
      AiCfoConversationIntent.approveProposal => AiCfoConversationResponse(
          type: AiCfoResponseType.proposal,
          intent: AiCfoConversationIntent.approveProposal,
          title: 'Approval required',
          message: activeProposal == null
              ? 'There is no active proposal to approve.'
              : 'Review the active proposal and approve it explicitly before execution.',
          proposal: activeProposal,
          requiresApproval: true,
          isBlocked: activeProposal == null,
          blockedReason: activeProposal == null ? 'No active proposal.' : null,
          canExecute: false,
        ),
      AiCfoConversationIntent.executeProposal => _executionGuard(
          activeProposal: activeProposal,
          hasApprovedProposal: hasApprovedProposal,
        ),
      AiCfoConversationIntent.deferProposal => AiCfoConversationResponse(
          type: activeProposal == null
              ? AiCfoResponseType.blocked
              : AiCfoResponseType.followUp,
          intent: AiCfoConversationIntent.deferProposal,
          title: 'Defer proposal',
          message: activeProposal == null
              ? 'There is no active proposal to defer.'
              : 'This can stay as session-only follow-up. Nothing is persisted by this router.',
          proposal: activeProposal,
          isBlocked: activeProposal == null,
          blockedReason: activeProposal == null ? 'No active proposal.' : null,
        ),
      AiCfoConversationIntent.unsupported => const AiCfoConversationResponse(
          type: AiCfoResponseType.unsupported,
          intent: AiCfoConversationIntent.unsupported,
          title: 'Unsupported CFO request',
          message:
              'I can help with business health, cash flow, inventory, profit, receivables, evidence explanation, and guarded proposals. Ask for one area at a time, for example "review inventory risk" or "what data is missing for cash flow?". I cannot make unsupported claims or execute vague operations.',
          isBlocked: true,
          blockedReason: 'Unsupported request.',
          canExecute: false,
        ),
    };
  }

  AiCfoConversationResponse _evidenceAnswer({
    required AiCfoConversationIntent intent,
    required String title,
    required AiCfoContextArea area,
    required AiCfoContextSnapshot context,
    required String missingMessage,
  }) {
    final evidence = context.evidenceFor(area);
    if (evidence.isEmpty) {
      return AiCfoConversationResponse(
        type: AiCfoResponseType.clarificationNeeded,
        intent: intent,
        title: title,
        message: _withCompleteness(
          '$missingMessage ${_lowDataGuidance(area)}',
          context,
        ),
      );
    }
    return AiCfoConversationResponse(
      type: AiCfoResponseType.answer,
      intent: intent,
      title: title,
      message: _withCompleteness(
        'Here is the grounded CFO view from available evidence only. ${_nextQuestionGuidance(area)}',
        context,
      ),
      evidence: evidence,
      risks: _weakEvidenceRisks(evidence, context),
    );
  }

  AiCfoConversationResponse _explainEvidence(AiCfoContextSnapshot context) {
    final evidence = context.evidenceFor(AiCfoContextArea.businessHealth);
    if (evidence.isEmpty) {
      return AiCfoConversationResponse(
        type: AiCfoResponseType.clarificationNeeded,
        intent: AiCfoConversationIntent.explainEvidence,
        title: 'Evidence explanation',
        message: _withCompleteness(
          'There is no evidence in the current snapshot to explain. Add products, customers, invoices, sales, payments, or expenses first; then ask me to explain which records support the answer.',
          context,
        ),
      );
    }
    return AiCfoConversationResponse(
      type: AiCfoResponseType.answer,
      intent: AiCfoConversationIntent.explainEvidence,
      title: 'Evidence explanation',
      message: 'I can explain only the evidence currently attached.',
      evidence: evidence,
      risks: _weakEvidenceRisks(evidence, context),
    );
  }

  AiCfoConversationResponse _executionGuard({
    required AiProposalModel? activeProposal,
    required bool hasApprovedProposal,
  }) {
    if (activeProposal == null) {
      return const AiCfoConversationResponse(
        type: AiCfoResponseType.blocked,
        intent: AiCfoConversationIntent.executeProposal,
        title: 'Execution blocked',
        message:
            'Execution requires an active proposal first. No financial record was changed.',
        isBlocked: true,
        blockedReason: 'No active proposal.',
        canExecute: false,
      );
    }
    if (!hasApprovedProposal) {
      return AiCfoConversationResponse(
        type: AiCfoResponseType.blocked,
        intent: AiCfoConversationIntent.executeProposal,
        title: 'Approval required',
        message:
            'Execution is blocked until the active proposal is explicitly approved.',
        proposal: activeProposal,
        requiresApproval: true,
        isBlocked: true,
        blockedReason: 'Proposal has not been explicitly approved.',
        canExecute: false,
      );
    }
    return AiCfoConversationResponse(
      type: AiCfoResponseType.executionResult,
      intent: AiCfoConversationIntent.executeProposal,
      title: 'Ready for guarded execution',
      message:
          'The proposal may be handed to the existing guarded execution engine.',
      proposal: activeProposal,
      requiresApproval: true,
      canExecute: true,
    );
  }

  List<String> _weakEvidenceRisks(
    List<AiCfoEvidence> evidence,
    AiCfoContextSnapshot context,
  ) {
    return [
      if (evidence
          .any((item) => item.confidence == AiCfoEvidenceConfidence.low))
        'Some evidence is low confidence.',
      ...context.dataCompletenessNotes,
    ];
  }

  String _withCompleteness(String message, AiCfoContextSnapshot context) {
    if (context.dataCompletenessNotes.isEmpty) return message;
    return '$message Data completeness: ${context.dataCompletenessNotes.join(' ')}';
  }

  String _lowDataGuidance(AiCfoContextArea area) {
    return switch (area) {
      AiCfoContextArea.cash =>
        'Add issued invoices, recorded payments, expenses, or ledger entries next. After that you can ask "what cash risk should I watch this week?".',
      AiCfoContextArea.sales =>
        'Record sales or issue invoices with product quantities and prices next. After that you can ask "which products are driving profit?".',
      AiCfoContextArea.inventory =>
        'Add products with stock, cost, selling price, and low-stock thresholds next. After that you can ask "which stock needs attention?".',
      AiCfoContextArea.receivables =>
        'Add customers and invoices with paid or unpaid balances next. After that you can ask "which customers need collection follow-up?".',
      AiCfoContextArea.businessHealth =>
        'Add products, customers, invoices, sales, payments, and expenses next. After that you can ask "what is the weakest part of the business today?".',
      AiCfoContextArea.ledger ||
      AiCfoContextArea.recentSales =>
        'Add real ledger or sales records next, then ask me to explain the evidence behind the latest activity.',
    };
  }

  String _nextQuestionGuidance(AiCfoContextArea area) {
    return switch (area) {
      AiCfoContextArea.cash =>
        'You can next ask about collection timing, expense pressure, or whether cash evidence is still incomplete.',
      AiCfoContextArea.sales =>
        'You can next ask for product margin, weak sales evidence, or what data would make the profit view stronger.',
      AiCfoContextArea.inventory =>
        'You can next ask about low-stock risk, reorder priorities, or slow-moving inventory evidence.',
      AiCfoContextArea.receivables =>
        'You can next ask which balances need follow-up or what customer data is missing.',
      AiCfoContextArea.businessHealth =>
        'You can next ask me to zoom into cash flow, inventory, profit, or receivables.',
      AiCfoContextArea.ledger ||
      AiCfoContextArea.recentSales =>
        'You can next ask me to explain the evidence or compare recent activity.',
    };
  }

  String _normalize(String value) => value.toLowerCase().trim();

  bool _containsAny(String value, List<String> terms) {
    return terms.any(value.contains);
  }

  static const _businessHealthTerms = [
    'business health',
    'business doing',
    'financial overview',
    'how is the business',
    'how is my business',
    'what should i focus on',
    'what should i do today',
    'what should i do next',
    'focus today',
    'first risk',
    'what are my risks',
    'risk should i check',
    'next best action',
    'ظƒظٹظپ ظˆط¶ط¹',
    'ظˆط¶ط¹ ط§ظ„ط´ط±ظƒط©',
    'كيف وضع',
    'وضع الشركة',
    'صحة الشركة',
  ];

  static const _cashflowTerms = [
    'cash',
    'cashflow',
    'cash flow',
    'liquidity',
    'ظƒط§ط´',
    'ط³ظٹظˆظ„ط©',
    'ظ†ظ‚ط¯',
    'كاش',
    'سيولة',
    'نقد',
  ];

  static const _inventoryTerms = [
    'inventory',
    'stock',
    'products',
    'ظ…ط®ط²ظˆظ†',
    'ظ…ظ†طھط¬ط§طھ',
    'مخزون',
    'منتجات',
  ];

  static const _profitTerms = [
    'profit',
    'profitability',
    'margin',
    'ط±ط¨ط­',
    'ظ‡ط§ظ…ط´',
    'ربح',
    'هامش',
  ];

  static const _receivablesTerms = [
    'receivable',
    'receivables',
    'customers',
    'customer balance',
    'overdue',
    'ط°ظ…ظ…',
    'ط¹ظ…ظ„ط§ط،',
    'ظ…طھط£ط®ط±',
    'ذمم',
    'عملاء',
    'متأخر',
  ];

  static const _proposalTerms = [
    'prepare',
    'proposal',
    'purchase',
    'sale',
    'create proposal',
    'ط¬ظ‡ط²',
    'ظ…ظ‚طھط±ط­',
    'جهز',
    'مقترح',
  ];

  static const _executionTerms = [
    'execute',
    'commit',
    'save',
    'ظ†ظپط°',
    'نفذ',
  ];

  static const _approvalTerms = [
    'approve',
    'confirm',
    'ظ…ظˆط§ظپظ‚',
    'موافق',
  ];

  static const _deferTerms = [
    'defer',
    'later',
    'not now',
    'ط¨ط¹ط¯ظٹظ†',
    'ظ„ظٹط³ ط§ظ„ط¢ظ†',
    'بعدين',
    'ليس الآن',
  ];

  static const _evidenceTerms = [
    'evidence',
    'why did you say',
    'explain evidence',
    'what data is missing',
    'data is missing',
    'missing data',
    'what is missing',
    'before i make a decision',
    'before i decide',
    'ظ„ظٹط´ ظ‚ظ„طھ',
    'ط§ظ„ط¯ظ„ظٹظ„',
    'ليش قلت',
    'الدليل',
  ];
}
