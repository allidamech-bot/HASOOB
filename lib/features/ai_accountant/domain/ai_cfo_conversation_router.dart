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
      return activeProposal == null
          ? AiCfoConversationIntent.executeProposal
          : AiCfoConversationIntent.approveProposal;
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
              'I can help with business health, cash flow, inventory, profit, receivables, evidence explanation, and guarded proposals. I cannot make unsupported claims or execute vague operations.',
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
        message: _withCompleteness(missingMessage, context),
      );
    }
    return AiCfoConversationResponse(
      type: AiCfoResponseType.answer,
      intent: intent,
      title: title,
      message: _withCompleteness(
        'Here is the grounded CFO view from available evidence only.',
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
          'There is no evidence in the current snapshot to explain.',
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

  String _normalize(String value) => value.toLowerCase().trim();

  bool _containsAny(String value, List<String> terms) {
    return terms.any(value.contains);
  }

  static const _businessHealthTerms = [
    'business health',
    'business doing',
    'financial overview',
    'how is the business',
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
    'ظ„ظٹط´ ظ‚ظ„طھ',
    'ط§ظ„ط¯ظ„ظٹظ„',
    'ليش قلت',
    'الدليل',
  ];
}
