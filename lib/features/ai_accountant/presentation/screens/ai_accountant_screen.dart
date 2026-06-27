import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/app_theme.dart';
import '../../../../data/database/database_helper.dart';
import '../widgets/command360/command360_context_module.dart';
import '../widgets/command360/command360_context_row.dart';
import '../widgets/command360/command360_decision_options.dart';
import '../widgets/command360/command360_executive_tab_button.dart';
import '../widgets/command360/command360_memory_card.dart';
import '../widgets/command360/command360_message_rows.dart';
import '../widgets/command360/command360_quick_action_chip.dart';
import '../widgets/command360/command360_starter_question_chip.dart';
import '../widgets/command360/command360_workflow_card.dart';
import '../widgets/command360/command360_message_expansion.dart';
import '../widgets/command360/command360_detail_line.dart';
import '../../../../core/business/business_context.dart';
import '../../../../core/ui/responsive.dart';
import '../../../../data/repositories/product_repository.dart';
import '../../../../screens/invoice_details_screen.dart';
import '../../../../screens/product_details_screen.dart';
import '../../../../screens/settings_screen.dart';
import '../../data/models/ai_proposal_model.dart';
import '../../data/repositories/ai_accountant_repository_factory.dart';
import '../../domain/ai_cfo_execution_outcome.dart';
import '../../domain/ai_cfo_conversation_intent.dart';
import '../../domain/ai_cfo_conversation_response.dart';
import '../../domain/ai_cfo_evidence.dart';
import '../../domain/ai_cfo_proposal_command.dart';
import '../../domain/ai_cfo_proposal_session_state.dart';
import '../../domain/ai_cfo_proposal_state_event.dart';
import '../../domain/services/ai_business_memory.dart';
import '../../domain/services/ai_cfo_execution_outcome_normalizer.dart';
import '../../domain/services/ai_cfo_proposal_session_controller.dart';
import '../../domain/services/ai_conversation_orchestrator.dart';
import '../../domain/services/ai_evidence_bundle.dart';
import '../../domain/services/ai_insight_generator.dart';
import '../../domain/services/ai_response_metadata.dart';
import '../../domain/services/ai_risk_detector.dart';
import '../../domain/services/ai_data_collection_state.dart';
import '../../domain/services/ai_workflow_session.dart';
import '../../domain/services/proposal_execution_engine.dart';
import '../proposal_execution_presentation_state.dart';

bool _containsArabicText(String text) {
  return RegExp(r'[\u0600-\u06FF]').hasMatch(text);
}

class LedgerEntry {
  final String code;
  final String account;
  final double debit;
  final double credit;
  final String description;
  final String date;
  final bool isUncommitted;

  LedgerEntry({
    required this.code,
    required this.account,
    required this.debit,
    required this.credit,
    required this.description,
    required this.date,
    this.isUncommitted = false,
  });
}

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
  final List<AiDecisionOption> decisionOptions;
  final AiConversationMemory? memory;
  final List<String> suggestedReplies;
  final AiResponseMetadata? metadata;
  final List<AiFinancialInsight> insights;
  final List<AiFinancialRisk> risks;
  final List<AiFinancialRecommendation> recommendations;
  final AiWorkflowSession? workflowSession;

  const AiChatMessage({
    required this.id,
    required this.role,
    required this.type,
    required this.text,
    required this.timestamp,
    this.proposal,
    this.executionResult,
    this.decisionOptions = const [],
    this.memory,
    this.suggestedReplies = const [],
    this.metadata,
    this.insights = const [],
    this.risks = const [],
    this.recommendations = const [],
    this.workflowSession,
  });
}

enum _ActionCardSource {
  chat,
  rail,
  details,
}

enum _FollowUpStatus {
  awaitingApproval,
  reviewed,
  deferred,
  completed,
}

enum _OperatingTimelineEventType {
  proposalGenerated,
  reviewed,
  awaitingApproval,
  deferred,
  executed,
  followUpNeeded,
}

class _SessionFollowUpItem {
  final String title;
  final _FollowUpStatus status;
  final String whyItMatters;
  final String nextStep;
  final DateTime? timestamp;

  const _SessionFollowUpItem({
    required this.title,
    required this.status,
    required this.whyItMatters,
    required this.nextStep,
    required this.timestamp,
  });
}

class _OperatingTimelineEntry {
  final String title;
  final _OperatingTimelineEventType type;
  final String reason;
  final String nextStep;
  final DateTime? timestamp;
  final AiProposalModel? proposal;

  const _OperatingTimelineEntry({
    required this.title,
    required this.type,
    required this.reason,
    required this.nextStep,
    required this.timestamp,
    this.proposal,
  });
}

// ─── Smart Accounting Workspace — Presentation-only Draft Model ───────────────

enum _DraftType { invoice, account, report, task, note }

enum _DraftStatus { draft, needsReview, ready }

enum _DraftConfidence { low, medium, high }

/// Which intake module created the draft.
enum _DraftSource {
  chat,
  documentIntake,
  quickTransaction,
  receivablesFollowUp,
  payablesExpense,
}

class _AccountingDraft {
  final String id;
  final _DraftType type;
  final String title;
  final String summary;
  final String? details;
  final _DraftStatus status;
  final _DraftConfidence confidence;
  final _DraftSource source;
  final String? sourceSummary;
  final double? amount;
  final String? currency;
  final String? customerOrSupplier;
  final String? dateOrDueDate;
  final String? category;
  final List<String> missingInfo;
  final String? recommendedNextAction;

  const _AccountingDraft({
    required this.id,
    required this.type,
    required this.title,
    required this.summary,
    required this.status,
    required this.confidence,
    this.source = _DraftSource.chat,
    this.details,
    this.sourceSummary,
    this.amount,
    this.currency,
    this.customerOrSupplier,
    this.dateOrDueDate,
    this.category,
    this.missingInfo = const [],
    this.recommendedNextAction,
  });

  _AccountingDraft copyWithStatus(_DraftStatus newStatus) =>
      copyWith(status: newStatus);

  _AccountingDraft copyWith({
    String? title,
    String? summary,
    String? details,
    _DraftStatus? status,
    _DraftConfidence? confidence,
    String? sourceSummary,
    double? amount,
    String? currency,
    String? customerOrSupplier,
    String? dateOrDueDate,
    String? category,
    List<String>? missingInfo,
    String? recommendedNextAction,
  }) {
    return _AccountingDraft(
      id: id,
      type: type,
      source: source,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      details: details ?? this.details,
      status: status ?? this.status,
      confidence: confidence ?? this.confidence,
      sourceSummary: sourceSummary ?? this.sourceSummary,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      customerOrSupplier: customerOrSupplier ?? this.customerOrSupplier,
      dateOrDueDate: dateOrDueDate ?? this.dateOrDueDate,
      category: category ?? this.category,
      missingInfo: missingInfo ?? this.missingInfo,
      recommendedNextAction:
          recommendedNextAction ?? this.recommendedNextAction,
    );
  }

  Map<String, dynamic> toArchiveMap() => {
        'id': id,
        'type': type.name,
        'title': title,
        'summary': summary,
        'details': details,
        'status': status.name,
        'confidence': confidence.name,
        'source': source.name,
        'sourceSummary': sourceSummary,
        'amount': amount,
        'currency': currency,
        'customerOrSupplier': customerOrSupplier,
        'dateOrDueDate': dateOrDueDate,
        'category': category,
        'missingInfo': missingInfo,
        'recommendedNextAction': recommendedNextAction,
      };

  String get sourceLabel {
    switch (source) {
      case _DraftSource.chat:
        return 'Chat';
      case _DraftSource.documentIntake:
        return 'Document';
      case _DraftSource.quickTransaction:
        return 'Transaction';
      case _DraftSource.receivablesFollowUp:
        return 'Receivable';
      case _DraftSource.payablesExpense:
        return 'Payable/Expense';
    }
  }

  String get typeLabel {
    switch (type) {
      case _DraftType.invoice:
        return 'Invoice';
      case _DraftType.account:
        return 'Account';
      case _DraftType.report:
        return 'Report';
      case _DraftType.task:
        return 'Task';
      case _DraftType.note:
        return 'Note';
    }
  }

  String get statusLabel {
    switch (status) {
      case _DraftStatus.draft:
        return 'Draft';
      case _DraftStatus.needsReview:
        return 'Needs Review';
      case _DraftStatus.ready:
        return 'Ready';
    }
  }

  String get confidenceLabel {
    switch (confidence) {
      case _DraftConfidence.low:
        return 'Low';
      case _DraftConfidence.medium:
        return 'Medium';
      case _DraftConfidence.high:
        return 'High';
    }
  }

  IconData get typeIcon {
    switch (type) {
      case _DraftType.invoice:
        return Icons.receipt_long_outlined;
      case _DraftType.account:
        return Icons.account_balance_outlined;
      case _DraftType.report:
        return Icons.bar_chart_outlined;
      case _DraftType.task:
        return Icons.task_alt_outlined;
      case _DraftType.note:
        return Icons.notes_outlined;
    }
  }
}

// ──────────────────────────────────────────────────────────────────────────────

class AiAccountantScreen extends StatefulWidget {
  final bool workspaceMode;

  const AiAccountantScreen({
    super.key,
    this.workspaceMode = false,
  });

  void _addDailyReportOrClosingDraftIfAvailable(
    LocalAccountingCommandDraft? draft,
  ) {
    if (draft == null) return;
    if (draft.type == LocalAccountingCommandDraftType.dailyReport) {
      _workspaceDrafts.insert(
        0,
        _AccountingDraft(
          id: 'local-daily-report-${DateTime.now().microsecondsSinceEpoch}',
          type: _DraftType.report,
          title: 'مسودة تقرير يومي',
          summary: 'تقرير يومي بانتظار المراجعة',
          details: const [
            'النطاق: اليوم',
            'المصدر: الجلسة الحالية والمسودات',
            'الحالة: بانتظار المراجعة',
            'لن يتم تسجيل أو إغلاق أي عملية قبل الاعتماد',
          ],
          status: _DraftStatus.needsReview,
          confidence: _DraftConfidence.medium,
          source: _DraftSource.chat,
          sourceSummary: 'من أمر محاسبي',
          dateOrDueDate: 'اليوم',
          recommendedNextAction: 'راجع التقرير قبل أي تنفيذ',
        ),
      );
    }
    if (draft.type == LocalAccountingCommandDraftType.dailyClosing) {
      _workspaceDrafts.insert(
        0,
        _AccountingDraft(
          id: 'local-daily-closing-${DateTime.now().microsecondsSinceEpoch}',
          type: _DraftType.report,
          title: 'مسودة إغلاق يومي',
          summary: 'إغلاق يومي بانتظار المراجعة',
          details: const [
            'النطاق: اليوم',
            'الحالة: بانتظار المراجعة',
            'المطلوب: مراجعة المسودات والبيانات',
            'لن يتم إغلاق اليوم أو تسجيل قيود قبل الاعتماد',
          ],
          status: _DraftStatus.needsReview,
          confidence: _DraftConfidence.medium,
          source: _DraftSource.chat,
          sourceSummary: 'من أمر محاسبي',
          dateOrDueDate: 'اليوم',
          recommendedNextAction: 'راجع مسودة الإغلاق قبل أي تنفيذ',
        ),
      );
    }
  }

  @override
  State<AiAccountantScreen> createState() => _AiAccountantScreenState();
}

class _AiAccountantScreenState extends State<AiAccountantScreen> {
  final _textController = TextEditingController();
  final _chatScrollController = ScrollController();
  final _repository = AiAccountantRepositoryFactory.make();
  final _orchestrator = AiConversationOrchestrator();
  final _proposalSessionController = const AiCfoProposalSessionController();
  final _executionOutcomeNormalizer = const AiCfoExecutionOutcomeNormalizer();

  bool _isAnalyzing = false;
  bool _isCommitting = false;
  AiProposalModel? _activeProposal;
  AiProposalModel? _confirmationProposal;
  int _contextTabIndex = 0;
  AiCfoProposalSessionState _proposalSessionState =
      AiCfoProposalSessionState.empty();
  final List<_SessionFollowUpItem> _deferredFollowUps =
      <_SessionFollowUpItem>[];

  // ── Accounting Workspace ─────────────────────────────────────────────────
  final List<_AccountingDraft> _workspaceDrafts = [];
  bool _isExtracting = false;
  int _workspaceTabIndex = 0;

  // ── Session Report & Archive ──────────────────────────────────────────────
  String? _sessionReportText;
  bool _sessionReportGenerated = false;
  bool _isSavingSession = false;
  String? _savedSessionId;
  final List<_SavedAiCfoSession> _savedSessions = [];

  static const Color darkBg = AppTheme.aiDeep;
  static const Color darkSurface = AppTheme.aiCard;
  static const Color goldAccent = AppTheme.aiGold;
  static const Color textSecondary = AppTheme.aiTextSecondary;
  static const Color borderTerminal = AppTheme.aiCardBorder;
  static const Color tealSuccess = AppTheme.aiGreen;
  static const Color premiumPanel = Color(0xFF101826);
  static const Color premiumPanelSoft = Color(0xFF142033);
  static const Color premiumStroke = Color(0xFF243044);

  final List<AiChatMessage> _messages = [
    AiChatMessage(
      id: 'welcome',
      role: AiChatRole.assistant,
      type: AiChatMessageType.question,
      text:
          'مرحبًا. أنا محاسبك الذكي ومستشارك المالي في HASOOB.\n\nاسألني عن الربح، التدفق النقدي، المخزون، المستحقات، أو ارفع مستندًا ليتم تحليله كمراجعة مالية.\n\nAdd invoices, customers, products, expenses, and sales to unlock evidence-backed analysis.',
      timestamp: DateTime(2026, 6, 11),
      suggestedReplies: [
        'Is my cash situation safe?',
        'This customer is late — what should I do?',
        'Prepare a purchase',
      ],
    ),
  ];

  final List<LedgerEntry> _ledgerRows = [
    LedgerEntry(
      code: 'JV-2026-089',
      account: 'Inventory',
      debit: 56000,
      credit: 0,
      description: 'Imported goods shipment',
      date: '2026-06-08',
    ),
    LedgerEntry(
      code: 'JV-2026-089',
      account: 'Accounts payable',
      debit: 0,
      credit: 56000,
      description: 'Supplier invoice accrual',
      date: '2026-06-08',
    ),
    LedgerEntry(
      code: 'JV-2026-090',
      account: 'Freight expense',
      debit: 12500,
      credit: 0,
      description: 'Freight cost linked to inventory',
      date: '2026-06-09',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadSavedSessions();
  }

  @override
  void dispose() {
    _textController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedSessions() async {
    try {
      final sessions = await _SavedAiCfoSession.loadAll();
      if (mounted)
        setState(() => _savedSessions
          ..clear()
          ..addAll(sessions));
    } catch (e) {
      debugPrint('[AiAccountantScreen] _loadSavedSessions: $e');
    }
  }

  String _proposalSessionId(AiProposalModel proposal) {
    return _proposalSessionController.proposalSessionId(proposal);
  }

  void _recordProposalState(AiCfoProposalStateEvent event) {
    _proposalSessionState = _proposalSessionController.reduceEvent(
      state: _proposalSessionState,
      event: event,
    );
  }

  void _recordExecutionOutcome(AiCfoExecutionOutcome outcome) {
    _proposalSessionState = _proposalSessionController.reduceOutcome(
      state: _proposalSessionState,
      outcome: outcome,
    );
  }

  bool _lastInputWasArabic = false;

  Future<void> _processAiCommand({String? customText}) async {
    final text = customText ?? _textController.text.trim();
    if (text.isEmpty) return;
    if (customText == null) _textController.clear();

    _lastInputWasArabic = _containsArabicText(text);

    _appendMessage(
      role: AiChatRole.user,
      type: AiChatMessageType.normal,
      text: text,
    );

    final controllerResult = await _proposalSessionController.resolveCommand(
      input: text,
      businessId: BusinessContext.businessId,
      sessionState: _proposalSessionState,
      activeProposal: _activeProposal,
      confirmationProposal: _confirmationProposal,
    );
    final kernelResponse = controllerResult.response;
    if (kernelResponse != null) {
      if (await _handleProposalCommand(
        controllerResult.command,
        input: text,
      )) {
        return;
      }
      _appendKernelResponse(kernelResponse);
      return;
    }

    if (await _handleProposalCommand(
      controllerResult.command,
      input: text,
    )) {
      return;
    }

    AiAdvisorResponse advisorResponse;
    try {
      advisorResponse = await _orchestrator.generateResponse(
        userText: text,
        activeProposal: _activeProposal ?? _confirmationProposal,
      );
    } catch (e, stack) {
      debugPrint('[AiAccountantScreen] Safe AI response fallback: $e');
      debugPrint('$stack');
      if (!mounted) return;
      _appendMessage(
        role: AiChatRole.assistant,
        type: AiChatMessageType.error,
        text: _lastInputWasArabic
            ? 'ما أقدر أجهّز إجابة مالية موثوقة من البيانات المتوفرة حاليًا. جرب غيره سؤال أضيق — مثلاً: تدفق نقدي، خطر عملاء، مخزون، أو تسعير شحنة.'
            : 'I could not prepare a reliable CFO answer from the available data. Please try again, or ask for a narrower analysis such as cash flow, customer risk, inventory, or shipment pricing.',
        suggestedReplies: _lastInputWasArabic
            ? const [
                'راجع الصحة المالية',
                'راجع خطر العميل',
                'سعر شحنة',
              ]
            : const [
                'Check business health',
                'Review customer risk',
                'Price a shipment',
              ],
      );
      return;
    }

    if (_isExecutionIntent(text)) {
      _addLocalCommandDraftIfAvailable(advisorResponse.localCommandDraft);
      final proposal = _activeProposal ?? _confirmationProposal;
      if (proposal != null && _canDelegateProposalExecution(proposal)) {
        await _handleExecutionIntent(text);
      } else {
        _appendMessage(
          role: AiChatRole.assistant,
          type: AiChatMessageType.confirmation,
          text: advisorResponse.text,
          decisionOptions: advisorResponse.decisionOptions,
          memory: advisorResponse.memory,
          suggestedReplies: advisorResponse.suggestedReplies,
          metadata: advisorResponse.metadata,
          insights: advisorResponse.insights,
          risks: advisorResponse.risks,
          recommendations: advisorResponse.recommendations,
          workflowSession: advisorResponse.workflowSession,
        );
      }
      return;
    }

    if (!advisorResponse.shouldPrepareProposal) {
      _addDailyReportOrClosingDraftIfAvailable(
        advisorResponse.localCommandDraft,
      );
      if (advisorResponse.localCommandDraft?.type !=
              LocalAccountingCommandDraftType.dailyReport &&
          advisorResponse.localCommandDraft?.type !=
              LocalAccountingCommandDraftType.dailyClosing) {
        _addLocalCommandDraftIfAvailable(advisorResponse.localCommandDraft);
      }
      _appendMessage(
        role: AiChatRole.assistant,
        type: _messageTypeForMode(advisorResponse.mode),
        text: advisorResponse.text,
        decisionOptions: advisorResponse.decisionOptions,
        memory: advisorResponse.memory,
        suggestedReplies: advisorResponse.suggestedReplies,
        metadata: advisorResponse.metadata,
        insights: advisorResponse.insights,
        risks: advisorResponse.risks,
        recommendations: advisorResponse.recommendations,
        workflowSession: advisorResponse.workflowSession,
      );
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _confirmationProposal = null;
    });

    try {
      final proposalText = advisorResponse.proposalDraftText ?? text;
      final proposal = await _repository.parseNaturalLanguage(proposalText);
      if (!mounted) return;

      if (proposal.actionType == 'unknown') {
        _appendMessage(
          role: AiChatRole.assistant,
          type: AiChatMessageType.question,
          text: _lastInputWasArabic
              ? 'عايز أكون واضح معاك. هل دي عملية شراء ولا بيع ولا تسعير؟ لازم أعرف نوع العملية، المنتج، الكمية، المبلغ، والعميل أو المورد.'
              : 'I need a little more detail before I can prepare a safe proposal. Is this a purchase, sale, or pricing simulation? Please include product, quantity, amount, and customer or supplier when relevant.',
          suggestedReplies: _lastInputWasArabic
              ? const [
                  'جهّز عملية شراء',
                  'جهّز عملية بيع',
                  'شغّل محاكاة تسعير',
                ]
              : const [
                  'Prepare a purchase',
                  'Prepare a sale',
                  'Run a pricing simulation',
                ],
        );
        return;
      }

      setState(() {
        _activeProposal = proposal;
        _orchestrator.rememberProposal(proposal);
        _addPreviewLedgerRow(proposal);
      });
      _appendMessage(
        role: AiChatRole.assistant,
        type: AiChatMessageType.proposal,
        text: _lastInputWasArabic
            ? 'أعددت مقترحًا للمراجعة. افحص التفاصيل قبل الموافقة. التنفيذ رح يروح عبر محرك المحاسبة المحمي.'
            : 'I prepared a reviewable proposal. Check the details before approving. Execution will still go through the guarded accounting engine.',
        proposal: proposal,
        suggestedReplies: _proposalSuggestedReplies(proposal),
      );
    } catch (e) {
      debugPrint('[AiAccountantScreen] Proposal parsing stopped safely: $e');
      if (!mounted) return;
      _appendMessage(
        role: AiChatRole.assistant,
        type: AiChatMessageType.error,
        text: _lastInputWasArabic
            ? 'ما أقدر أجهّز مقترح آمن من طلبك. أضف نوع العملية، المنتج، الكمية، المبلغ، والعميل أو المورد.'
            : 'I could not prepare a safe proposal from that request. Please add the transaction type, product, quantity, amount, and customer or supplier when relevant.',
        suggestedReplies: _lastInputWasArabic
            ? const [
                'جرب كعملية شراء',
                'جرب كعملية بيع',
                'اسأل لنصيحة بدلاً من ذلك',
              ]
            : const [
                'Try as a purchase',
                'Try as a sale',
                'Ask for advice instead',
              ],
      );
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  void _appendKernelResponse(AiCfoConversationResponse response) {
    final blocked = response.type == AiCfoResponseType.blocked;
    final emptyEvidence = response.evidence.isEmpty;
    final suggestions = blocked
        ? (_lastInputWasArabic
            ? const ['جهّز مقترح', 'راجع الصحة المالية', 'استمر في المحادثة']
            : const [
                'Prepare a proposal',
                'Review business health',
                'Continue discussion',
              ])
        : emptyEvidence
            ? (_lastInputWasArabic
                ? const [
                    'أي بيانات متوفرة؟',
                    'راجع خطر المخزون',
                    'راجع تدفق النقدية'
                  ]
                : const [
                    'What data is missing?',
                    'Review inventory risk',
                    'Review cash flow',
                  ])
            : (_lastInputWasArabic
                ? const ['اشرح البرهان', 'أي بيانات متوفرة؟', 'راجع المخاطر']
                : const [
                    'Explain evidence',
                    'What data is missing?',
                    'Review next risk',
                  ]);
    _appendMessage(
      role: AiChatRole.assistant,
      type: response.isBlocked
          ? AiChatMessageType.confirmation
          : AiChatMessageType.normal,
      text: _kernelResponseText(response),
      proposal: response.proposal,
      suggestedReplies: suggestions,
      metadata: _kernelResponseMetadata(response),
    );
  }

  Future<bool> _handleProposalCommand(
    AiCfoProposalCommand command, {
    required String input,
  }) async {
    switch (command.type) {
      case AiCfoProposalCommandType.none:
        return false;
      case AiCfoProposalCommandType.showGuardMessage:
        final response = command.response;
        if (response != null) {
          _appendKernelResponse(response);
        } else {
          _appendMessage(
            role: AiChatRole.assistant,
            type: AiChatMessageType.confirmation,
            text: command.reason,
            suggestedReplies: _lastInputWasArabic
                ? const [
                    'راجع المقترح',
                    'جهّز مقترح',
                    'استمر في المحادثة',
                  ]
                : const [
                    'Review proposal',
                    'Prepare a proposal',
                    'Continue discussion',
                  ],
          );
        }
        return true;
      case AiCfoProposalCommandType.reviewProposal:
        final proposal = command.proposal;
        if (proposal == null) return false;
        _showActionExecutionDetails(proposal);
        return true;
      case AiCfoProposalCommandType.approveProposal:
        final proposal = command.proposal;
        if (proposal != null) {
          setState(() {
            _recordProposalState(
              AiCfoProposalStateEvent(
                type: AiCfoProposalStateEventType.approved,
                proposal: proposal,
                reason: 'Proposal approved in session.',
                occurredAt: DateTime.now(),
              ),
            );
          });
        }
        return false;
      case AiCfoProposalCommandType.deferProposal:
        final proposal = command.proposal;
        if (proposal == null) return false;
        _deferProposal(proposal, _proposalGeneratedAt(proposal));
        return true;
      case AiCfoProposalCommandType.executeProposal:
        if (!command.canMutateLedger) return false;
        await _handleExecutionIntent(input);
        return true;
    }
  }

  String _kernelResponseText(AiCfoConversationResponse response) {
    final ar = _lastInputWasArabic;
    final lines = <String>[
      response.title,
      '',
      ar ? 'الصورة الحالية:' : 'Current picture:',
      _currentPictureLine(response),
      '',
      ar ? 'البراهين المتوفرة:' : 'Available evidence:',
      _availableEvidenceLine(response),
      '',
      ar ? 'البيانات الناقصة:' : 'Missing data:',
      _missingDataLine(response),
      '',
      ar ? 'المخاطر:' : 'Risk:',
      _riskLine(response),
      '',
      ar ? 'الإجراء التالي الموصى به:' : 'Recommended next action:',
      _recommendedNextActionLine(response),
    ];
    if (response.evidence.isNotEmpty) {
      lines.add('');
      lines.add(ar ? 'تفاصيل البراهين:' : 'Evidence details:');
      lines.addAll(response.evidence
          .take(4)
          .map((item) => '- ${item.label}: ${item.value}'));
      lines.add('');
      lines.add(ar ? 'مصادر البراهين:' : 'Evidence sources:');
      lines.addAll(response.evidence.take(6).map((item) => '- ${item.source}'));
    } else {
      lines.add('');
      lines.add(ar ? 'شي لازم تضيفه:' : 'What to add next:');
      lines.add(ar
          ? '- منتجات بمخزون وتكلفة وسعر بيع.'
          : '- Products with stock, cost, and selling price.');
      lines.add(ar
          ? '- عملاء وفواتير بأرصدة مدفوعة أو غير مدفوعة.'
          : '- Customers and invoices with paid or unpaid balances.');
      lines.add(ar
          ? '- مبيعات، مدفوعات، مصروفات أو قيود محاسبية مسجلة.'
          : '- Recorded sales, payments, expenses, or ledger entries.');
      lines.add('');
      lines.add(ar ? 'أسئلة مفيدة الآن:' : 'Useful next questions:');
      lines.add(ar
          ? '- أي بيانات تدفق النقدية متوفرة؟'
          : '- What cash-flow data is missing?');
      lines.add(
          ar ? '- أي مخزون يحتاج انتباه؟' : '- Which stock needs attention?');
      lines.add(ar
          ? '- أي حاجة تقدر تقولها من البيانات اللي عندي؟'
          : '- What can you say from the data I have?');
    }
    if (response.risks.isNotEmpty || response.blockedReason != null) {
      lines.add('');
      lines.add(ar ? 'البيانات الناقصة / الحدود:' : 'Missing data / limits:');
      if (response.blockedReason != null) {
        lines.add('- ${response.blockedReason}');
      }
      lines.addAll(response.risks.take(4).map((item) => '- $item'));
    }
    return lines.join('\n');
  }

  String _currentPictureLine(AiCfoConversationResponse response) {
    if (response.evidence.isEmpty) {
      return response.message;
    }
    final ar = _lastInputWasArabic;
    final leadEvidence = response.evidence.take(3).map((item) {
      return '${item.label}: ${item.value}';
    }).join('؛ ');
    return ar
        ? 'الصورة دي بناها من ${response.evidence.length} برهان محلي${response.evidence.length == 1 ? '' : 'ة'} متوفرة دلوقتي: $leadEvidence.'
        : 'This view is based on ${response.evidence.length} local evidence record${response.evidence.length == 1 ? '' : 's'} available now: $leadEvidence.';
  }

  String _availableEvidenceLine(AiCfoConversationResponse response) {
    final ar = _lastInputWasArabic;
    if (response.evidence.isEmpty) {
      return ar
          ? 'ما في برهان قابلة للاستخدام مرتبطة بالجواب دلوقتي.'
          : 'No usable local evidence is attached to this answer yet.';
    }
    final sources = response.evidence
        .map((item) => item.source)
        .where((source) => source.trim().isNotEmpty)
        .toSet()
        .take(3)
        .join(', ');
    return sources.isEmpty
        ? ar
            ? 'البراهين موجودة، بس التسميات غير مكتملة.'
            : 'Evidence exists, but the source labels are incomplete.'
        : ar
            ? 'أقدر أستخدم البراهين من: $sources.'
            : 'I can use evidence from: $sources.';
  }

  String _missingDataLine(AiCfoConversationResponse response) {
    final ar = _lastInputWasArabic;
    if (response.risks.isNotEmpty) {
      return response.risks.take(2).join(' ');
    }
    if (response.evidence.isEmpty) {
      return ar
          ? 'التطبيق ناقص أنشطة مسجلة كفاية عشان أقارن الاتجاهات. أضف منتجات، عملاء، فواتير، مبيعات، مدفوعات، أو مصروفات تحتاجها.'
          : 'The app is missing enough recorded activity to compare trends yet. Add products, customers, invoices, sales, payments, or expenses to make the answer stronger.';
    }
    return ar
        ? 'ما بصراحة أي تغيير في الاتجاه من اللقطة دي بس. استمر في تسجيل المبيعات اليومية، التحصيلات، المصروفات، وتحديثات المخزون عشان مراجعتنا الجاية تقدر تقارن الحركة.'
        : 'No trend change is being claimed from this snapshot alone. Keep recording daily sales, collections, expenses, and stock updates so the next review can compare movement.';
  }

  String _riskLine(AiCfoConversationResponse response) {
    final ar = _lastInputWasArabic;
    final hasLowConfidence = response.evidence
        .any((item) => item.confidence == AiCfoEvidenceConfidence.low);
    if (hasLowConfidence) {
      return ar
          ? 'بعض البراهين منخفضة الثقة، فحاول تأكيد السجلات قبل أخذ قرار مالي.'
          : 'Some evidence is low confidence, so verify the underlying records before making a financial decision.';
    }
    if (response.risks.isNotEmpty) {
      return response.risks.first;
    }
    if (response.evidence.isEmpty) {
      return ar
          ? 'المخاطر الأساسية من اتخاذ قرار من غير برهان محلي كافي.'
          : 'The main risk is acting without enough local evidence.';
    }
    return ar
        ? 'ما في مخاطر حاسمة مؤكدة من الجواب ده بس؛ راجع تدفق النقدية، المخزون، الربح، أو الذمم قبل أي إجراء.'
        : 'No critical risk is proven from this answer alone; review cash flow, stock, profit, or receivables before acting.';
  }

  String _recommendedNextActionLine(AiCfoConversationResponse response) {
    final ar = _lastInputWasArabic;
    if (response.type == AiCfoResponseType.blocked ||
        response.intent == AiCfoConversationIntent.unsupported) {
      return ar
          ? 'اسأل عن مجال محدد، مثلاً: تدفق نقدي، مخزون، ربح، أرصدة، أو تفسير البراهين.'
          : 'Ask for one focused area, such as cash flow, inventory, profit, receivables, or evidence explanation.';
    }
    if (response.evidence.isEmpty) {
      return ar
          ? 'أضف سجل عمل حقيقي، وبعدين اسأل السؑال تاني عشان الجواب يقدر يستخدم البراهين.'
          : 'Add one real business record, then ask the same question again so the answer can use evidence.';
    }
    switch (response.intent) {
      case AiCfoConversationIntent.cashflowReview:
        return ar
            ? 'راجع الفواتير غير المدفوعة، التحصيلات الأخيرة، والمصروفات القادمة قبل أي طلب دفع أو خصم.'
            : 'Check unpaid invoices, recent collections, and upcoming expenses before spending or discounting.';
      case AiCfoConversationIntent.inventoryReview:
        return ar
            ? 'راجع المنتجات منخفضة المخزون أو غير المتوفر، وبعدين قرر إيش تشتري بناءً على الطلب والربحية.'
            : 'Review low-stock or out-of-stock items, then decide what to reorder based on demand and margin.';
      case AiCfoConversationIntent.profitReview:
        return ar
            ? 'قارن سعر البيع، التكلفة، حجم المبيعات، والمصروفات قبل ما تغير الأسعار أو تشتري مخزون إضافي.'
            : 'Compare selling price, cost, sales volume, and expenses before changing prices or buying more stock.';
      case AiCfoConversationIntent.receivablesReview:
        return ar
            ? 'تابع أرصدة العملاء اللي عندهم أعلى مستوى تعرض أولاً.'
            : 'Follow up on customer balances with the highest exposure first.';
      case AiCfoConversationIntent.explainEvidence:
        return ar
            ? 'استخدم قائمة البراهين تحت تحقق من سجلات المصادر، وبعدين اسأل سؑال محدد إذا لزم.'
            : 'Use the evidence list below to check the source records, then ask a narrower follow-up if needed.';
      case AiCfoConversationIntent.businessHealth:
        return ar
            ? 'اختر المجال الأضعف التالي: تدفق النقدية، المخزون، الربح، أو تحصيل العملاء.'
            : 'Pick the weakest area next: cash flow, stock, profit, or customer collection.';
      case AiCfoConversationIntent.createProposal:
      case AiCfoConversationIntent.approveProposal:
      case AiCfoConversationIntent.deferProposal:
      case AiCfoConversationIntent.executeProposal:
        return ar
            ? 'راجع تفاصيل المقترح وأوافق بس لما الأرقام تطابق سجلاتك.'
            : 'Review the proposal details and approve only when the numbers match your records.';
      case AiCfoConversationIntent.unsupported:
        return ar
            ? 'اسأل عن مجال محدد، مثلاً: تدفق نقدي، مخزون، ربح، أرصدة، أو تفسير البراهين.'
            : 'Ask for one focused area, such as cash flow, inventory, profit, receivables, or evidence explanation.';
    }
  }

  AiResponseMetadata _kernelResponseMetadata(
    AiCfoConversationResponse response,
  ) {
    final missingEvidence = <String>[
      if (response.blockedReason != null) response.blockedReason!,
      ...response.risks,
    ];
    return AiResponseMetadata(
      confidenceLevel: _kernelConfidence(response.evidence),
      executedTools: response.evidence
          .map((item) => item.source)
          .where((source) => source.trim().isNotEmpty)
          .toSet()
          .toList(),
      missingEvidence: missingEvidence.toSet().toList(),
      evidenceCount: response.evidence.length,
      generatedAt: DateTime.now(),
    );
  }

  AiEvidenceConfidence _kernelConfidence(List<AiCfoEvidence> evidence) {
    if (evidence.isEmpty) return AiEvidenceConfidence.low;
    if (evidence
        .any((item) => item.confidence == AiCfoEvidenceConfidence.low)) {
      return AiEvidenceConfidence.low;
    }
    if (evidence
        .any((item) => item.confidence == AiCfoEvidenceConfidence.medium)) {
      return AiEvidenceConfidence.medium;
    }
    return AiEvidenceConfidence.high;
  }

  Future<void> _handleExecutionIntent(String text) async {
    if (_isCommitting) {
      _appendExecutionGuardMessage(
        'Execution is already in progress. I will wait for the guarded result before starting another request.',
      );
      return;
    }

    final wantsQuotation = _containsAny(_normalized(text), [
      'convert',
      'quotation',
      'quote',
      'حول',
      'حولها',
    ]);
    final proposal = _activeProposal ?? _confirmationProposal;

    if (proposal == null || !_canDelegateProposalExecution(proposal)) {
      _recordExecutionOutcome(
        _executionOutcomeNormalizer.skipped(
          reason: 'No executable proposal is available.',
          proposal: proposal,
          proposalSessionId:
              proposal == null ? null : _proposalSessionId(proposal),
        ),
      );
      _appendMessage(
        role: AiChatRole.assistant,
        type: AiChatMessageType.confirmation,
        text:
            'I need a clear, complete proposal before execution. Do you want to prepare a purchase, sale, or pricing simulation?',
        suggestedReplies: const [
          'Prepare a purchase',
          'Prepare a sale',
          'Run a pricing simulation',
        ],
      );
      return;
    }

    if (wantsQuotation && proposal.actionType == 'pricing_simulation') {
      _convertPricingToQuotation();
      return;
    }

    await _executeProposal(proposal, clearActive: true);
  }

  void _appendMessage({
    required AiChatRole role,
    required AiChatMessageType type,
    required String text,
    AiProposalModel? proposal,
    ProposalExecutionResult? executionResult,
    List<AiDecisionOption> decisionOptions = const [],
    AiConversationMemory? memory,
    List<String> suggestedReplies = const [],
    AiResponseMetadata? metadata,
    List<AiFinancialInsight> insights = const [],
    List<AiFinancialRisk> risks = const [],
    List<AiFinancialRecommendation> recommendations = const [],
    AiWorkflowSession? workflowSession,
  }) {
    setState(() {
      _messages.add(
        AiChatMessage(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          role: role,
          type: type,
          text: text,
          timestamp: DateTime.now(),
          proposal: proposal,
          executionResult: executionResult,
          decisionOptions: decisionOptions,
          memory: memory,
          suggestedReplies: suggestedReplies,
          metadata: metadata,
          insights: insights,
          risks: risks,
          recommendations: recommendations,
          workflowSession: workflowSession,
        ),
      );
    });
    _scrollChatToEnd();
  }

  void _scrollChatToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_chatScrollController.hasClients) return;
      _chatScrollController.animateTo(
        _chatScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _addPreviewLedgerRow(AiProposalModel proposal) {
    _ledgerRows.removeWhere((row) => row.code == 'PENDING-AI');
    if (proposal.actionType == 'unknown' ||
        proposal.actionType == 'pricing_simulation') {
      return;
    }
    final isPurchase = proposal.actionType == 'purchase';
    final total =
        (proposal.financialPayload?['totalAmount'] as num?)?.toDouble() ?? 0;
    final itemName =
        proposal.inventoryPayload?['name']?.toString() ?? 'Proposed item';
    _ledgerRows.insert(
      0,
      LedgerEntry(
        code: 'PENDING-AI',
        account: isPurchase ? 'Inventory ($itemName)' : 'Sales revenue',
        debit: isPurchase ? total : 0,
        credit: isPurchase ? 0 : total,
        description: proposal.explanation,
        date: 'Pending review',
        isUncommitted: true,
      ),
    );
  }

  Future<void> _savePricingSimulation() async {
    final proposal = _activeProposal;
    if (proposal == null || !_guardProposalExecutionRequest(proposal)) return;
    await _executeProposal(proposal, clearActive: true);
  }

  void _convertPricingToQuotation() {
    const result = ProposalExecutionResult(
      success: false,
      requiresUserConfirmation: true,
      error:
          'Converting a pricing simulation to a quotation needs a confirmed customer and product first.',
    );
    setState(() {
      _activeProposal = null;
      _confirmationProposal = null;
    });
    _appendMessage(
      role: AiChatRole.assistant,
      type: AiChatMessageType.executionResult,
      text:
          'I cannot convert this yet. A quotation needs a confirmed customer and product first.',
      executionResult: result,
      suggestedReplies: const [
        'Add customer details',
        'Choose a product',
        'Keep discussing pricing',
      ],
    );
  }

  Future<void> _commitProposalToLedger() async {
    final proposal = _activeProposal;
    if (proposal == null || !_guardProposalExecutionRequest(proposal)) return;
    await _executeProposal(proposal, clearActive: true);
  }

  Future<void> _confirmProductAndExecute(String productId) async {
    final proposal = _confirmationProposal ?? _activeProposal;
    if (proposal == null || productId.isEmpty) return;
    if (_isCommitting) {
      _appendExecutionGuardMessage(
        'Execution is already in progress. I will wait for the guarded result before starting another request.',
      );
      return;
    }
    final inventory =
        Map<String, dynamic>.from(proposal.inventoryPayload ?? {});
    inventory['productId'] = productId;
    final confirmed = AiProposalModel(
      actionType: proposal.actionType,
      explanation: proposal.explanation,
      confidenceScore: proposal.confidenceScore,
      inventoryPayload: inventory,
      customerPayload: proposal.customerPayload,
      financialPayload: proposal.financialPayload,
      pricingPayload: proposal.pricingPayload,
    );
    await _executeProposal(confirmed, clearActive: true);
  }

  Future<void> _executeProposal(
    AiProposalModel proposal, {
    required bool clearActive,
  }) async {
    if (_isCommitting) {
      _appendExecutionGuardMessage(
        'Execution is already in progress. I will wait for the guarded result before starting another request.',
      );
      return;
    }

    setState(() {
      _recordExecutionOutcome(
        _executionOutcomeNormalizer.started(
          proposal: proposal,
          proposalSessionId: _proposalSessionId(proposal),
        ),
      );
      _isCommitting = true;
    });
    try {
      final result = await _repository.executeProposalDetailed(proposal);
      if (!mounted) return;
      setState(() {
        final proposalSessionId = _proposalSessionId(proposal);
        final outcome = result.success
            ? _executionOutcomeNormalizer.succeeded(
                proposal: proposal,
                proposalSessionId: proposalSessionId,
                message: _resultSummary(result),
              )
            : result.requiresUserConfirmation
                ? _executionOutcomeNormalizer.blocked(
                    proposal: proposal,
                    proposalSessionId: proposalSessionId,
                    reason: _resultSummary(result),
                  )
                : _executionOutcomeNormalizer.failed(
                    proposal: proposal,
                    proposalSessionId: proposalSessionId,
                    reason: _resultSummary(result),
                  );
        _recordExecutionOutcome(outcome);
        _confirmationProposal =
            result.requiresUserConfirmation ? proposal : null;
        if (clearActive && !result.requiresUserConfirmation) {
          _activeProposal = null;
        }
        _orchestrator.markExecutionFollowUp();
        _isCommitting = false;
        _markPreviewRow(result.success);
      });
      _appendMessage(
        role: AiChatRole.assistant,
        type: AiChatMessageType.executionResult,
        text: result.success
            ? 'Execution finished. You can review the result below or continue the conversation.'
            : 'The guarded execution flow stopped this action. Review the details below before trying again.',
        executionResult: result,
        suggestedReplies: result.success
            ? const [
                'Explain the impact',
                'Prepare another transaction',
                'Discuss pricing',
              ]
            : const [
                'What is missing?',
                'Prepare a clearer proposal',
                'Continue discussion',
              ],
      );
    } catch (e) {
      debugPrint('[AiAccountantScreen] Guarded execution failed safely: $e');
      if (!mounted) return;
      const result = ProposalExecutionResult(
        success: false,
        error:
            'The guarded execution flow stopped this action before anything was committed.',
      );
      setState(() {
        _recordExecutionOutcome(
          _executionOutcomeNormalizer.failed(
            proposal: proposal,
            proposalSessionId: _proposalSessionId(proposal),
            reason: result.error ?? 'Execution failed safely.',
          ),
        );
        _confirmationProposal = null;
        if (clearActive) _activeProposal = null;
        _isCommitting = false;
        _markPreviewRow(false);
      });
      _appendMessage(
        role: AiChatRole.assistant,
        type: AiChatMessageType.executionResult,
        text: 'Execution failed safely. No vague conversation was committed.',
        executionResult: result,
        suggestedReplies: const [
          'Review requirements',
          'Prepare a new proposal',
          'Ask for advice',
        ],
      );
    }
  }

  void _markPreviewRow(bool success) {
    for (var i = 0; i < _ledgerRows.length; i++) {
      if (_ledgerRows[i].code == 'PENDING-AI') {
        final row = _ledgerRows[i];
        _ledgerRows[i] = LedgerEntry(
          code: success ? 'JV-APPROVED' : 'JV-REVIEW',
          account: row.account,
          debit: row.debit,
          credit: row.credit,
          description: success
              ? '${row.description} (executed)'
              : '${row.description} (needs review)',
          date: DateTime.now().toIso8601String().split('T').first,
          isUncommitted: !success,
        );
      }
    }
  }

  Future<void> _openProduct(String productId) async {
    final product = await ProductRepository().getProductById(
      productId,
      BusinessContext.businessId,
    );
    if (!mounted) return;
    if (product == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product was not found.')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProductDetailsScreen(product: product)),
    );
  }

  void _openInvoice(String invoiceId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InvoiceDetailsScreen(invoiceId: invoiceId),
      ),
    );
  }

  Future<void> _copyExecutionSummary(ProposalExecutionResult result) async {
    await Clipboard.setData(ClipboardData(text: _resultSummary(result)));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Execution summary copied.')),
    );
  }

  String _resultSummary(ProposalExecutionResult result) {
    final data = _asMap(result.data);
    final product = _asMap(data['product']);
    final invoice = _asMap(data['invoice']);
    final journal = _asMap(data['journalEntry']);
    return [
      'Status: ${_statusLabel(result, data)}',
      if ((result.message ?? '').isNotEmpty) 'Message: ${result.message}',
      if ((result.error ?? '').isNotEmpty) 'Error: ${result.error}',
      if (product.isNotEmpty)
        'Product: ${product['id'] ?? '-'} / ${product['name'] ?? '-'}',
      if (invoice.isNotEmpty)
        'Invoice: ${invoice['id'] ?? '-'} / ${invoice['number'] ?? '-'}',
      if (journal.isNotEmpty)
        'Journal: ${journal['id'] ?? '-'} / ${journal['code'] ?? '-'}',
    ].join('\n');
  }

  @override
  Widget build(BuildContext context) {
    if (widget.workspaceMode) {
      return _buildWorkspaceView();
    }
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: darkBg,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop =
                UIResponsive.isWideDesktopWidth(constraints.maxWidth);
            return SafeArea(
              child: Column(
                children: [
                  _buildPremiumHeader(isDesktop: isDesktop),
                  Expanded(child: _buildCommandCenter(isDesktop: isDesktop)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildWorkspaceView() {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: darkBg,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop =
                  UIResponsive.isWideDesktopWidth(constraints.maxWidth);
              return _buildConversationDominantShell(isDesktop: isDesktop);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildConversationDominantShell({required bool isDesktop}) {
    final padding = EdgeInsets.fromLTRB(
      isDesktop ? 18 : 10,
      isDesktop ? 14 : 8,
      isDesktop ? 18 : 10,
      isDesktop ? 14 : 10,
    );

    if (!isDesktop) {
      return Padding(
        padding: padding,
        child: Column(
          children: [
            Expanded(child: _buildConversationPanel(isDesktop: false)),
          ],
        ),
      );
    }

    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 24,
            child: _buildLeftContextRail(),
          ),
          const SizedBox(width: 14),
          Expanded(
            flex: 52,
            child: _buildCenterConversationPanel(),
          ),
          const SizedBox(width: 14),
          Expanded(
            flex: 24,
            child: _buildRightContextRail(),
          ),
        ],
      ),
    );
  }

  Widget _buildLeftContextRail() {
    return Container(
      decoration: BoxDecoration(
        color: premiumPanelSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: premiumStroke),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildRailHeader(
              icon: Icons.monitor_heart_outlined,
              arabicTitle: 'الوضع المالي',
              englishTitle: 'Financial Status',
            ),
            const SizedBox(height: 10),
            Command360ContextModule(
              title: 'ملخص اليوم',
              icon: Icons.today_outlined,
              child: _buildTodaySummarySection(),
            ),
            Command360ContextModule(
              title: 'المؤشرات',
              icon: Icons.signal_cellular_alt,
              child: _buildCommandSignalStrip(isDesktop: true),
            ),
            Command360ContextModule(
              title: 'الحسابات',
              icon: Icons.account_balance_outlined,
              child: _buildAccountsMonitorSection(),
            ),
            Command360ContextModule(
              title: 'المخاطر',
              icon: Icons.warning_amber_rounded,
              child: _buildRiskMonitorSection(),
            ),
            Command360ContextModule(
              title: 'البيانات الناقصة',
              icon: Icons.rule_folder_outlined,
              child: _buildMissingDataSection(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterConversationPanel() {
    return Container(
      decoration: BoxDecoration(
        color: premiumPanel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: premiumStroke),
      ),
      child: _buildConversationPanel(isDesktop: true),
    );
  }

  // ignore: unused_element
  Widget _buildExecutiveCommandHeader({required bool isDesktop}) {
    final score = _businessHealthScore();
    final risks = _latestRisks()
        .where((risk) => risk.title != 'No major risk detected')
        .length;
    final recommendations = _latestRecommendations().length;
    final focus = _activeCommandFocus();

    return Container(
      padding: EdgeInsets.all(isDesktop ? 18 : 14),
      decoration: BoxDecoration(
        color: premiumPanel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: premiumStroke),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: isDesktop
          ? Row(
              children: [
                Expanded(child: _buildExecutiveHeaderIdentity(focus)),
                const SizedBox(width: 16),
                _buildExecutiveHeaderMetric(
                  label: 'Health',
                  value: score == null ? 'Pending' : '$score/100',
                  color: score == null ? textSecondary : _healthColor(score),
                ),
                const SizedBox(width: 10),
                _buildExecutiveHeaderMetric(
                  label: 'Risks',
                  value: '$risks',
                  color: risks == 0 ? tealSuccess : goldAccent,
                ),
                const SizedBox(width: 10),
                _buildExecutiveHeaderMetric(
                  label: 'Actions',
                  value: '$recommendations',
                  color: recommendations == 0 ? textSecondary : tealSuccess,
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildExecutiveHeaderIdentity(focus),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildExecutiveHeaderMetric(
                        label: 'Health',
                        value: score == null ? 'Pending' : '$score/100',
                        color:
                            score == null ? textSecondary : _healthColor(score),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildExecutiveHeaderMetric(
                        label: 'Risks',
                        value: '$risks',
                        color: risks == 0 ? tealSuccess : goldAccent,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildExecutiveHeaderMetric(
                        label: 'Actions',
                        value: '$recommendations',
                        color:
                            recommendations == 0 ? textSecondary : tealSuccess,
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  // ignore: unused_element
  Widget _buildDailyOperatingBrief({required bool compact}) {
    final metadata = _latestMetadata();
    final risks = _latestRisks()
        .where((risk) => risk.title != 'No major risk detected')
        .toList();
    final recommendations = _latestRecommendations();
    final missing = metadata?.missingEvidence.take(2).toList() ?? const [];
    final hasEvidence = metadata != null && metadata.evidenceCount > 0;
    final evidenceLine = !hasEvidence
        ? 'No evidence checked yet in this session.'
        : '${metadata.evidenceCount} evidence record${metadata.evidenceCount == 1 ? '' : 's'} checked at ${metadata.confidenceLabel.toLowerCase()} confidence.';
    final missingLine = missing.isEmpty
        ? 'Add product, record sale, add customer, or create invoice/quotation to build evidence.'
        : missing.join(' ');
    final riskLine = risks.isEmpty
        ? (!hasEvidence
            ? 'First risk: low data confidence. Not enough sales, stock, or invoice evidence to compare trends.'
            : 'First risk: acting before enough evidence to compare trends. Add more activity before trusting insights.')
        : 'First risk: ${risks.first.title}. ${risks.first.description}';
    final actionLine = recommendations.isNotEmpty
        ? recommendations.first.title
        : !hasEvidence
            ? 'Add products first, then record a sale with Quick Sell. Then ask AI CFO what changed.'
            : 'Ask AI CFO what changed after adding new data.';
    final suggestedQuestion = hasEvidence
        ? 'After my latest sale, which products are moving and what stock should I check?'
        : 'What data should I add before asking for financial analysis?';

    return Container(
      padding: EdgeInsets.all(compact ? 12 : 14),
      decoration: BoxDecoration(
        color: premiumPanel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: goldAccent.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.today_outlined, color: goldAccent, size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'الملخص التشغيلي اليومي',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _statusPill('Beta', goldAccent),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _dailyBriefChip('البيانات', evidenceLine, Icons.folder_copy),
              _dailyBriefChip(
                  'البيانات الناقصة', missingLine, Icons.rule_rounded),
              _dailyBriefChip(
                  'أول مخاطرة', riskLine, Icons.warning_amber_rounded),
              _dailyBriefChip(
                  'الخطوة التالية', actionLine, Icons.route_rounded),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _isAnalyzing || _isCommitting
                  ? null
                  : () => _processAiCommand(customText: suggestedQuestion),
              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
              label: Text(hasEvidence
                  ? 'Ask about sales movement'
                  : 'What data is missing?'),
              style: TextButton.styleFrom(
                foregroundColor: goldAccent,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dailyBriefChip(String label, String value, IconData icon) {
    return Container(
      constraints: const BoxConstraints(minWidth: 190, maxWidth: 330),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: darkBg.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: premiumStroke),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: goldAccent, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExecutiveHeaderIdentity(String focus) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: goldAccent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: goldAccent.withValues(alpha: 0.28)),
          ),
          child: const Icon(
            Icons.account_balance_outlined,
            color: goldAccent,
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text(
                    'AI CFO Command360',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  _statusPill('Command360 Beta', goldAccent),
                  _statusPill(
                    _activeProposal != null ? 'Proposal ready' : 'Live',
                    _activeProposal != null ? goldAccent : tealSuccess,
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                focus,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: textSecondary,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildExecutiveHeaderMetric({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      constraints: const BoxConstraints(minWidth: 88),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: darkSurface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommandSignalStrip({required bool isDesktop}) {
    final signals = _commandContextSignals();
    final cards = signals
        .map((signal) => _CommandSignalCard(signal: signal))
        .toList(growable: false);

    if (isDesktop) {
      return Row(
        children: [
          for (var index = 0; index < cards.length; index++) ...[
            Expanded(child: cards[index]),
            if (index < cards.length - 1) const SizedBox(width: 10),
          ],
        ],
      );
    }

    return SizedBox(
      height: 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: cards.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) => SizedBox(
          width: 172,
          child: cards[index],
        ),
      ),
    );
  }

  List<_CommandSignalData> _commandContextSignals() {
    return [
      _CommandSignalData(
        icon: Icons.payments_outlined,
        label: 'النقدية / Cash',
        value: _firstInsightSignal(['cash', 'payment', 'liquidity']) ??
            'تحتاج بيانات / Needs data',
        color: tealSuccess,
        hasEvidence: _hasInsightSignal(['cash', 'payment', 'liquidity']),
      ),
      _CommandSignalData(
        icon: Icons.trending_up_rounded,
        label: 'الإيرادات / Revenue',
        value: _firstInsightSignal(['revenue', 'sales', 'profit']) ??
            'تحتاج تحليل / Needs analysis',
        color: goldAccent,
        hasEvidence: _hasInsightSignal(['revenue', 'sales', 'profit']),
      ),
      _CommandSignalData(
        icon: Icons.inventory_2_outlined,
        label: 'المخزون / Inventory',
        value: _orchestrator.businessMemory.recentProducts.isEmpty
            ? 'تحتاج بيانات / Needs data'
            : _orchestrator.businessMemory.recentProducts.first,
        color: AppTheme.aiBlue,
        hasEvidence: _orchestrator.businessMemory.recentProducts.isNotEmpty,
      ),
      _CommandSignalData(
        icon: Icons.people_alt_outlined,
        label: 'المستحقات / Receivables',
        value: _orchestrator.memory.latestCustomer ??
            _firstInsightSignal(['receivable', 'customer', 'balance']) ??
            'تحتاج بيانات / Needs data',
        color: const Color(0xFF8B5CF6),
        hasEvidence: _orchestrator.memory.latestCustomer != null ||
            _hasInsightSignal(['receivable', 'customer', 'balance']),
      ),
    ];
  }

  bool _hasInsightSignal(List<String> tokens) =>
      _firstInsightSignal(tokens) != null;

  String? _firstInsightSignal(List<String> tokens) {
    final loweredTokens = tokens.map((token) => token.toLowerCase()).toList();
    final candidates = [
      ..._latestInsights().map((item) => item.title),
      ..._latestRisks().map((item) => item.title),
      ..._latestRecommendations().map((item) => item.title),
    ];

    for (final candidate in candidates) {
      final lowered = candidate.toLowerCase();
      if (loweredTokens.any(lowered.contains)) return candidate;
    }
    return null;
  }

  String _activeCommandFocus() {
    final workflow = _orchestrator.activeWorkflow;
    final proposal = _activeProposal ?? _confirmationProposal;
    final memory = _orchestrator.memory;

    if (proposal != null) {
      return 'Current focus: review ${proposal.actionType} proposal before execution.';
    }
    if (workflow != null) {
      return 'Current focus: ${_workflowTitle(workflow.workflowType)} workflow, step ${workflow.currentStep.clamp(1, workflow.totalSteps)} of ${workflow.totalSteps}.';
    }
    if (memory.latestCustomer != null) {
      return 'Current focus: ${memory.latestCustomer} customer context.';
    }
    if (memory.currentProduct != null) {
      return 'Current focus: ${memory.currentProduct} product context.';
    }
    return 'Current focus: ask for cash, profitability, inventory, or receivables analysis.';
  }

  Color _healthColor(int score) {
    if (score >= 80) return tealSuccess;
    if (score >= 65) return goldAccent;
    return AppTheme.aiRed;
  }

  Widget _buildConversationPanel({required bool isDesktop}) {
    return Container(
      decoration: BoxDecoration(
        color: darkBg.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: premiumStroke),
      ),
      child: Column(
        children: [
          _buildConversationTopBar(isDesktop: isDesktop),
          Expanded(
            child: _messages.isEmpty
                ? _buildPremiumEmptyState()
                : _buildChatTimeline(),
          ),
          if (_isAnalyzing && _messages.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              child: _buildTypingIndicator(),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(14, 0, 14, isDesktop ? 14 : 10),
            child: _buildInputField(),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationTopBar({required bool isDesktop}) {
    return Container(
      padding: EdgeInsets.fromLTRB(isDesktop ? 18 : 12, 12, 12, 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: premiumStroke)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: goldAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: goldAccent.withValues(alpha: 0.24)),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: goldAccent,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'مركز الأوامر المالية',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Financial Command Center',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              _statusPill('AI CFO Beta', goldAccent),
              const SizedBox(width: 8),
              _buildExtractDraftsButton(isDesktop: isDesktop),
              const SizedBox(width: 6),
              if (!isDesktop)
                IconButton(
                  tooltip: 'الأدوات والتنفيذ / Tools & Execution',
                  icon: const Icon(Icons.view_sidebar_outlined,
                      color: textSecondary),
                  onPressed: _showMobileContextSheet,
                )
              else
                _statusPill(
                  _activeProposal != null ? 'Proposal ready' : 'Advisory mode',
                  _activeProposal != null ? goldAccent : tealSuccess,
                ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'اكتب ما حدث في تجارتك، وحاسوب يحوّله إلى حسابات ومسودات وتقارير.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExtractDraftsButton({required bool isDesktop}) {
    final hasDrafts = _workspaceDrafts.isNotEmpty;
    final readyCount =
        _workspaceDrafts.where((d) => d.status == _DraftStatus.ready).length;
    final reviewCount = _workspaceDrafts
        .where((d) => d.status == _DraftStatus.needsReview)
        .length;
    final label = hasDrafts ? '${_workspaceDrafts.length} drafts' : 'Organize';
    final tooltip = hasDrafts
        ? '$readyCount ready · $reviewCount needs review'
        : 'Extract accounting drafts from conversation';

    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: _isExtracting || _isAnalyzing
            ? null
            : () {
                if (!isDesktop) {
                  _showMobileWorkspaceSheet();
                } else {
                  _extractAccountingDrafts();
                }
              },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: hasDrafts
                ? goldAccent.withValues(alpha: 0.13)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color:
                  hasDrafts ? goldAccent.withValues(alpha: 0.4) : premiumStroke,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isExtracting)
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: goldAccent,
                  ),
                )
              else
                Icon(
                  hasDrafts
                      ? Icons.folder_special_outlined
                      : Icons.auto_awesome_outlined,
                  color: hasDrafts ? goldAccent : textSecondary,
                  size: 13,
                ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: hasDrafts ? goldAccent : textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMobileWorkspaceSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          child: FractionallySizedBox(
            heightFactor: 0.86,
            child: Container(
              margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: premiumPanel,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: premiumStroke),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.folder_special_outlined,
                        color: goldAccent,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Accounting Workspace',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Session drafts — not posted to accounting records.',
                              style:
                                  TextStyle(color: textSecondary, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close,
                            color: textSecondary, size: 18),
                        onPressed: () => Navigator.pop(sheetContext),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: SingleChildScrollView(
                      child: StatefulBuilder(
                        builder: (_, sheetSetState) => Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildIntakePanel(),
                            const SizedBox(height: 12),
                            _buildReportActionBar(),
                            const SizedBox(height: 12),
                            _buildWorkspaceDraftsPanel(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showMobileContextSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          child: FractionallySizedBox(
            heightFactor: 0.82,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: _buildRightContextRail(),
            ),
          ),
        );
      },
    );
  }

  // ignore: unused_element
  Widget _buildWorkspaceHeader() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: premiumPanel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: premiumStroke),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: goldAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: goldAccent.withValues(alpha: 0.24)),
            ),
            child: const Icon(
              Icons.account_balance_wallet_outlined,
              color: goldAccent,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'AI Accountant',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Conversation-first workspace',
                  style: TextStyle(
                    color: AppTheme.aiTextSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          _statusPill(
            _activeProposal != null ? 'Proposal ready' : 'Advisory mode',
            _activeProposal != null ? goldAccent : tealSuccess,
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildWorkspaceTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: premiumPanel,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: premiumStroke),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child:
                  CircularProgressIndicator(color: goldAccent, strokeWidth: 2),
            ),
            SizedBox(width: 9),
            Text(
              'AI Accountant is preparing a safe response...',
              style: TextStyle(color: textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommandCenter({required bool isDesktop}) {
    return _buildConversationDominantShell(isDesktop: isDesktop);
  }

  // ignore: unused_element
  Widget _buildAiFirstHero({required bool isDesktop}) {
    final score = _businessHealthScore();
    final hasEvidence = score != null;
    final statusCards = [
      _ExecutiveKpiData(
        label: 'Revenue Status',
        value: hasEvidence
            ? _statusForRisk(_latestRisks(), 'profit')
            : 'Ask about revenue',
        icon: Icons.trending_up_rounded,
        color: hasEvidence ? tealSuccess : textSecondary,
      ),
      _ExecutiveKpiData(
        label: 'Cashflow Status',
        value: hasEvidence
            ? _cashflowStatus(_latestRisks())
            : 'Ask about cash flow',
        icon: Icons.payments_outlined,
        color: hasEvidence ? goldAccent : textSecondary,
      ),
      _ExecutiveKpiData(
        label: 'Inventory Status',
        value: hasEvidence
            ? _inventoryStatus(_latestRisks())
            : 'Ask about inventory',
        icon: Icons.inventory_2_outlined,
        color: hasEvidence ? tealSuccess : textSecondary,
      ),
      _ExecutiveKpiData(
        label: 'Receivables Status',
        value: hasEvidence
            ? _receivablesStatus(_latestRisks())
            : 'Ask about balances',
        icon: Icons.receipt_long_outlined,
        color: hasEvidence ? AppTheme.warning : textSecondary,
      ),
    ];

    return Container(
      padding: EdgeInsets.all(isDesktop ? 26 : 18),
      decoration: BoxDecoration(
        color: premiumPanel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: premiumStroke),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: isDesktop
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 5,
                  child: _buildAiHeroStatement(
                    score,
                    compact: false,
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(flex: 6, child: _buildHealthKpiGrid(statusCards, 4)),
              ],
            )
          : _buildAiHeroStatement(
              score,
              compact: true,
            ),
    );
  }

  Widget _buildAiHeroStatement(int? score, {required bool compact}) {
    final hasScore = score != null;
    return Container(
      padding: EdgeInsets.all(compact ? 14 : 18),
      decoration: BoxDecoration(
        color: AppTheme.aiDeep.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasScore ? goldAccent.withValues(alpha: 0.3) : premiumStroke,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'AI Accountant',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Your financial advisor inside HASOOB',
            style: TextStyle(
              color: goldAccent,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            hasScore
                ? 'Business health: $score / 100. Ask me what changed, what is risky, or what to do next.'
                : 'Talk to me like your accountant. I can analyze profitability, monitor cash flow, detect risks, review balances, track inventory, and prepare proposals safely.',
            style: const TextStyle(
              color: textSecondary,
              fontSize: 12,
              height: 1.45,
            ),
            maxLines: compact ? 4 : null,
            overflow: compact ? TextOverflow.ellipsis : null,
          ),
          SizedBox(height: compact ? 10 : 14),
          _buildStarterPromptWrap(compact: compact),
        ],
      ),
    );
  }

  Widget _buildHealthKpiGrid(List<_ExecutiveKpiData> cards, int columns) {
    return GridView.count(
      crossAxisCount: columns,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: columns == 4 ? 1.18 : 1.08,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: cards.map((data) => _ExecutiveKpiCard(data: data)).toList(),
    );
  }

  Widget _buildStarterPromptWrap({required bool compact}) {
    final prompts = [
      ('What should I focus on today?', Icons.today_outlined),
      ('How is my business doing?', Icons.query_stats_outlined),
      ('What is the first risk I should check?', Icons.warning_amber_outlined),
      ('What data is missing before I decide?', Icons.fact_check_outlined),
      ('What should I do next?', Icons.route_outlined),
    ];
    if (compact) {
      return SizedBox(
        height: 38,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: prompts.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final prompt = prompts[index];
            return Command360StarterQuestionChip(
              label: prompt.$1,
              icon: prompt.$2,
              onPressed: _isAnalyzing || _isCommitting
                  ? null
                  : () => _processAiCommand(customText: prompt.$1),
            );
          },
        ),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: prompts.map((prompt) {
        return Command360StarterQuestionChip(
          label: prompt.$1,
          icon: prompt.$2,
          onPressed: _isAnalyzing || _isCommitting
              ? null
              : () => _processAiCommand(customText: prompt.$1),
        );
      }).toList(),
    );
  }

  // ignore: unused_element
  Widget _buildAiDetectedCommandSection() {
    final findings = _executiveFindings();
    return _CommandSection(
      title: 'AI Detected',
      subtitle: 'Automatic findings from existing risks and insights.',
      trailing: _statusPill(
        findings.isEmpty ? 'Clear' : '${findings.length} findings',
        findings.isEmpty ? tealSuccess : goldAccent,
      ),
      child: findings.isEmpty
          ? const _ExecutiveEmptyLine(
              icon: Icons.verified_outlined,
              label: 'No critical issues detected',
            )
          : Wrap(
              spacing: 10,
              runSpacing: 10,
              children: findings
                  .map((finding) => _ExecutiveFindingTile(label: finding))
                  .toList(),
            ),
    );
  }

  // ignore: unused_element
  Widget _buildAiRecommendationsCommandSection({required bool isDesktop}) {
    final recommendations = _latestRecommendations().take(3).toList();
    if (recommendations.isEmpty) {
      return const _CommandSection(
        title: 'AI Recommendations',
        subtitle:
            'Ask the AI Accountant for analysis to generate next actions.',
        child: _ExecutiveEmptyLine(
          icon: Icons.lightbulb_outline,
          label: 'Try: "How is my business doing?"',
        ),
      );
    }

    return _CommandSection(
      title: 'AI Recommendations',
      subtitle: 'Top 3 actions only.',
      trailing: _statusPill('Top 3', tealSuccess),
      child: GridView.count(
        crossAxisCount: isDesktop ? 3 : 1,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: isDesktop ? 3.1 : 4.1,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: recommendations
            .map((item) => _ExecutiveRecommendationCard(item: item))
            .toList(),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildAskAiCommandSection({required bool isDesktop}) {
    return _CommandSection(
      title: 'Ask AI Accountant',
      subtitle:
          'Type a question, ask for analysis, or prepare a guarded proposal.',
      trailing: _activeProposal != null
          ? _statusPill('Proposal ready', goldAccent)
          : _statusPill('Advisory mode', tealSuccess),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildDominantInput(),
          const SizedBox(height: 12),
          _buildQuickActions(),
          const SizedBox(height: 12),
          SizedBox(
            height: isDesktop ? 390 : 360,
            child: Container(
              decoration: BoxDecoration(
                color: darkBg.withValues(alpha: 0.52),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: premiumStroke),
              ),
              child: _messages.isEmpty
                  ? _buildPremiumEmptyState()
                  : _buildChatTimeline(),
            ),
          ),
          if (_isAnalyzing) _buildTypingIndicator(),
        ],
      ),
    );
  }

  Widget _buildDominantInput() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: goldAccent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: goldAccent.withValues(alpha: 0.26)),
      ),
      child: _buildInputField(),
    );
  }

  // ignore: unused_element
  Widget _buildContextTabsCommandSection({required bool isDesktop}) {
    return _CommandSection(
      title: 'Context Tabs',
      subtitle:
          'Overview, memory, and ledger are separated into one view at a time.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildContextTabBar(),
          const SizedBox(height: 12),
          SizedBox(
            height: isDesktop ? 330 : 300,
            child: _buildContextTabBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildContextTabBar() {
    final tabs = [
      (Icons.dashboard_outlined, 'Overview'),
      (Icons.memory_outlined, 'Memory'),
      (Icons.account_balance_outlined, 'Ledger'),
    ];
    return Row(
      children: [
        for (var i = 0; i < tabs.length; i++) ...[
          Expanded(
            child: Command360ExecutiveTabButton(
              icon: tabs[i].$1,
              label: tabs[i].$2,
              selected: _contextTabIndex == i,
              onPressed: () => setState(() => _contextTabIndex = i),
            ),
          ),
          if (i != tabs.length - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }

  Widget _buildContextTabBody() {
    switch (_contextTabIndex) {
      case 1:
        return SingleChildScrollView(
          child: _buildBusinessMemoryPanel(_orchestrator.businessMemory),
        );
      case 2:
        return _buildLedgerPanel(isCompact: true, embedded: true);
      case 0:
      default:
        return SingleChildScrollView(
            child: _buildContextSummary(compact: true));
    }
  }

  int? _businessHealthScore() {
    final metadata = _latestMetadata();
    if (metadata == null || metadata.evidenceCount == 0) return null;

    var score = switch (metadata.confidenceLevel) {
      AiEvidenceConfidence.high => 87,
      AiEvidenceConfidence.medium => 74,
      AiEvidenceConfidence.low => 58,
    };

    for (final risk in _latestRisks()) {
      switch (risk.level) {
        case AiFinancialRiskLevel.high:
          score -= 18;
          break;
        case AiFinancialRiskLevel.medium:
          score -= 10;
          break;
        case AiFinancialRiskLevel.low:
          if (risk.title != 'No major risk detected') score -= 4;
          break;
      }
    }
    return score.clamp(0, 100);
  }

  AiResponseMetadata? _latestMetadata() {
    for (final message in _messages.reversed) {
      if (message.metadata != null) return message.metadata;
    }
    return null;
  }

  String _latestConfidenceLabel() {
    final metadata = _latestMetadata();
    return metadata == null ? 'Ready to analyze' : metadata.confidenceLabel;
  }

  List<AiFinancialRisk> _latestRisks() {
    for (final message in _messages.reversed) {
      if (message.risks.isNotEmpty) return message.risks;
    }
    return const [];
  }

  List<AiFinancialInsight> _latestInsights() {
    for (final message in _messages.reversed) {
      if (message.insights.isNotEmpty) return message.insights;
    }
    return const [];
  }

  List<AiFinancialRecommendation> _latestRecommendations() {
    for (final message in _messages.reversed) {
      if (message.recommendations.isNotEmpty) {
        return message.recommendations;
      }
    }
    return const [];
  }

  List<String> _executiveFindings() {
    final risks = _latestRisks()
        .where((risk) => risk.title != 'No major risk detected')
        .map((risk) => risk.title)
        .toList();
    final insights = _latestInsights().map((insight) => insight.title).toList();
    return [...risks, ...insights].take(5).toList(growable: false);
  }

  String _statusForRisk(List<AiFinancialRisk> risks, String keyword) {
    final lowerKeyword = keyword.toLowerCase();
    final hasRisk = risks.any((risk) {
      final text = '${risk.title} ${risk.description}'.toLowerCase();
      return text.contains(lowerKeyword);
    });
    return hasRisk ? 'Needs Review' : 'Stable';
  }

  String _cashflowStatus(List<AiFinancialRisk> risks) {
    final hasRisk = risks.any((risk) {
      final text = '${risk.title} ${risk.description}'.toLowerCase();
      return text.contains('cash') ||
          text.contains('invoice') ||
          text.contains('balance');
    });
    return hasRisk ? 'Watch Closely' : 'Stable';
  }

  String _inventoryStatus(List<AiFinancialRisk> risks) {
    final hasRisk = risks.any((risk) {
      final text = '${risk.title} ${risk.description}'.toLowerCase();
      return text.contains('stock') || text.contains('inventory');
    });
    return hasRisk ? 'Needs Attention' : 'Healthy';
  }

  String _receivablesStatus(List<AiFinancialRisk> risks) {
    final hasRisk = risks.any((risk) {
      final text = '${risk.title} ${risk.description}'.toLowerCase();
      return text.contains('invoice') ||
          text.contains('customer') ||
          text.contains('receivable') ||
          text.contains('balance');
    });
    return hasRisk ? 'Needs Follow-Up' : 'Stable';
  }

  Widget _buildPremiumHeader({required bool isDesktop}) {
    return Container(
      margin:
          EdgeInsets.fromLTRB(isDesktop ? 20 : 12, 12, isDesktop ? 20 : 12, 0),
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 20 : 14,
        vertical: isDesktop ? 18 : 14,
      ),
      decoration: BoxDecoration(
        color: premiumPanel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: premiumStroke),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.24),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: goldAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: goldAccent.withValues(alpha: 0.24)),
            ),
            child: const Icon(
              Icons.account_balance_wallet_outlined,
              color: goldAccent,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'AI Accountant',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 19,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _miniStatusDot(tealSuccess),
                    const Text(
                      'Ready',
                      style: TextStyle(color: textSecondary, fontSize: 12),
                    ),
                    const Text(
                      '•',
                      style:
                          TextStyle(color: AppTheme.aiTextMuted, fontSize: 12),
                    ),
                    const Text(
                      'Context Loaded',
                      style: TextStyle(color: textSecondary, fontSize: 12),
                    ),
                    _statusPill('AI CFO Beta', goldAccent),
                  ],
                ),
              ],
            ),
          ),
          if (isDesktop) ...[
            _headerMetric('Confidence', _latestConfidenceLabel()),
            const SizedBox(width: 10),
          ],
          _statusPill(
            _activeProposal != null ? 'Proposal ready' : 'Safe advisory mode',
            _activeProposal != null ? goldAccent : tealSuccess,
          ),
        ],
      ),
    );
  }

  Widget _miniStatusDot(Color color) {
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  Widget _headerMetric(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: premiumPanelSoft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: premiumStroke),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(color: textSecondary, fontSize: 11),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildTopFinancialRibbon() {
    return SafeArea(
      bottom: false,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        decoration: const BoxDecoration(
          color: darkSurface,
          border: Border(bottom: BorderSide(color: borderTerminal)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.account_balance_wallet_outlined,
              color: goldAccent,
              size: 20,
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'HASOOB | AI Accountant Advisor',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  letterSpacing: 0,
                ),
              ),
            ),
            _statusPill('Review before execution', tealSuccess),
          ],
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildContextPanel() {
    return Container(
      decoration: BoxDecoration(
        color: premiumPanel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: premiumStroke),
      ),
      child: Column(
        children: [
          _buildContextSummary(),
          const Divider(color: premiumStroke, height: 1),
          Expanded(child: _buildLedgerPanel(isCompact: true, embedded: true)),
        ],
      ),
    );
  }

  // ── Accounting Workspace — Extraction Logic ──────────────────────────────

  void _extractAccountingDrafts() {
    if (_isExtracting) return;
    setState(() => _isExtracting = true);

    final meaningfulMessages =
        _messages.where((m) => m.text.trim().length > 20).toList();

    if (meaningfulMessages.isEmpty) {
      setState(() {
        _workspaceDrafts.clear();
        _isExtracting = false;
      });
      return;
    }

    final allText =
        meaningfulMessages.map((m) => m.text).join(' ').toLowerCase();

    final drafts = <_AccountingDraft>[];

    // 1. Invoice / document draft
    final invoiceKeywords = [
      'invoice',
      'bill',
      'receipt',
      'quotation',
      'payment',
      'due date',
      'customer',
      'supplier',
      'amount',
      'vat',
      'tax',
      'paid',
      'unpaid',
      'collection',
    ];
    if (_containsAny(allText, invoiceKeywords)) {
      final amount = _extractFirstAmountFromText(allText);
      final customer = _extractCustomerHintFromText();
      final missing = <String>[
        if (customer == null) 'Customer / Supplier name',
        if (amount == null) 'Amount',
        'Currency',
        'Due date',
        'VAT / Tax status',
        'Payment status',
      ];
      drafts.add(_AccountingDraft(
        id: 'draft-invoice-${drafts.length}',
        type: _DraftType.invoice,
        source: _DraftSource.chat,
        title: 'Invoice / Document Draft',
        summary:
            'Conversation mentions invoice or payment topics. Complete missing fields before saving.',
        status: (amount != null && customer != null)
            ? _DraftStatus.draft
            : _DraftStatus.needsReview,
        confidence: (amount != null && customer != null)
            ? _DraftConfidence.medium
            : _DraftConfidence.low,
        sourceSummary: 'Extracted from chat',
        amount: amount,
        customerOrSupplier: customer,
        missingInfo: missing,
        recommendedNextAction:
            'Provide customer, amount, due date, and VAT status. Mark Ready when complete.',
      ));
    }

    // 2. Account entry draft
    final accountKeywords = [
      'cash',
      'bank',
      'receivable',
      'payable',
      'expense',
      'revenue',
      'capital',
      'liability',
      'asset',
      'account',
      'balance',
      'reconciliation',
    ];
    if (_containsAny(allText, accountKeywords)) {
      drafts.add(_AccountingDraft(
        id: 'draft-account-${drafts.length}',
        type: _DraftType.account,
        source: _DraftSource.chat,
        title: 'Account Entry Draft',
        summary:
            'Conversation mentions accounting entries, balances, or classifications.',
        status: _DraftStatus.needsReview,
        confidence: _DraftConfidence.medium,
        sourceSummary: 'Extracted from chat',
        category: _extractAccountCategoryFromText(allText),
        missingInfo: const [
          'Account name',
          'Amount / Balance',
          'Classification',
          'Period'
        ],
        recommendedNextAction:
            'Confirm account name, amount, and classification. Review before reporting.',
      ));
    }

    // 3. Report draft
    final reportKeywords = [
      'sales',
      'profit',
      'loss',
      'margin',
      'inventory',
      'stock',
      'business health',
      'monthly summary',
      'financial position',
      'performance',
    ];
    if (_containsAny(allText, reportKeywords)) {
      drafts.add(_AccountingDraft(
        id: 'draft-report-${drafts.length}',
        type: _DraftType.report,
        source: _DraftSource.chat,
        title: 'Financial Report Draft',
        summary:
            'Conversation covers financial analysis topics that could form a report.',
        status: _DraftStatus.draft,
        confidence: _DraftConfidence.medium,
        sourceSummary: 'Extracted from chat',
        category: _extractReportCategoryFromText(allText),
        missingInfo: const [
          'Report period',
          'Source data',
          'Key figures',
          'Conclusion'
        ],
        recommendedNextAction:
            'Confirm period and figures, then generate the Session Report.',
      ));
    }

    // 4. Task draft
    final taskKeywords = [
      'follow up',
      'collect',
      'pay',
      'prepare',
      'review',
      'check',
      'reconcile',
      'remind',
      'call',
      'send',
      'approve',
      'action',
      'next step',
    ];
    if (_containsAny(allText, taskKeywords)) {
      drafts.add(_AccountingDraft(
        id: 'draft-task-${drafts.length}',
        type: _DraftType.task,
        source: _DraftSource.chat,
        title: 'Follow-up Task Draft',
        summary: 'Conversation contains action items or follow-up reminders.',
        status: _DraftStatus.needsReview,
        confidence: _DraftConfidence.medium,
        sourceSummary: 'Extracted from chat',
        missingInfo: const [
          'Task owner',
          'Due date',
          'Exact action',
          'Related customer / document'
        ],
        recommendedNextAction:
            'Define the action, due date, and responsible party. Mark Ready.',
      ));
    }

    // 5. Note draft
    if (meaningfulMessages.length >= 2) {
      final firstUserText = _messages
          .where((m) => m.role == AiChatRole.user && m.text.trim().isNotEmpty)
          .map((m) => m.text.trim())
          .firstOrNull;
      final noteText = firstUserText != null && firstUserText.length > 80
          ? '${firstUserText.substring(0, 80)}…'
          : (firstUserText ?? 'Session notes from AI CFO conversation.');
      drafts.add(_AccountingDraft(
        id: 'draft-note-${drafts.length}',
        type: _DraftType.note,
        source: _DraftSource.chat,
        title: 'Conversation Note',
        summary: noteText,
        details: 'Full session — ${_messages.length} messages exchanged.',
        status: _DraftStatus.draft,
        confidence: _DraftConfidence.high,
        sourceSummary: '${_messages.length} messages',
        recommendedNextAction:
            'Generate the Session Report to archive this conversation.',
      ));
    }

    if (drafts.isEmpty && meaningfulMessages.isNotEmpty) {
      drafts.add(_AccountingDraft(
        id: 'draft-note-0',
        type: _DraftType.note,
        source: _DraftSource.chat,
        title: 'Conversation Note',
        summary:
            'Discuss invoices, cash flow, receivables, expenses, or decisions to extract structured drafts.',
        status: _DraftStatus.draft,
        confidence: _DraftConfidence.low,
        sourceSummary: '${_messages.length} messages',
        recommendedNextAction:
            'Continue chatting about specific financial topics.',
      ));
    }

    setState(() {
      _workspaceDrafts
        ..clear()
        ..addAll(drafts);
      _workspaceTabIndex = 0;
      _isExtracting = false;
    });
  }

  double? _extractFirstAmountFromText(String text) {
    final match = RegExp(r'(\d{2,}(?:[.,]\d+)?)').firstMatch(text);
    if (match == null) return null;
    return double.tryParse(match.group(1)!.replaceAll(',', '.'));
  }

  String? _extractCustomerHintFromText() {
    final memory = _orchestrator.memory;
    if (memory.latestCustomer != null) return memory.latestCustomer;
    final bm = _orchestrator.businessMemory;
    if (bm.recentCustomers.isNotEmpty) return bm.recentCustomers.first;
    return null;
  }

  String? _extractAccountCategoryFromText(String text) {
    if (_containsAny(text, ['cash', 'bank'])) return 'Cash / Bank';
    if (_containsAny(text, ['receivable'])) return 'Receivables';
    if (_containsAny(text, ['payable'])) return 'Payables';
    if (_containsAny(text, ['expense', 'cost'])) return 'Expenses';
    if (_containsAny(text, ['revenue', 'income'])) return 'Revenue';
    return null;
  }

  String? _extractReportCategoryFromText(String text) {
    if (_containsAny(text, ['profit', 'loss', 'margin']))
      return 'Profit & Loss';
    if (_containsAny(text, ['inventory', 'stock'])) return 'Inventory';
    if (_containsAny(text, ['cash'])) return 'Cash Flow';
    if (_containsAny(text, ['sales'])) return 'Sales Report';
    return 'Financial Summary';
  }

  void _markDraftReady(_AccountingDraft draft) {
    setState(() {
      final index = _workspaceDrafts.indexWhere((d) => d.id == draft.id);
      if (index >= 0) {
        _workspaceDrafts[index] = draft.copyWithStatus(_DraftStatus.ready);
      }
    });
  }

  void _markDraftNeedsReview(_AccountingDraft draft) {
    setState(() {
      final index = _workspaceDrafts.indexWhere((d) => d.id == draft.id);
      if (index >= 0) {
        _workspaceDrafts[index] =
            draft.copyWithStatus(_DraftStatus.needsReview);
      }
    });
  }

  // ── Accounting Workspace — UI Builders ────────────────────────────────────

  Widget _buildWorkspaceDraftsPanel() {
    final tabs = [
      'All',
      'Invoices',
      'Accounts',
      'Reports',
      'Tasks',
      'Notes',
      'Review Queue',
    ];
    final visibleDrafts = _draftsForTab(_workspaceTabIndex);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Action bar
        Row(
          children: [
            Expanded(
              child: Text(
                _workspaceDrafts.isEmpty
                    ? 'No drafts yet'
                    : '${_workspaceDrafts.length} draft${_workspaceDrafts.length == 1 ? '' : 's'}',
                style: const TextStyle(color: textSecondary, fontSize: 11),
              ),
            ),
            if (_workspaceDrafts.isNotEmpty)
              GestureDetector(
                onTap: () => setState(() => _workspaceDrafts.clear()),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    'Clear',
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            GestureDetector(
              onTap: _isExtracting || _isAnalyzing
                  ? null
                  : _extractAccountingDrafts,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: goldAccent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: goldAccent.withValues(alpha: 0.38)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isExtracting)
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: goldAccent,
                        ),
                      )
                    else
                      const Icon(Icons.auto_awesome_outlined,
                          size: 12, color: goldAccent),
                    const SizedBox(width: 5),
                    Text(
                      _workspaceDrafts.isEmpty
                          ? 'Extract drafts'
                          : 'Re-extract',
                      style: const TextStyle(
                        color: goldAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (_workspaceDrafts.isNotEmpty) ...[
          const SizedBox(height: 10),
          // Tab filter row
          SizedBox(
            height: 30,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: tabs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 5),
              itemBuilder: (context, i) {
                final count = i == 0
                    ? _workspaceDrafts.length
                    : i == 6
                        ? _workspaceDrafts
                            .where((d) => d.status == _DraftStatus.needsReview)
                            .length
                        : _workspaceDrafts
                            .where((d) => d.type.index == i - 1)
                            .length;
                final selected = _workspaceTabIndex == i;
                return GestureDetector(
                  onTap: () => setState(() => _workspaceTabIndex = i),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: selected
                          ? goldAccent.withValues(alpha: 0.18)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: selected
                            ? goldAccent.withValues(alpha: 0.5)
                            : premiumStroke,
                      ),
                    ),
                    child: Text(
                      count > 0 ? '${tabs[i]} ($count)' : tabs[i],
                      style: TextStyle(
                        color: selected ? goldAccent : textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          if (visibleDrafts.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'No drafts in this section.',
                style: TextStyle(color: textSecondary, fontSize: 11),
              ),
            )
          else
            ...visibleDrafts.map(_buildDraftCard),
        ] else if (!_isExtracting) ...[
          const SizedBox(height: 8),
          _buildWorkspaceEmptyState(),
        ],
      ],
    );
  }

  List<_AccountingDraft> _draftsForTab(int tabIndex) {
    if (tabIndex == 0) return List.from(_workspaceDrafts);
    if (tabIndex == 6) {
      return _workspaceDrafts
          .where((d) => d.status == _DraftStatus.needsReview)
          .toList();
    }
    final type = _DraftType.values[tabIndex - 1];
    return _workspaceDrafts.where((d) => d.type == type).toList();
  }

  Widget _buildWorkspaceEmptyState() {
    return const _EmptyHint(
      icon: Icons.folder_open_outlined,
      title: 'No drafts yet',
      body: 'Create your first draft using any of these 4 intake modules:\n\n'
          '📄 Document — Paste invoice / receipt / quotation text\n'
          '⚡ Transaction — Record a quick sale, expense, or payment\n'
          '👤 Receivable — Log customer follow-ups or expected payments\n'
          '💳 Payable/Exp — Log supplier payables or expense notes\n\n'
          'Nothing is posted to accounting records until you explicitly approve it.',
    );
  }

  Widget _buildDraftCard(_AccountingDraft draft) {
    final isLocalCommandDraft = _isLocalCommandDraft(draft);
    final visibleSourceLabel =
        isLocalCommandDraft ? 'من أمر محاسبي' : draft.sourceLabel;
    final visibleStatusLabel =
        isLocalCommandDraft ? 'بانتظار المراجعة' : draft.statusLabel;
    final statusColor = switch (draft.status) {
      _DraftStatus.ready => tealSuccess,
      _DraftStatus.needsReview => goldAccent,
      _DraftStatus.draft => textSecondary,
    };
    final confidenceColor = switch (draft.confidence) {
      _DraftConfidence.high => tealSuccess,
      _DraftConfidence.medium => goldAccent,
      _DraftConfidence.low => AppTheme.aiRed,
    };

    return GestureDetector(
      onTap: () => _showDraftDetailSheet(draft),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: darkBg.withValues(alpha: 0.52),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: statusColor.withValues(alpha: 0.22)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(draft.typeIcon, color: goldAccent, size: 14),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    draft.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: premiumPanelSoft,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                  visibleSourceLabel,
                    style: const TextStyle(
                        color: textSecondary,
                        fontSize: 8,
                        fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(4),
                    border:
                        Border.all(color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                  visibleStatusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              draft.summary,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: textSecondary,
                fontSize: 10.5,
                height: 1.35,
              ),
            ),
            if (draft.amount != null ||
                draft.customerOrSupplier != null ||
                draft.category != null) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 5,
                runSpacing: 4,
                children: [
                  if (draft.amount != null)
                    _draftMetaChip(
                      Icons.payments_outlined,
                      '${draft.amount!.toStringAsFixed(2)} ${draft.currency ?? ''}',
                    ),
                  if (draft.customerOrSupplier != null)
                    _draftMetaChip(
                      Icons.person_outline,
                      draft.customerOrSupplier!,
                    ),
                  if (draft.category != null)
                    _draftMetaChip(Icons.label_outline, draft.category!),
                ],
              ),
            ],
            if (draft.sourceSummary != null) ...[
              const SizedBox(height: 4),
              Text(
                draft.sourceSummary!,
                style: const TextStyle(
                  color: AppTheme.aiTextMuted,
                  fontSize: 9,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: confidenceColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${draft.confidenceLabel} confidence',
                    style: TextStyle(color: confidenceColor, fontSize: 9),
                  ),
                ),
                const Spacer(),
                if (draft.status != _DraftStatus.ready)
                  GestureDetector(
                    onTap: () => _markDraftReady(draft),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: tealSuccess.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                            color: tealSuccess.withValues(alpha: 0.3)),
                      ),
                      child: const Text(
                      'مراجعة',
                        style: TextStyle(
                          color: tealSuccess,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  )
                else
                  GestureDetector(
                    onTap: () => _markDraftNeedsReview(draft),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: goldAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                            color: goldAccent.withValues(alpha: 0.3)),
                      ),
                      child: const Text(
                      'بانتظار المراجعة',
                        style: TextStyle(
                          color: goldAccent,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 5),
            Row(children: [
              const Expanded(
                child: Text(
                  'Session draft only — not posted to accounting records.',
                  style: TextStyle(
                      color: AppTheme.aiTextMuted, fontSize: 9, height: 1.3),
                ),
              ),
              const SizedBox(width: 4),
              const Text('Edit ›',
                  style: TextStyle(
                      color: AppTheme.aiTextSecondary,
                      fontSize: 9,
                      fontWeight: FontWeight.w800)),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _draftMetaChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: premiumPanelSoft,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: premiumStroke),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 9, color: textSecondary),
          const SizedBox(width: 3),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 9),
          ),
        ],
      ),
    );
  }

  // ── Intake Callback ───────────────────────────────────────────────────────

  bool _isLocalCommandDraft(_AccountingDraft draft) {
    return draft.sourceSummary?.startsWith('local accounting command') ?? false;
  }

  void _addLocalCommandDraftIfAvailable(LocalAccountingCommandDraft? command) {
    if (command == null || !command.isReviewable) return;
    final draft = _draftFromLocalAccountingCommand(command);
    setState(() {
      _workspaceDrafts.add(draft);
      _workspaceTabIndex = 0;
    });
  }

  _AccountingDraft _draftFromLocalAccountingCommand(
    LocalAccountingCommandDraft command,
  ) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return switch (command.type) {
      LocalAccountingCommandDraftType.sale => _AccountingDraft(
          id: 'local-sale-$now',
          type: _DraftType.account,
          source: _DraftSource.chat,
          title: command.isArabic ? 'مسودة بيع' : 'Sale draft',
          summary: command.isArabic
              ? 'مسودة بيع بانتظار المراجعة. لن يتم التسجيل قبل الاعتماد.'
              : 'Sale draft. Pending review. Nothing will be posted before approval.',
          details: _localSaleDraftDetails(command),
          status: _DraftStatus.needsReview,
          confidence: _DraftConfidence.high,
          sourceSummary: command.source,
          amount: command.revenue,
          category: command.isArabic ? 'بيع' : 'Sale',
          missingInfo: const [],
          recommendedNextAction: command.isArabic
              ? 'راجع المسودة قبل أي تنفيذ.'
              : 'Review before execution.',
        ),
      LocalAccountingCommandDraftType.expense => _AccountingDraft(
          id: 'local-expense-$now',
          type: _DraftType.account,
          source: _DraftSource.chat,
          title: command.isArabic ? 'مسودة مصروف' : 'Expense draft',
          summary: command.isArabic
              ? 'مسودة مصروف بانتظار المراجعة. لن يتم التسجيل قبل الاعتماد.'
              : 'Expense draft. Pending review. Nothing will be posted before approval.',
          details: _localExpenseDraftDetails(command),
          status: _DraftStatus.needsReview,
          confidence: _DraftConfidence.high,
          sourceSummary: command.source,
          amount: command.amount,
          category: command.isArabic
              ? command.categoryArabic
              : _capitalizeDraftLabel(command.categoryEnglish),
          missingInfo: const [],
          recommendedNextAction: command.isArabic
              ? 'راجع المسودة قبل أي تنفيذ.'
              : 'Review before execution.',
        ),
      LocalAccountingCommandDraftType.purchase => _AccountingDraft(
          id: 'local-purchase-$now',
          type: _DraftType.account,
          source: _DraftSource.chat,
          title: command.isArabic ? 'مسودة شراء' : 'Purchase draft',
          summary: command.isArabic
              ? 'مسودة شراء بانتظار المراجعة. لن يتم التسجيل قبل الاعتماد.'
              : 'Purchase draft. Pending review. Nothing will be posted before approval.',
          details: _localPurchaseDraftDetails(command),
          status: _DraftStatus.needsReview,
          confidence: _DraftConfidence.high,
          sourceSummary: command.source,
          amount: command.totalCost,
          category: command.isArabic ? 'شراء' : 'Purchase',
          missingInfo: const [],
          recommendedNextAction: command.isArabic
              ? 'راجع المسودة قبل أي تنفيذ.'
              : 'Review before execution.',
        ),
      LocalAccountingCommandDraftType.inventoryIntake => _AccountingDraft(
          id: 'local-inventory-intake-$now',
          type: _DraftType.account,
          source: _DraftSource.chat,
          title:
              command.isArabic ? 'مسودة إدخال مخزون' : 'Inventory intake draft',
          summary: command.isArabic
              ? 'مسودة إدخال مخزون بانتظار المراجعة. لن يتم تحديث المخزون قبل الاعتماد.'
              : 'Inventory intake draft. Pending review. Stock will not be updated before approval.',
          details: _localPurchaseDraftDetails(command),
          status: _DraftStatus.needsReview,
          confidence: _DraftConfidence.high,
          sourceSummary: command.source,
          amount: command.totalCost,
          category: command.isArabic ? 'إدخال مخزون' : 'Inventory intake',
          missingInfo: const [],
          recommendedNextAction: command.isArabic
              ? 'راجع المسودة قبل أي تنفيذ.'
              : 'Review before execution.',
        ),
      LocalAccountingCommandDraftType.receivable => _AccountingDraft(
          id: 'local-receivable-$now',
          type: _DraftType.account,
          source: _DraftSource.chat,
          title: command.isArabic ? 'مسودة ذمم مدينة' : 'Receivable draft',
          summary: command.isArabic
              ? 'مسودة ذمم مدينة بانتظار المراجعة. لن يتم تعديل رصيد العميل قبل الاعتماد.'
              : 'Receivable draft. Pending review. Customer balance will not be updated before approval.',
          details: _localPartyDraftDetails(command),
          status: _DraftStatus.needsReview,
          confidence: _DraftConfidence.high,
          sourceSummary: command.source,
          amount: command.amount,
          customerOrSupplier: command.partyName,
          category: command.isArabic ? 'ذمم مدينة' : 'Receivable',
          missingInfo: const [],
          recommendedNextAction: command.isArabic
              ? 'راجع المسودة قبل أي تنفيذ.'
              : 'Review before execution.',
        ),
      LocalAccountingCommandDraftType.customerReceipt => _AccountingDraft(
          id: 'local-customer-receipt-$now',
          type: _DraftType.account,
          source: _DraftSource.chat,
          title:
              command.isArabic ? 'مسودة قبض من عميل' : 'Customer receipt draft',
          summary: command.isArabic
              ? 'مسودة قبض من عميل بانتظار المراجعة. لن يتم تسجيل القبض قبل الاعتماد.'
              : 'Customer receipt draft. Pending review. Receipt will not be posted before approval.',
          details: _localPartyDraftDetails(command),
          status: _DraftStatus.needsReview,
          confidence: _DraftConfidence.high,
          sourceSummary: command.source,
          amount: command.amount,
          customerOrSupplier: command.partyName,
          category: command.isArabic ? 'قبض من عميل' : 'Customer receipt',
          missingInfo: const [],
          recommendedNextAction: command.isArabic
              ? 'راجع المسودة قبل أي تنفيذ.'
              : 'Review before execution.',
        ),
      LocalAccountingCommandDraftType.supplierPayable => _AccountingDraft(
          id: 'local-supplier-payable-$now',
          type: _DraftType.account,
          source: _DraftSource.chat,
          title: command.isArabic ? 'مسودة ذمم دائنة' : 'Supplier payable draft',
          summary: command.isArabic
              ? 'مسودة ذمم دائنة بانتظار المراجعة. لن يتم تعديل رصيد المورد قبل الاعتماد.'
              : 'Supplier payable draft. Pending review. Supplier balance will not be updated before approval.',
          details: _localPartyDraftDetails(command),
          status: _DraftStatus.needsReview,
          confidence: _DraftConfidence.high,
          sourceSummary: command.source,
          amount: command.amount,
          customerOrSupplier: command.partyName,
          category: command.isArabic ? 'ذمم دائنة' : 'Supplier payable',
          missingInfo: const [],
          recommendedNextAction: command.isArabic
              ? 'راجع المسودة قبل أي تنفيذ.'
              : 'Review before execution.',
        ),
      LocalAccountingCommandDraftType.supplierPayment => _AccountingDraft(
          id: 'local-supplier-payment-$now',
          type: _DraftType.account,
          source: _DraftSource.chat,
          title: command.isArabic ? 'مسودة دفع لمورد' : 'Supplier payment draft',
          summary: command.isArabic
              ? 'مسودة دفع لمورد بانتظار المراجعة. لن يتم تسجيل الدفع قبل الاعتماد.'
              : 'Supplier payment draft. Pending review. Supplier payment will not be posted before approval.',
          details: _localPartyDraftDetails(command),
          status: _DraftStatus.needsReview,
          confidence: _DraftConfidence.high,
          sourceSummary: command.source,
          amount: command.amount,
          customerOrSupplier: command.partyName,
          category: command.isArabic ? 'دفع لمورد' : 'Supplier payment',
          missingInfo: const [],
          recommendedNextAction: command.isArabic
              ? 'راجع المسودة قبل أي تنفيذ.'
              : 'Review before execution.',
        ),
    };
  }

  String _localSaleDraftDetails(LocalAccountingCommandDraft command) {
    if (command.isArabic) {
      return [
        'الكمية: ${_formatDraftNumber(command.quantity)}',
        'سعر البيع للوحدة: ${_formatDraftNumber(command.unitSellingPrice)}',
        'تكلفة الوحدة: ${_formatDraftNumber(command.unitCost)}',
        'الإيراد: ${_formatDraftNumber(command.revenue)}',
        'التكلفة: ${_formatDraftNumber(command.totalCost)}',
        'الربح: ${_formatDraftNumber(command.profit)}',
        'هامش الربح: ${_formatDraftNumber(command.marginPercent)}%',
        'لن يتم التسجيل قبل الاعتماد.',
      ].join('\n');
    }
    return [
      'Quantity: ${_formatDraftNumber(command.quantity)}',
      'Unit selling price: ${_formatDraftNumber(command.unitSellingPrice)}',
      'Unit cost: ${_formatDraftNumber(command.unitCost)}',
      'Revenue: ${_formatDraftNumber(command.revenue)}',
      'Total cost: ${_formatDraftNumber(command.totalCost)}',
      'Profit: ${_formatDraftNumber(command.profit)}',
      'Margin: ${_formatDraftNumber(command.marginPercent)}%',
      'Nothing will be posted before approval.',
    ].join('\n');
  }

  String _localExpenseDraftDetails(LocalAccountingCommandDraft command) {
    if (command.isArabic) {
      return [
        'التصنيف: ${command.categoryArabic ?? command.categoryEnglish ?? '-'}',
        'المبلغ: ${_formatDraftNumber(command.amount)}',
        'لن يتم التسجيل قبل الاعتماد.',
      ].join('\n');
    }
    return [
      'Category: ${_capitalizeDraftLabel(command.categoryEnglish) ?? command.categoryArabic ?? '-'}',
      'Amount: ${_formatDraftNumber(command.amount)}',
      'Nothing will be posted before approval.',
    ].join('\n');
  }

  String _localPurchaseDraftDetails(LocalAccountingCommandDraft command) {
    final inventory = command.type == LocalAccountingCommandDraftType.inventoryIntake;
    if (command.isArabic) {
      return [
        if (command.productName != null) 'الصنف: ${command.productName}',
        'الكمية: ${_formatDraftNumber(command.quantity)}',
        'تكلفة الوحدة: ${_formatDraftNumber(command.unitCost)}',
        inventory
            ? 'إجمالي التكلفة: ${_formatDraftNumber(command.totalCost)}'
            : 'الإجمالي: ${_formatDraftNumber(command.totalCost)}',
        inventory
            ? 'لن يتم تحديث المخزون قبل الاعتماد.'
            : 'لن يتم التسجيل قبل الاعتماد.',
      ].join('\n');
    }
    return [
      if (command.productName != null) 'Product: ${command.productName}',
      'Quantity: ${_formatDraftNumber(command.quantity)}',
      'Unit cost: ${_formatDraftNumber(command.unitCost)}',
      'Total cost: ${_formatDraftNumber(command.totalCost)}',
      inventory
          ? 'Stock will not be updated before approval.'
          : 'Nothing will be posted before approval.',
    ].join('\n');
  }

  String _localPartyDraftDetails(LocalAccountingCommandDraft command) {
    final isCustomer = command.type == LocalAccountingCommandDraftType.receivable ||
        command.type == LocalAccountingCommandDraftType.customerReceipt;
    final isBalance = command.type == LocalAccountingCommandDraftType.receivable ||
        command.type == LocalAccountingCommandDraftType.supplierPayable;
    if (command.isArabic) {
      return [
        '${isCustomer ? 'العميل' : 'المورد'}: ${command.partyName ?? '-'}',
        'المبلغ: ${_formatDraftNumber(command.amount)}',
        if (isCustomer && isBalance)
          'لن يتم تعديل رصيد العميل قبل الاعتماد.'
        else if (isCustomer)
          'لن يتم تسجيل القبض قبل الاعتماد.'
        else if (isBalance)
          'لن يتم تعديل رصيد المورد قبل الاعتماد.'
        else
          'لن يتم تسجيل الدفع قبل الاعتماد.',
      ].join('\n');
    }
    return [
      '${isCustomer ? 'Customer' : 'Supplier'}: ${command.partyName ?? '-'}',
      'Amount: ${_formatDraftNumber(command.amount)}',
      if (isCustomer && isBalance)
        'Customer balance will not be updated before approval.'
      else if (isCustomer)
        'Receipt will not be posted before approval.'
      else if (isBalance)
        'Supplier balance will not be updated before approval.'
      else
        'Supplier payment will not be posted before approval.',
    ].join('\n');
  }

  String _formatDraftNumber(double? value) {
    if (value == null) return '-';
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(2);
  }

  String? _capitalizeDraftLabel(String? value) {
    if (value == null || value.isEmpty) return value;
    return '${value[0].toUpperCase()}${value.substring(1)}';
  }

  void _onDraftCreatedFromIntake(_AccountingDraft draft, String chatMessage) {
    setState(() => _workspaceDrafts.add(draft));
    _appendMessage(
      role: AiChatRole.assistant,
      type: AiChatMessageType.recommendation,
      text: chatMessage,
      suggestedReplies: const [
        'Review the draft',
        'Add missing details',
        'Continue discussing',
      ],
    );
  }

  void _updateDraft(
      String draftId, _AccountingDraft Function(_AccountingDraft) updater) {
    setState(() {
      final idx = _workspaceDrafts.indexWhere((d) => d.id == draftId);
      if (idx >= 0) _workspaceDrafts[idx] = updater(_workspaceDrafts[idx]);
    });
  }

  // ── Session Report ────────────────────────────────────────────────────────

  String _buildSessionReportText() {
    final now = DateTime.now();
    final dateStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final readyDrafts =
        _workspaceDrafts.where((d) => d.status == _DraftStatus.ready).toList();
    final reviewDrafts = _workspaceDrafts
        .where((d) => d.status == _DraftStatus.needsReview)
        .toList();

    String bySource(String label, _DraftSource src) {
      final items = _workspaceDrafts.where((d) => d.source == src).toList();
      if (items.isEmpty) return '';
      final lines = ['■ $label (${items.length})', ''];
      for (final d in items) {
        lines.add('  [${d.statusLabel}] ${d.title}');
        if (d.customerOrSupplier != null)
          lines.add('    Customer/Supplier: ${d.customerOrSupplier}');
        if (d.amount != null)
          lines.add(
              '    Amount: ${d.amount!.toStringAsFixed(2)} ${d.currency ?? ''}');
        if (d.category != null) lines.add('    Category: ${d.category}');
        if (d.missingInfo.isNotEmpty)
          lines.add('    Missing: ${d.missingInfo.take(3).join(', ')}');
        lines.add('');
      }
      return lines.join('\n');
    }

    final chatDrafts = bySource('Chat Drafts', _DraftSource.chat);
    final docDrafts =
        bySource('Document Intake Drafts', _DraftSource.documentIntake);
    final txDrafts =
        bySource('Quick Transaction Drafts', _DraftSource.quickTransaction);
    final recDrafts =
        bySource('Receivables Follow-up', _DraftSource.receivablesFollowUp);
    final payDrafts =
        bySource('Payables / Expense Drafts', _DraftSource.payablesExpense);

    final allMissing = _workspaceDrafts.expand((d) => d.missingInfo).toSet();
    final userHighlights = _messages
        .where((m) => m.role == AiChatRole.user && m.text.trim().isNotEmpty)
        .take(5)
        .map((m) =>
            '  • ${m.text.length > 120 ? '${m.text.substring(0, 120)}…' : m.text}')
        .join('\n');

    return [
      '═══════════════════════════════════════',
      'HASOOB AI CFO — Accounting Session Report',
      'Date: $dateStr',
      '═══════════════════════════════════════',
      '',
      '■ EXECUTIVE SUMMARY',
      '${_messages.length} messages · ${_workspaceDrafts.length} drafts · ${readyDrafts.length} ready · ${reviewDrafts.length} need review',
      '',
      '■ SESSION SCOPE',
      _sessionTopics(),
      '',
      if (userHighlights.isNotEmpty) ...[
        '■ CONVERSATION HIGHLIGHTS',
        userHighlights,
        '',
      ],
      if (chatDrafts.isNotEmpty) chatDrafts,
      if (docDrafts.isNotEmpty) docDrafts,
      if (txDrafts.isNotEmpty) txDrafts,
      if (recDrafts.isNotEmpty) recDrafts,
      if (payDrafts.isNotEmpty) payDrafts,
      if (readyDrafts.isNotEmpty) ...[
        '■ READY ITEMS (${readyDrafts.length})',
        ...readyDrafts.map((d) => '  ✓ [${d.typeLabel}] ${d.title}'),
        '',
      ],
      if (reviewDrafts.isNotEmpty) ...[
        '■ NEEDS REVIEW (${reviewDrafts.length})',
        ...reviewDrafts.map((d) => '  ⚠ [${d.typeLabel}] ${d.title}'),
        '',
      ],
      if (allMissing.isNotEmpty) ...[
        '■ MISSING INFORMATION CHECKLIST',
        ...allMissing.take(12).map((m) => '  • $m'),
        '',
      ],
      '■ RECOMMENDED NEXT ACTIONS',
      if (readyDrafts.isEmpty)
        '  • Mark drafts Ready after reviewing and completing missing fields.'
      else
        ...readyDrafts
            .where((d) => d.recommendedNextAction != null)
            .take(3)
            .map((d) => '  • ${d.recommendedNextAction}'),
      '',
      '═══════════════════════════════════════',
      '⚠ ADVISORY NOTICE',
      'Generated from the current AI CFO session.',
      'NOT posted to the accounting ledger.',
      'NOT saved as official accounting records.',
      'All items require review and explicit approval',
      'before any official accounting action.',
      '═══════════════════════════════════════',
    ].join('\n');
  }

  String _sessionTopics() {
    final t = _messages.map((m) => m.text).join(' ').toLowerCase();
    final topics = <String>[];
    if (_containsAny(t, ['invoice', 'bill', 'receipt'])) topics.add('Invoices');
    if (_containsAny(t, ['cash', 'bank'])) topics.add('Cash Flow');
    if (_containsAny(t, ['receivable', 'customer'])) topics.add('Receivables');
    if (_containsAny(t, ['expense', 'cost'])) topics.add('Expenses');
    if (_containsAny(t, ['inventory', 'stock'])) topics.add('Inventory');
    if (_containsAny(t, ['profit', 'margin'])) topics.add('Profitability');
    if (_containsAny(t, ['payable', 'supplier'])) topics.add('Payables');
    return topics.isEmpty ? 'General financial discussion' : topics.join(', ');
  }

  void _generateSessionReport() {
    if (_workspaceDrafts.isEmpty) {
      _appendMessage(
        role: AiChatRole.assistant,
        type: AiChatMessageType.question,
        text:
            'No accounting drafts have been extracted yet. Use the Intake modules or tap "Organize" to extract drafts from the conversation, then generate the report.',
        suggestedReplies: const [
          'Organize conversation',
          'What should I enter?'
        ],
      );
      return;
    }
    final report = _buildSessionReportText();
    setState(() {
      _sessionReportText = report;
      _sessionReportGenerated = true;
      _savedSessionId = null;
    });
    _showSessionReportSheet();
  }

  Future<void> _copySessionReport() async {
    final text = _sessionReportText;
    if (text == null) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Report copied to clipboard.')),
    );
  }

  Future<void> _saveSessionReport() async {
    final text = _sessionReportText;
    if (text == null || _isSavingSession) return;
    setState(() => _isSavingSession = true);
    try {
      final now = DateTime.now();
      final session = _SavedAiCfoSession(
        id: 'aicfo_${now.millisecondsSinceEpoch}',
        title: 'AI CFO Session',
        reportText: text,
        draftsJson:
            jsonEncode(_workspaceDrafts.map((d) => d.toArchiveMap()).toList()),
        createdAt: now,
      );
      await session.save();
      if (!mounted) return;
      setState(() {
        _savedSessionId = session.id;
        _savedSessions.insert(0, session);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: const Text('AI CFO session saved.'),
            backgroundColor: tealSuccess),
      );
    } catch (e) {
      debugPrint('[AiAccountantScreen] _saveSessionReport: $e');
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Save failed.')));
    } finally {
      if (mounted) setState(() => _isSavingSession = false);
    }
  }

  // ── Show Sheets ───────────────────────────────────────────────────────────

  void _showSessionReportSheet() {
    final report = _sessionReportText ?? '';
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _FullHeightSheet(
        title: 'Accounting Session Report',
        subtitle: 'Session-only — not posted to accounting records.',
        icon: Icons.summarize_outlined,
        colors: _SheetColors.of(this),
        actions: [
          _SheetAction(
            label: 'Copy',
            icon: Icons.copy_outlined,
            color: goldAccent,
            onTap: () {
              Navigator.pop(ctx);
              _copySessionReport();
            },
          ),
          _SheetAction(
            label: _savedSessionId != null ? 'Saved' : 'Save',
            icon: _savedSessionId != null
                ? Icons.check_circle_outline
                : Icons.save_outlined,
            color: tealSuccess,
            enabled: _savedSessionId == null,
            onTap: () async {
              await _saveSessionReport();
              if (ctx.mounted) Navigator.pop(ctx);
            },
          ),
        ],
        child: SelectableText(report,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                height: 1.6,
                fontFamily: 'monospace')),
      ),
    );
  }

  void _showDraftDetailSheet(_AccountingDraft draft) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _DraftDetailSheet(
        draft: draft,
        onUpdate: (updated) => _updateDraft(draft.id, (_) => updated),
        onMarkReady: () => _markDraftReady(draft),
        onMarkNeedsReview: () => _markDraftNeedsReview(draft),
        colors: _SheetColors.of(this),
      ),
    );
  }

  void _showSavedSessionSheet(_SavedAiCfoSession session) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _FullHeightSheet(
        title: session.title,
        subtitle: session.shortDate,
        icon: Icons.archive_outlined,
        colors: _SheetColors.of(this),
        actions: [
          _SheetAction(
            label: 'Copy',
            icon: Icons.copy_outlined,
            color: goldAccent,
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: session.reportText));
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('Copied.')));
              }
            },
          ),
          _SheetAction(
            label: 'Delete',
            icon: Icons.delete_outline,
            color: AppTheme.aiRed,
            onTap: () async {
              await session.delete();
              if (mounted)
                setState(() =>
                    _savedSessions.removeWhere((s) => s.id == session.id));
              if (ctx.mounted) Navigator.pop(ctx);
            },
          ),
        ],
        child: SelectableText(session.reportText,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                height: 1.6,
                fontFamily: 'monospace')),
      ),
    );
  }

  // ── Intake Sheets ─────────────────────────────────────────────────────────

  void _showDocumentIntakeSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _DocumentIntakeSheet(
        colors: _SheetColors.of(this),
        onDraftCreated: (draft, msg) {
          _onDraftCreatedFromIntake(draft, msg);
          Navigator.pop(ctx);
        },
      ),
    );
  }

  void _showQuickTransactionSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _QuickTransactionSheet(
        colors: _SheetColors.of(this),
        onDraftCreated: (draft, msg) {
          _onDraftCreatedFromIntake(draft, msg);
          Navigator.pop(ctx);
        },
      ),
    );
  }

  void _showReceivablesSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ReceivablesSheet(
        colors: _SheetColors.of(this),
        onDraftCreated: (draft, msg) {
          _onDraftCreatedFromIntake(draft, msg);
          Navigator.pop(ctx);
        },
      ),
    );
  }

  void _showPayablesSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PayablesSheet(
        colors: _SheetColors.of(this),
        onDraftCreated: (draft, msg) {
          _onDraftCreatedFromIntake(draft, msg);
          Navigator.pop(ctx);
        },
      ),
    );
  }

  // ── Workspace / Report Panels ─────────────────────────────────────────────

  String _workspaceSummaryText() {
    final total = _workspaceDrafts.length;
    if (total == 0) return 'No drafts yet';
    final ready =
        _workspaceDrafts.where((d) => d.status == _DraftStatus.ready).length;
    final review = _workspaceDrafts
        .where((d) => d.status == _DraftStatus.needsReview)
        .length;
    final inv =
        _workspaceDrafts.where((d) => d.type == _DraftType.invoice).length;
    final acct =
        _workspaceDrafts.where((d) => d.type == _DraftType.account).length;
    final rpt =
        _workspaceDrafts.where((d) => d.type == _DraftType.report).length;
    final tsk = _workspaceDrafts.where((d) => d.type == _DraftType.task).length;
    final parts = <String>[];
    if (inv > 0) parts.add('$inv inv');
    if (acct > 0) parts.add('$acct acct');
    if (rpt > 0) parts.add('$rpt rpt');
    if (tsk > 0) parts.add('$tsk task');
    final breakdown = parts.isEmpty ? '' : ' · ${parts.join(' · ')}';
    final rptPart = _sessionReportGenerated ? ' · report ✓' : '';
    final savePart = _savedSessionId != null ? ' · saved ✓' : '';
    return '$total drafts · $ready ready · $review review$breakdown$rptPart$savePart';
  }

  Widget _buildReportActionBar() {
    final canGenerate = _workspaceDrafts.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_workspaceDrafts.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: darkBg.withValues(alpha: 0.52),
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: premiumStroke),
            ),
            child: Text(_workspaceSummaryText(),
                style: const TextStyle(
                    color: textSecondary, fontSize: 10, height: 1.35)),
          ),
        Row(children: [
          Expanded(
            child: GestureDetector(
              onTap: canGenerate
                  ? (_sessionReportGenerated
                      ? _showSessionReportSheet
                      : _generateSessionReport)
                  : null,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: canGenerate
                      ? goldAccent.withValues(alpha: 0.14)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                      color: canGenerate
                          ? goldAccent.withValues(alpha: 0.42)
                          : premiumStroke),
                ),
                child:
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(
                      _sessionReportGenerated
                          ? Icons.summarize_outlined
                          : Icons.auto_awesome_outlined,
                      color: canGenerate ? goldAccent : textSecondary,
                      size: 13),
                  const SizedBox(width: 5),
                  Text(
                      _sessionReportGenerated
                          ? 'View Report'
                          : 'Generate Report',
                      style: TextStyle(
                          color: canGenerate ? goldAccent : textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w900)),
                ]),
              ),
            ),
          ),
          if (_sessionReportGenerated) ...[
            const SizedBox(width: 6),
            GestureDetector(
              onTap: _copySessionReport,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: premiumStroke)),
                child: const Icon(Icons.copy_outlined,
                    color: textSecondary, size: 14),
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: (_savedSessionId != null || _isSavingSession)
                  ? null
                  : _saveSessionReport,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
                decoration: BoxDecoration(
                  color: _savedSessionId != null
                      ? tealSuccess.withValues(alpha: 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                      color: _savedSessionId != null
                          ? tealSuccess.withValues(alpha: 0.38)
                          : premiumStroke),
                ),
                child: Icon(
                    _savedSessionId != null
                        ? Icons.check_circle_outline
                        : Icons.save_outlined,
                    color:
                        _savedSessionId != null ? tealSuccess : textSecondary,
                    size: 14),
              ),
            ),
          ],
        ]),
      ],
    );
  }

  Widget _buildIntakePanel() {
    final buttons = [
      (
        Icons.paste_outlined,
        'مستند',
        'لصق الفاتورة، الإيصال، أو عرض السعر',
        _showDocumentIntakeSheet
      ),
      (
        Icons.receipt_outlined,
        'عملية',
        'ملاحظة بيع أو مصروف أو دفعة سريعة',
        _showQuickTransactionSheet
      ),
      (
        Icons.people_alt_outlined,
        'مستحقات العملاء',
        'متابعة ودفعات العملاء',
        _showReceivablesSheet
      ),
      (
        Icons.payment_outlined,
        'مصروف/مورد',
        'دفعات الموردين والمصاريف',
        _showPayablesSheet
      ),
    ];
    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: buttons.map((btn) {
        return Tooltip(
          message: btn.$3,
          child: GestureDetector(
            onTap: btn.$4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: darkBg.withValues(alpha: 0.38),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: goldAccent.withValues(alpha: 0.28)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(btn.$1, color: goldAccent, size: 13),
                const SizedBox(width: 5),
                Text(btn.$2,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800)),
              ]),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSavedSessionsPanel() {
    if (_savedSessions.isEmpty) {
      return const _EmptyHint(
        icon: Icons.archive_outlined,
        title: 'لا توجد جلسات محفوظة بعد',
        body: 'أنشئ تقرير جلسة واحفظه. جلسات AI CFO المحفوظة تظهر هنا.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _savedSessions
          .take(5)
          .map((s) => GestureDetector(
                onTap: () => _showSavedSessionSheet(s),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: darkBg.withValues(alpha: 0.42),
                    borderRadius: BorderRadius.circular(9),
                    border:
                        Border.all(color: tealSuccess.withValues(alpha: 0.22)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.check_circle_outline,
                        color: tealSuccess, size: 13),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(s.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900)),
                          Text(s.shortDate,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: textSecondary, fontSize: 9.5)),
                        ])),
                    const Icon(Icons.chevron_right_rounded,
                        color: textSecondary, size: 15),
                  ]),
                ),
              ))
          .toList(),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildRailHeader({
    required IconData icon,
    required String arabicTitle,
    required String englishTitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: darkBg.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: goldAccent.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          Icon(icon, color: goldAccent, size: 18),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  arabicTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  englishTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: textSecondary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodaySummarySection() {
    final items = [
      (
        Icons.point_of_sale_outlined,
        'المبيعات',
        'Sales',
        _firstInsightSignal(['sales', 'revenue']) ??
            'تحتاج بيانات / Needs data',
      ),
      (
        Icons.trending_down_rounded,
        'المصاريف',
        'Expenses',
        _firstInsightSignal(['expense', 'cost']) ?? 'تحتاج بيانات / Needs data',
      ),
      (
        Icons.show_chart_rounded,
        'الربح',
        'Profit',
        _firstInsightSignal(['profit', 'margin']) ??
            'تحتاج تحليل / Needs analysis',
      ),
      (
        Icons.payments_outlined,
        'النقدية',
        'Cash',
        _firstInsightSignal(['cash', 'payment', 'liquidity']) ??
            'تحتاج بيانات / Needs data',
      ),
    ];

    return Column(
      children: items.map((item) {
        return _railStatusTile(
          icon: item.$1,
          title: '${item.$2} / ${item.$3}',
          value: item.$4,
        );
      }).toList(),
    );
  }

  Widget _buildAccountsMonitorSection() {
    final accounts = [
      (Icons.account_balance_wallet_outlined, 'الصندوق', 'Cashbox'),
      (Icons.point_of_sale_outlined, 'المبيعات', 'Sales'),
      (Icons.receipt_long_outlined, 'المصاريف', 'Expenses'),
      (Icons.people_alt_outlined, 'العملاء', 'Customers'),
      (Icons.local_shipping_outlined, 'الموردون', 'Suppliers'),
      (Icons.inventory_2_outlined, 'المخزون', 'Inventory'),
    ];

    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: accounts.map((account) {
        return _railActionButton(
          icon: account.$1,
          label: '${account.$2} / ${account.$3}',
          onTap: _isAnalyzing || _isCommitting
              ? null
              : () =>
                  _processAiCommand(customText: 'Review ${account.$3} account'),
        );
      }).toList(),
    );
  }

  Widget _buildRiskMonitorSection() {
    final risks = _latestRisks()
        .where((risk) => risk.title != 'No major risk detected')
        .take(4)
        .map((risk) => '${risk.levelLabel}: ${risk.title}')
        .toList();
    return _contextRows(
      risks,
      empty:
          'لا توجد مخاطر مؤكدة من بيانات الجلسة الحالية / No active risk signal',
    );
  }

  Widget _buildMissingDataSection() {
    final metadata = _latestMetadata();
    final missing = metadata?.missingEvidence.take(5).toList() ?? const [];
    final empty = metadata == null
        ? 'ابدأ بسؤال أو أدخل مستندًا ليحدد حاسوب البيانات الناقصة / Ask or add a document to detect missing data'
        : 'لا توجد بيانات ناقصة محددة في آخر تحليل / No specific missing data in the latest analysis';
    return _contextRows(missing, empty: empty);
  }

  Widget _railStatusTile({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: darkBg.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: premiumStroke),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: goldAccent, size: 14),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: textSecondary,
                    fontSize: 10,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _railActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
  }) {
    return Tooltip(
      message: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
          decoration: BoxDecoration(
            color: darkBg.withValues(alpha: 0.36),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: premiumStroke),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: goldAccent, size: 13),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickEntrySection() {
    final actions = [
      (
        Icons.point_of_sale_outlined,
        'بيع جديد / New Sale',
        _showQuickTransactionSheet
      ),
      (
        Icons.inventory_2_outlined,
        'شراء مخزون / Stock Purchase',
        _showQuickTransactionSheet
      ),
      (
        Icons.receipt_long_outlined,
        'مصروف / Expense',
        _showQuickTransactionSheet
      ),
      (
        Icons.people_alt_outlined,
        'مستحقات عميل / Customer Receivable',
        _showReceivablesSheet
      ),
      (
        Icons.payment_outlined,
        'مورد/مصروف / Payable/Supplier',
        _showPayablesSheet
      ),
    ];
    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: actions.map((action) {
        return _railActionButton(
          icon: action.$1,
          label: action.$2,
          onTap: action.$3,
        );
      }).toList(),
    );
  }

  Widget _buildDocumentsSection() {
    final actions = [
      (
        Icons.description_outlined,
        'مستند / Document',
        _showDocumentIntakeSheet
      ),
      (Icons.receipt_outlined, 'فاتورة / Invoice', _showDocumentIntakeSheet),
      (
        Icons.request_quote_outlined,
        'عرض سعر / Quotation',
        _showDocumentIntakeSheet
      ),
      (
        Icons.fact_check_outlined,
        'مراجعة مستند / Review Document',
        _showDocumentIntakeSheet
      ),
    ];
    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: actions.map((action) {
        return _railActionButton(
          icon: action.$1,
          label: action.$2,
          onTap: action.$3,
        );
      }).toList(),
    );
  }

  Widget _buildReportsSection() {
    final prompts = [
      (
        Icons.today_outlined,
        'تقرير اليوم / Daily Report',
        'Prepare a daily financial report'
      ),
      (
        Icons.show_chart_rounded,
        'تقرير الربح / Profit Report',
        'Prepare a profit report'
      ),
      (
        Icons.inventory_2_outlined,
        'تقرير المخزون / Inventory Report',
        'Prepare an inventory report'
      ),
      (
        Icons.people_alt_outlined,
        'تقرير العملاء / Customer Report',
        'Prepare a customer report'
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: prompts.map((prompt) {
            return _railActionButton(
              icon: prompt.$1,
              label: prompt.$2,
              onTap: _isAnalyzing || _isCommitting
                  ? null
                  : () => _processAiCommand(customText: prompt.$3),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        _railActionButton(
          icon: Icons.auto_awesome_outlined,
          label: 'إنشاء التقرير / Generate Report',
          onTap: _workspaceDrafts.isEmpty
              ? null
              : (_sessionReportGenerated
                  ? _showSessionReportSheet
                  : _generateSessionReport),
        ),
      ],
    );
  }

  Widget _buildReconciliationSection() {
    final prompts = [
      (
        Icons.payments_outlined,
        'تسوية النقدية / Cash Reconciliation',
        'Review cash reconciliation'
      ),
      (
        Icons.receipt_long_outlined,
        'الفواتير غير المدفوعة / Unpaid Invoices',
        'Review unpaid invoices'
      ),
      (
        Icons.category_outlined,
        'مصاريف غير مصنفة / Uncategorized Expenses',
        'Review uncategorized expenses'
      ),
      (
        Icons.lock_clock_outlined,
        'الإغلاق اليومي / Daily Closing',
        'Prepare daily closing review'
      ),
    ];
    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: prompts.map((prompt) {
        return _railActionButton(
          icon: prompt.$1,
          label: prompt.$2,
          onTap: _isAnalyzing || _isCommitting
              ? null
              : () => _processAiCommand(customText: prompt.$3),
        );
      }).toList(),
    );
  }

  Widget _buildRightContextRail() {
    final workflow = _orchestrator.activeWorkflow;
    final proposal = _activeProposal ?? _confirmationProposal;

    return Container(
      decoration: BoxDecoration(
        color: premiumPanel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: premiumStroke),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildRailHeader(
              icon: Icons.construction_outlined,
              arabicTitle: 'الأدوات والتنفيذ',
              englishTitle: 'Tools & execution',
            ),
            const SizedBox(height: 10),
            Command360ContextModule(
              title: 'المسودات بانتظار المراجعة',
              icon: Icons.folder_special_outlined,
              child: _buildWorkspaceDraftsPanel(),
            ),
            Command360ContextModule(
              title: 'الإدخال السريع',
              icon: Icons.add_circle_outline,
              child: _buildQuickEntrySection(),
            ),
            Command360ContextModule(
              title: 'المستندات',
              icon: Icons.description_outlined,
              child: _buildDocumentsSection(),
            ),
            Command360ContextModule(
              title: 'التقارير',
              icon: Icons.summarize_outlined,
              child: _buildReportsSection(),
            ),
            Command360ContextModule(
              title: 'التسوية والمراجعة',
              icon: Icons.fact_check_outlined,
              child: _buildReconciliationSection(),
            ),
            Command360ContextModule(
              title: 'المقترح النشط',
              icon: Icons.fact_check_outlined,
              child: _buildDecisionCockpit(
                proposal: proposal,
                workflow: workflow,
              ),
            ),
            Command360ContextModule(
              title: 'تقرير الجلسة',
              icon: Icons.archive_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildReportActionBar(),
                  const SizedBox(height: 10),
                  _buildSavedSessionsPanel(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildRightContextRailLegacy() {
    final score = _businessHealthScore();
    final risks = _latestRisks();
    final insights = _latestInsights();
    final recommendations = _latestRecommendations();
    final workflow = _orchestrator.activeWorkflow;
    final proposal = _activeProposal ?? _confirmationProposal;

    return Container(
      decoration: BoxDecoration(
        color: premiumPanel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: premiumStroke),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Command360ContextModule(
              title: 'الإدخال السريع',
              icon: Icons.add_circle_outline,
              child: _buildIntakePanel(),
            ),
            Command360ContextModule(
              title: 'تقرير الجلسة',
              icon: Icons.summarize_outlined,
              child: _buildReportActionBar(),
            ),
            Command360ContextModule(
              title: 'مساحة محاسبة',
              icon: Icons.folder_special_outlined,
              child: _buildWorkspaceDraftsPanel(),
            ),
            Command360ContextModule(
              title: 'الجلسات المحفوظة',
              icon: Icons.archive_outlined,
              child: _buildSavedSessionsPanel(),
            ),
            Command360ContextModule(
              title: 'الصحة المالية',
              icon: Icons.query_stats_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    score == null ? 'Ready to analyze' : '$score / 100',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    score == null
                        ? 'Ask a business question to generate a live CFO view.'
                        : _businessHealthLabel(score),
                    style: const TextStyle(
                      color: textSecondary,
                      fontSize: 11,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            Command360ContextModule(
              title: 'مخاطر النظام',
              icon: Icons.warning_amber_rounded,
              child: _contextRows(
                risks
                    .where((risk) => risk.title != 'No major risk detected')
                    .take(4)
                    .map((risk) => '${risk.levelLabel}: ${risk.title}')
                    .toList(),
                empty: 'No active risk signal',
              ),
            ),
            Command360ContextModule(
              title: 'رؤى',
              icon: Icons.lightbulb_outline,
              child: _contextRows(
                insights.take(4).map((item) => item.title).toList(),
                empty: 'لم تُنشأ رؤى بعد',
              ),
            ),
            Command360ContextModule(
              title: 'الإجراءات الموصى بها',
              icon: Icons.task_alt_outlined,
              child: _contextRows(
                recommendations.take(4).map((item) => item.title).toList(),
                empty: 'اسأل عن التحليل لتوليد إجراءات',
              ),
            ),
            Command360ContextModule(
              title: 'الذاكرة',
              icon: Icons.memory_outlined,
              child: _buildContextSummary(compact: true),
            ),
            Command360ContextModule(
              title: 'الجدول الزمني التشغيلي',
              icon: Icons.timeline_outlined,
              child: _buildOperatingTimeline(compact: true),
            ),
            Command360ContextModule(
              title: 'المتابعة الذكية',
              icon: Icons.pending_actions_outlined,
              child: _buildFollowUpLoop(compact: true),
            ),
            Command360ContextModule(
              title: 'المقترح النشط / سير العمل',
              icon: Icons.fact_check_outlined,
              child: _buildDecisionCockpit(
                proposal: proposal,
                workflow: workflow,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _contextRows(List<String> rows, {required String empty}) {
    final visibleRows = rows.where((row) => row.trim().isNotEmpty).toList();
    if (visibleRows.isEmpty) {
      return Text(
        empty,
        style: const TextStyle(color: textSecondary, fontSize: 11),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: visibleRows.take(4).map((row) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 7),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 5),
                child: Icon(Icons.circle, color: textSecondary, size: 5),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  row,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDecisionCockpit({
    required AiProposalModel? proposal,
    required AiWorkflowSession? workflow,
  }) {
    if (proposal != null) {
      return _buildActionExecutionCard(
        proposal,
        compact: true,
        source: _ActionCardSource.rail,
        generatedAt: _proposalGeneratedAt(proposal),
      );
    }

    if (workflow != null) {
      return _buildWorkflowDecisionCard(workflow);
    }

    return const _ExecutiveEmptyLine(
      icon: Icons.rule_folder_outlined,
      label: 'No active proposal or workflow',
    );
  }

  Widget _buildWorkflowDecisionCard(AiWorkflowSession workflow) {
    final waitingField = workflow.waitingField;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: darkSurface.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: premiumStroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _workflowTitle(workflow.workflowType),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          _actionInfoLine(
            icon: Icons.route_outlined,
            label:
                'Step ${workflow.currentStep.clamp(1, workflow.totalSteps)} of ${workflow.totalSteps}',
          ),
          _actionInfoLine(
            icon: Icons.assignment_late_outlined,
            label: waitingField == null
                ? 'Review required before proposal creation'
                : 'Waiting for ${AiWorkflowField.label(waitingField)}',
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: null,
            icon: const Icon(Icons.lock_outline, size: 16),
            label: const Text('Review required'),
          ),
        ],
      ),
    );
  }

  String _businessHealthLabel(int score) {
    if (score >= 80) return 'Healthy. Continue monitoring cash and exposure.';
    if (score >= 65) return 'Stable with items worth reviewing.';
    return 'Needs attention before major commitments.';
  }

  // ignore: unused_element
  Widget _buildMobileContextPanel(double maxHeight) {
    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight < 720 ? 230 : 300),
      decoration: BoxDecoration(
        color: premiumPanel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: premiumStroke),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          tilePadding: const EdgeInsets.symmetric(horizontal: 14),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          iconColor: goldAccent,
          collapsedIconColor: textSecondary,
          title: const Text(
            'Context & ledger',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          subtitle: Text(
            _activeProposal != null
                ? 'Active proposal ready'
                : 'Business context loaded',
            style: const TextStyle(color: textSecondary, fontSize: 11),
          ),
          children: [
            _buildContextSummary(compact: true),
            const SizedBox(height: 10),
            SizedBox(
              height: 170,
              child: _buildLedgerPanel(isCompact: true, embedded: true),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContextSummary({bool compact = false}) {
    final memory = _orchestrator.memory;
    final businessMemory = _orchestrator.businessMemory;
    final workflow = _orchestrator.activeWorkflow;
    return Padding(
      padding: EdgeInsets.all(compact ? 12 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!compact) ...[
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'CFO context',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                _statusPill('Live', tealSuccess),
              ],
            ),
            const SizedBox(height: 12),
          ],
          Command360ContextRow(
              icon: Icons.business_outlined,
              label: 'Business',
              value: BusinessContext.businessId.isEmpty
                  ? 'Open a business profile'
                  : BusinessContext.businessId),
          Command360ContextRow(
              icon: Icons.person_outline,
              label: 'Customer',
              value: memory.latestCustomer ?? 'Ask about a customer'),
          Command360ContextRow(
              icon: Icons.inventory_2_outlined,
              label: 'Product',
              value: memory.currentProduct ?? 'Ask about a product'),
          Command360ContextRow(
              icon: Icons.fact_check_outlined,
              label: 'Active proposal',
              value: _activeProposal?.actionType ??
                  _confirmationProposal?.actionType ??
                  'No Active Proposal'),
          Command360ContextRow(
              icon: Icons.route_outlined,
              label: 'Active workflow',
              value: workflow == null
                  ? 'No Active Workflow'
                  : _workflowTitle(workflow.workflowType)),
          if (!compact) ...[
            const SizedBox(height: 8),
            _buildBusinessMemoryPanel(businessMemory),
          ],
        ],
      ),
    );
  }

  Widget _buildBusinessMemoryPanel(AiBusinessMemory businessMemory) {
    final recentProduct = businessMemory.recentProducts.isEmpty
        ? 'Discuss a product'
        : businessMemory.recentProducts.first;
    final recentCustomer = businessMemory.recentCustomers.isEmpty
        ? 'Discuss a customer'
        : businessMemory.recentCustomers.first;
    final recentTopic = businessMemory.recentTopics.isEmpty
        ? 'Ask for analysis'
        : businessMemory.recentTopics.first;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.aiCardElevated.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: premiumStroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Business Memory',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() => _orchestrator.clearBusinessMemory());
                },
                child: const Text('Clear Memory'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Command360ContextRow(
              icon: Icons.inventory_2_outlined,
              label: 'Recent Product',
              value: recentProduct),
          Command360ContextRow(
              icon: Icons.person_outline,
              label: 'Recent Customer',
              value: recentCustomer),
          Command360ContextRow(
              icon: Icons.topic_outlined,
              label: 'Recent Topic',
              value: recentTopic),
        ],
      ),
    );
  }

  Widget _buildLedgerPanel({bool isCompact = false, bool embedded = false}) {
    return Container(
      padding: EdgeInsets.all(isCompact ? 12 : 16),
      decoration: BoxDecoration(
        color: embedded ? Colors.transparent : darkBg,
        border: embedded
            ? null
            : Border(
                left: isCompact
                    ? BorderSide.none
                    : const BorderSide(color: borderTerminal),
                top: isCompact
                    ? const BorderSide(color: borderTerminal)
                    : BorderSide.none,
              ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Ledger context',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '${_ledgerRows.length} rows',
                style: const TextStyle(color: textSecondary, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: darkSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: borderTerminal),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 640),
                    child: DataTable(
                      headingRowColor:
                          WidgetStateProperty.all(AppTheme.aiCardElevated),
                      dataRowMinHeight: 48,
                      dataRowMaxHeight: 58,
                      horizontalMargin: 12,
                      columnSpacing: 18,
                      columns: const [
                        DataColumn(
                          label: Text(
                            'Code',
                            style: TextStyle(
                              color: goldAccent,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Account',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Debit',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Credit',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Memo',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                      ],
                      rows: _ledgerRows.map((row) {
                        return DataRow(
                          color: row.isUncommitted
                              ? WidgetStateProperty.all(
                                  goldAccent.withValues(alpha: 0.06),
                                )
                              : null,
                          cells: [
                            DataCell(
                              Text(
                                row.code,
                                style: TextStyle(
                                  color: row.isUncommitted
                                      ? goldAccent
                                      : textSecondary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                row.account,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                row.debit > 0
                                    ? row.debit.toStringAsFixed(2)
                                    : '0.00',
                                style: const TextStyle(
                                  color: AppTheme.aiRed,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                row.credit > 0
                                    ? row.credit.toStringAsFixed(2)
                                    : '0.00',
                                style: const TextStyle(
                                  color: tealSuccess,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                row.description,
                                style: TextStyle(
                                  color: row.isUncommitted
                                      ? Colors.white
                                      : Colors.white70,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildAiPanel({bool isMobile = false}) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.aiNavy,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: premiumStroke),
      ),
      padding: EdgeInsets.all(isMobile ? 12 : 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildWorkspaceIntro(),
          const SizedBox(height: 14),
          _buildQuickInsights(isMobile: isMobile),
          const SizedBox(height: 12),
          _buildQuickActions(),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: darkBg.withValues(alpha: 0.42),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: premiumStroke),
              ),
              child: _messages.isEmpty
                  ? _buildPremiumEmptyState()
                  : _buildChatTimeline(),
            ),
          ),
          if (_isAnalyzing) _buildTypingIndicator(),
          const SizedBox(height: 12),
          _buildInputField(),
        ],
      ),
    );
  }

  Widget _buildWorkspaceIntro() {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AI CFO workspace',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Ask, compare, prepare proposals, then approve through the guarded accounting flow. Add invoices, customers, products, expenses, and shipment costs when analysis says data is missing.',
                style:
                    TextStyle(color: textSecondary, fontSize: 12, height: 1.35),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.end,
          children: [
            _statusPill('AI CFO Beta', goldAccent),
            if (_activeProposal != null)
              _statusPill('Proposal ready', goldAccent)
            else
              _statusPill('Advisory only', tealSuccess),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickInsights({required bool isMobile}) {
    final insights = [
      const _InsightData(
        'Revenue',
        'Ask about revenue',
        Icons.trending_up_rounded,
        tealSuccess,
      ),
      const _InsightData(
        'Expenses',
        'Ask about expenses',
        Icons.trending_down_rounded,
        AppTheme.aiRed,
      ),
      const _InsightData(
        'Profit',
        'Ask about profit',
        Icons.account_balance_wallet_outlined,
        goldAccent,
      ),
      const _InsightData(
        'Pending Invoices',
        'Ask about invoices',
        Icons.receipt_long_outlined,
        AppTheme.warning,
      ),
      const _InsightData(
        'Low Stock',
        'Ask about stock',
        Icons.inventory_2_outlined,
        tealSuccess,
      ),
    ];

    if (isMobile) {
      return SizedBox(
        height: 78,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: insights.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) => _InsightCard(data: insights[index]),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return GridView.count(
          crossAxisCount: constraints.maxWidth > 820 ? 5 : 3,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: constraints.maxWidth > 820 ? 2.45 : 2.25,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: insights.map((data) => _InsightCard(data: data)).toList(),
        );
      },
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      ('Analyze Profitability', Icons.analytics_outlined),
      ('Cash Flow', Icons.payments_outlined),
      ('Low Stock', Icons.inventory_outlined),
      ('Customer Balances', Icons.people_alt_outlined),
      ('Top Products', Icons.leaderboard_outlined),
    ];
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: actions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final action = actions[index];
          return Command360QuickActionChip(
            label: action.$1,
            icon: action.$2,
            onPressed: _isAnalyzing || _isCommitting
                ? null
                : () => _processAiCommand(customText: action.$1),
          );
        },
      ),
    );
  }

  Widget _buildChatTimeline() {
    return ListView.separated(
      controller: _chatScrollController,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      itemCount: _messages.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, index) => _buildChatMessage(_messages[index]),
    );
  }

  Widget _buildPremiumEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: goldAccent.withValues(alpha: 0.11),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: goldAccent.withValues(alpha: 0.24)),
              ),
              child: const Icon(
                Icons.account_balance_outlined,
                color: goldAccent,
                size: 30,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'AI Accountant & CFO Advisor',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Talk to me like your accountant. Discuss invoices, receivables, cash, expenses, inventory, or financial decisions — then tap "Organize" to extract structured accounting work items for review.',
              textAlign: TextAlign.center,
              style:
                  TextStyle(color: textSecondary, fontSize: 12, height: 1.45),
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Command360QuickActionChip(
                  label: 'Is my cash situation safe?',
                  icon: Icons.payments_outlined,
                  onPressed: () => _processAiCommand(
                    customText: 'Is my cash situation safe?',
                  ),
                ),
                Command360QuickActionChip(
                  label: 'Analyze Profitability',
                  icon: Icons.analytics_outlined,
                  onPressed: () => _processAiCommand(
                    customText: 'Analyze Profitability',
                  ),
                ),
                Command360QuickActionChip(
                  label: 'Customer balance risk',
                  icon: Icons.people_alt_outlined,
                  onPressed: () => _processAiCommand(
                    customText: 'Review customer balance risk',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatMessage(AiChatMessage message) {
    final isUser = message.role == AiChatRole.user;
    final alignment = isUser ? Alignment.centerRight : Alignment.centerLeft;
    final bubbleColor =
        isUser ? goldAccent.withValues(alpha: 0.16) : Colors.transparent;
    final borderColor =
        isUser ? goldAccent.withValues(alpha: 0.34) : Colors.transparent;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final maxWidth = isUser
        ? (screenWidth >= 1000 ? 430.0 : screenWidth * 0.78)
        : (screenWidth >= 1000 ? 900.0 : screenWidth * 0.96);

    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(isUser ? 12 : 0),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(isUser ? 14 : 6),
                  topRight: const Radius.circular(14),
                  bottomLeft: Radius.circular(isUser ? 14 : 6),
                  bottomRight: Radius.circular(isUser ? 4 : 14),
                ),
                border: Border.all(color: borderColor),
              ),
              child: isUser
                  ? _buildUserMessageContent(message)
                  : _buildAssistantMessageContent(message),
            ),
            if (!isUser && message.suggestedReplies.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildSuggestedReplies(message.suggestedReplies),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUserMessageContent(AiChatMessage message) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          message.text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            height: 1.38,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          _timeLabel(message.timestamp),
          style: const TextStyle(
            color: AppTheme.aiTextMuted,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildAssistantMessageContent(AiChatMessage message) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              _messageIcon(message.type),
              color: _messageColor(message.type),
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'AI Accountant',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _messageColor(message.type),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Text(
              _timeLabel(message.timestamp),
              style: const TextStyle(
                color: AppTheme.aiTextMuted,
                fontSize: 10,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _messageSectionTitle('Summary'),
        Text(
          message.text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            height: 1.55,
          ),
        ),
        if (message.decisionOptions.isNotEmpty) ...[
          const SizedBox(height: 14),
          _messageSectionTitle('Reasoning'),
          Command360DecisionOptions(options: message.decisionOptions),
        ],
        if (message.recommendations.isNotEmpty) ...[
          const SizedBox(height: 14),
          _messageSectionTitle('Recommendations'),
          Command360MessageRows(
            rows: message.recommendations
                .take(4)
                .map((item) => item.title)
                .toList(),
            icon: Icons.task_alt_outlined,
            color: tealSuccess,
          ),
        ],
        if (message.proposal != null || message.executionResult != null) ...[
          const SizedBox(height: 14),
          _messageSectionTitle('Actions'),
          if (message.proposal != null)
            _buildProposalCard(message.proposal!,
                generatedAt: message.timestamp),
          if (message.executionResult != null)
            _buildExecutionResultCard(message.executionResult!),
        ],
        if (_hasExpandableMessageDetails(message)) ...[
          const SizedBox(height: 12),
          _buildMessageExpandableSections(message),
        ],
      ],
    );
  }

  Widget _messageSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        title,
        style: const TextStyle(
          color: textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  bool _hasExpandableMessageDetails(AiChatMessage message) {
    return message.metadata != null ||
        message.workflowSession != null ||
        message.memory?.hasVisibleContext == true ||
        message.insights.isNotEmpty ||
        message.risks.isNotEmpty;
  }

  Widget _buildMessageExpandableSections(AiChatMessage message) {
    final metadata = message.metadata;
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (message.insights.isNotEmpty || message.risks.isNotEmpty)
            Command360MessageExpansion(
              title: 'Evidence',
              icon: Icons.dataset_outlined,
              child: Command360MessageRows(
                rows: [
                  ...message.insights.take(3).map((item) => item.title),
                  ...message.risks
                      .where((risk) => risk.title != 'No major risk detected')
                      .take(3)
                      .map((risk) => '${risk.levelLabel}: ${risk.title}'),
                  if (metadata != null)
                    'Evidence records: ${metadata.evidenceCount}',
                  if (metadata != null && metadata.missingEvidence.isNotEmpty)
                    'Missing: ${metadata.missingEvidence.join(', ')}',
                ],
                icon: Icons.circle_outlined,
                color: textSecondary,
              ),
            ),
          if (metadata != null)
            Command360MessageExpansion(
              title: 'Confidence',
              icon: Icons.verified_user_outlined,
              child: Command360MessageRows(
                rows: ['${metadata.confidenceLabel} confidence'],
                icon: Icons.verified_user_outlined,
                color: _confidenceColor(metadata.confidenceLevel),
              ),
            ),
          if (metadata != null && metadata.executedTools.isNotEmpty)
            Command360MessageExpansion(
              title: 'Tools Used',
              icon: Icons.construction_outlined,
              child: Command360MessageRows(
                rows: metadata.executedToolLabels,
                icon: Icons.check_circle_outline_rounded,
                color: tealSuccess,
              ),
            ),
          if (message.workflowSession != null)
            Command360MessageExpansion(
              title: 'Workflow State',
              icon: Icons.route_outlined,
              child: Command360WorkflowCard(session: message.workflowSession!),
            ),
          if (message.memory?.hasVisibleContext == true)
            Command360MessageExpansion(
              title: 'Memory',
              icon: Icons.memory_outlined,
              child: Command360MemoryCard(memory: message.memory!),
            ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildAiInsightsPanel({
    required List<AiFinancialInsight> insights,
    required List<AiFinancialRisk> risks,
    required List<AiFinancialRecommendation> recommendations,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.aiCardElevated.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tealSuccess.withValues(alpha: 0.26)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'AI Insights',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (insights.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: insights.take(4).map(_insightCard).toList(),
            ),
          ],
          if (risks.isNotEmpty) ...[
            const SizedBox(height: 12),
            _insightSection(
              title: 'Risks',
              rows: risks
                  .take(3)
                  .map((risk) => '${risk.levelLabel}: ${risk.title}')
                  .toList(),
              icon: Icons.warning_amber_rounded,
              color: goldAccent,
            ),
          ],
          if (recommendations.isNotEmpty) ...[
            const SizedBox(height: 10),
            _insightSection(
              title: 'Recommendations',
              rows: recommendations.take(3).map((item) => item.title).toList(),
              icon: Icons.task_alt_rounded,
              color: tealSuccess,
            ),
          ],
        ],
      ),
    );
  }

  Widget _insightCard(AiFinancialInsight insight) {
    return Container(
      width: 190,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: premiumPanelSoft.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: premiumStroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            insight.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            insight.description,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: textSecondary,
              fontSize: 10.5,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _insightSection({
    required String title,
    required List<String> rows,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: textSecondary,
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        ...rows.map((row) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(
              children: [
                Icon(icon, color: color, size: 14),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    row,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ignore: unused_element
  Widget _buildResponseMetadata(AiResponseMetadata metadata) {
    final isMobile = MediaQuery.sizeOf(context).width < 700;
    final confidenceColor = _confidenceColor(metadata.confidenceLevel);
    final summary = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _metadataPill(
          Icons.verified_user_outlined,
          'Confidence: ${metadata.confidenceLabel}',
          confidenceColor,
        ),
        _metadataPill(
          Icons.dataset_outlined,
          'Evidence: ${metadata.evidenceCount} records',
          textSecondary,
        ),
        _metadataPill(
          Icons.construction_outlined,
          'Tools Used: ${metadata.executedTools.length}',
          textSecondary,
        ),
      ],
    );

    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        summary,
        if (metadata.executedTools.isNotEmpty) ...[
          const SizedBox(height: 10),
          _metadataPanel(
            title: 'Tools Used',
            rows: metadata.executedToolLabels,
            icon: Icons.check_circle_outline_rounded,
            color: tealSuccess,
          ),
        ],
        if (metadata.missingEvidence.isNotEmpty) ...[
          const SizedBox(height: 10),
          _metadataPanel(
            title: 'Missing Information',
            rows: metadata.missingEvidence,
            icon: Icons.info_outline_rounded,
            color: goldAccent,
          ),
        ],
      ],
    );

    if (!isMobile) return details;

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.aiCardElevated.withValues(alpha: 0.58),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: premiumStroke),
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 10),
          childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          iconColor: textSecondary,
          collapsedIconColor: textSecondary,
          title: summary,
          children: [
            if (metadata.executedTools.isNotEmpty)
              _metadataPanel(
                title: 'Tools Used',
                rows: metadata.executedToolLabels,
                icon: Icons.check_circle_outline_rounded,
                color: tealSuccess,
              ),
            if (metadata.missingEvidence.isNotEmpty) ...[
              const SizedBox(height: 10),
              _metadataPanel(
                title: 'Missing Information',
                rows: metadata.missingEvidence,
                icon: Icons.info_outline_rounded,
                color: goldAccent,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _metadataPanel({
    required String title,
    required List<String> rows,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.aiCardElevated.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: premiumStroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          ...rows.map((row) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(icon, color: color, size: 14),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      row,
                      style: const TextStyle(
                        color: textSecondary,
                        fontSize: 11,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _metadataPill(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestedReplies(List<String> replies) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: replies.map((reply) {
        return ActionChip(
          backgroundColor: AppTheme.aiCardElevated,
          side: const BorderSide(color: borderTerminal),
          label: Text(
            reply,
            style: const TextStyle(color: textSecondary, fontSize: 11),
          ),
          onPressed: _isAnalyzing || _isCommitting
              ? null
              : () => _processAiCommand(customText: reply),
        );
      }).toList(),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: premiumPanel,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: premiumStroke),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child:
                  CircularProgressIndicator(color: goldAccent, strokeWidth: 2),
            ),
            SizedBox(width: 9),
            Text(
              'AI Accountant is preparing a safe response...',
              style: TextStyle(color: textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProposalCard(
    AiProposalModel proposal, {
    DateTime? generatedAt,
  }) {
    return _buildActionExecutionCard(
      proposal,
      compact: false,
      source: _ActionCardSource.chat,
      generatedAt: generatedAt,
    );
  }

  Widget _buildActionExecutionCard(
    AiProposalModel proposal, {
    required bool compact,
    required _ActionCardSource source,
    DateTime? generatedAt,
  }) {
    final isPricing = proposal.actionType == 'pricing_simulation';
    final pricing = proposal.pricingPayload ?? const <String, dynamic>{};
    final inventory = proposal.inventoryPayload ?? const <String, dynamic>{};
    final financial = proposal.financialPayload ?? const <String, dynamic>{};
    final isCurrent = _isCurrentActionProposal(proposal);
    final executionState = _proposalExecutionState(proposal);
    final canExecute = executionState.canDelegateExecution;
    final canDismiss = isCurrent && !_isCommitting;
    final title = _proposalActionTitle(proposal);
    final impact = _proposalFinancialImpact(proposal);
    final decision = executionState.decisionLabel;
    final riskLevel = proposal.confidenceScore >= 0.85
        ? 'Low'
        : proposal.confidenceScore >= 0.65
            ? 'Medium'
            : 'High';
    final riskColor = riskLevel == 'Low'
        ? tealSuccess
        : riskLevel == 'Medium'
            ? AppTheme.warning
            : AppTheme.aiRed;
    final actionColor = isPricing ? tealSuccess : goldAccent;

    return Container(
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: BoxDecoration(
        color: premiumPanelSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: actionColor.withValues(alpha: isCurrent ? 0.48 : 0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: actionColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isPricing
                      ? Icons.price_check_outlined
                      : Icons.fact_check_outlined,
                  color: actionColor,
                  size: 19,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: compact ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      decision,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(color: textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
              _statusPill(
                '${(proposal.confidenceScore * 100).clamp(0, 100).toStringAsFixed(0)}%',
                goldAccent,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            proposal.explanation,
            maxLines: compact ? 3 : null,
            overflow: compact ? TextOverflow.ellipsis : null,
            style: const TextStyle(
                color: Colors.white, fontSize: 12.5, height: 1.5),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _proposalMetaChip(
                  Icons.insights_outlined, 'Impact: $impact', tealSuccess),
              _proposalMetaChip(
                  Icons.shield_outlined, 'Risk: $riskLevel', riskColor),
              _proposalMetaChip(
                Icons.verified_user_outlined,
                'Status: ${executionState.statusLabel}',
                isCurrent ? goldAccent : textSecondary,
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (!compact && isPricing) ...[
            Command360DetailLine(
              icon: Icons.location_on_outlined,
              label: 'Destination',
              value: '${pricing['destination'] ?? '-'}',
            ),
            Command360DetailLine(
              icon: Icons.inventory_2_outlined,
              label: 'Estimated units',
              value: '${pricing['estimatedTotalBoxes'] ?? '-'}',
            ),
            Command360DetailLine(
              icon: Icons.price_change_outlined,
              label: 'Landed cost',
              value: '${pricing['landedCostPerUnit'] ?? '-'}',
            ),
            Command360DetailLine(
              icon: Icons.trending_up_rounded,
              label: 'Suggested price',
              value: '${pricing['suggestedPricePerUnit'] ?? '-'}',
            ),
          ] else if (!compact) ...[
            Command360DetailLine(
              icon: Icons.inventory_2_outlined,
              label: 'Item',
              value: '${inventory['name'] ?? inventory['productId'] ?? '-'}',
            ),
            Command360DetailLine(
              icon: Icons.format_list_numbered_rtl,
              label: 'Quantity',
              value: '${inventory['quantity'] ?? '-'}',
            ),
            Command360DetailLine(
              icon: Icons.payments_outlined,
              label: 'Amount',
              value: '${financial['totalAmount'] ?? '-'}',
            ),
          ] else ...[
            _actionInfoLine(
              icon: Icons.domain_verification_outlined,
              label: isPricing ? 'Pricing strategy' : 'Ledger and inventory',
            ),
            _actionInfoLine(
              icon: Icons.rule_outlined,
              label: executionState.canDelegateExecution
                  ? 'Ready for guarded execution'
                  : executionState.decisionLabel,
            ),
          ],
          SizedBox(height: compact ? 10 : 14),
          _buildEvidenceSection(
            proposal,
            compact: compact,
            generatedAt: generatedAt,
            impact: impact,
            riskLevel: riskLevel,
          ),
          SizedBox(height: compact ? 10 : 14),
          _buildDecisionTrail(
            proposal,
            compact: compact,
            generatedAt: generatedAt,
            executionState: executionState,
          ),
          if (!compact) ...[
            const SizedBox(height: 14),
            _buildOperatingTimeline(
              compact: false,
              proposalFilter: proposal,
            ),
          ],
          SizedBox(height: compact ? 12 : 16),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              if (source != _ActionCardSource.details)
                OutlinedButton.icon(
                  onPressed: () => _showActionExecutionDetails(
                    proposal,
                    generatedAt: generatedAt,
                  ),
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label: const Text('Review'),
                ),
              if (isPricing)
                FilledButton.icon(
                  onPressed: canExecute ? _savePricingSimulation : null,
                  icon: _isCommitting
                      ? _miniProgress()
                      : const Icon(Icons.save_outlined, size: 16),
                  label: Text(compact ? 'Approve' : 'Save simulation'),
                )
              else
                FilledButton.icon(
                  onPressed: canExecute ? _commitProposalToLedger : null,
                  icon: _isCommitting
                      ? _miniProgress()
                      : const Icon(Icons.check_circle_outline, size: 16),
                  label: Text(compact ? 'Execute' : 'Approve / Execute'),
                ),
              if (isPricing)
                OutlinedButton.icon(
                  onPressed: canExecute && source == _ActionCardSource.chat
                      ? _convertPricingToQuotation
                      : null,
                  icon: const Icon(Icons.request_quote_outlined, size: 16),
                  label: const Text('Convert to quote'),
                ),
              OutlinedButton.icon(
                onPressed: canDismiss
                    ? () => _deferProposal(proposal, generatedAt)
                    : null,
                icon: const Icon(Icons.close_rounded, size: 16),
                label: Text(compact ? 'Not now' : 'Dismiss'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFollowUpLoop({required bool compact}) {
    final items = _sessionFollowUpItems();
    if (items.isEmpty) {
      return const _ExecutiveEmptyLine(
        icon: Icons.pending_actions_outlined,
        label: 'No session follow-up yet',
      );
    }

    final visibleItems = items.take(compact ? 3 : 8).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _proposalMetaChip(
              Icons.pending_actions_outlined,
              '${items.length} session item${items.length == 1 ? '' : 's'}',
              goldAccent,
            ),
            _proposalMetaChip(
              Icons.lock_clock_outlined,
              'Session-level',
              textSecondary,
            ),
          ],
        ),
        SizedBox(height: compact ? 10 : 12),
        ...visibleItems.map((item) {
          final showGroup = !compact &&
              (visibleItems.indexOf(item) == 0 ||
                  visibleItems[visibleItems.indexOf(item) - 1].status !=
                      item.status);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showGroup) ...[
                Text(
                  _followUpStatusGroup(item.status),
                  style: const TextStyle(
                    color: textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 7),
              ],
              _buildFollowUpItem(item, compact: compact),
              SizedBox(height: compact ? 8 : 10),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildFollowUpItem(
    _SessionFollowUpItem item, {
    required bool compact,
  }) {
    final color = _followUpStatusColor(item.status);
    final timing = item.timestamp == null
        ? 'Session'
        : '${_followUpTimingPrefix(item.status)} ${_timeLabel(item.timestamp!)}';

    return Container(
      padding: EdgeInsets.all(compact ? 10 : 12),
      decoration: BoxDecoration(
        color: darkSurface.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(_followUpStatusIcon(item.status), color: color, size: 16),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  item.title,
                  maxLines: compact ? 2 : null,
                  overflow: compact ? TextOverflow.ellipsis : null,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    height: 1.25,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _statusPill(_followUpStatusLabel(item.status), color),
            ],
          ),
          const SizedBox(height: 8),
          _actionInfoLine(
            icon: Icons.priority_high_outlined,
            label: item.whyItMatters,
          ),
          _actionInfoLine(
            icon: Icons.next_plan_outlined,
            label: item.nextStep,
          ),
          Row(
            children: [
              const Icon(
                Icons.schedule_outlined,
                color: textSecondary,
                size: 14,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  '$timing - session-level memory',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: textSecondary,
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<_SessionFollowUpItem> _sessionFollowUpItems() {
    final items = <_SessionFollowUpItem>[];
    final currentProposal = _activeProposal ?? _confirmationProposal;

    if (currentProposal != null) {
      items.add(
        _SessionFollowUpItem(
          title: _proposalActionTitle(currentProposal),
          status: _FollowUpStatus.awaitingApproval,
          whyItMatters: _proposalFinancialImpact(currentProposal),
          nextStep: _requiredDecisionLabel(
            currentProposal,
            isCurrent: true,
          ),
          timestamp: _proposalGeneratedAt(currentProposal),
        ),
      );
    }

    for (final message in _messages.reversed) {
      final proposal = message.proposal;
      if (proposal == null) continue;
      if (!_proposalSessionState.isReviewed(_proposalSessionId(proposal))) {
        continue;
      }
      if (identical(proposal, currentProposal)) continue;
      items.add(
        _SessionFollowUpItem(
          title: _proposalActionTitle(proposal),
          status: _FollowUpStatus.reviewed,
          whyItMatters: _proposalFinancialImpact(proposal),
          nextStep: 'Keep reviewing or ask AI CFO for the next action.',
          timestamp: message.timestamp,
        ),
      );
    }

    items.addAll(_deferredFollowUps.reversed);

    for (final message in _messages.reversed) {
      final result = message.executionResult;
      if (result == null) continue;
      items.add(
        _SessionFollowUpItem(
          title:
              result.isSuccess ? 'Execution completed' : 'Execution follow-up',
          status: result.isSuccess
              ? _FollowUpStatus.completed
              : _FollowUpStatus.awaitingApproval,
          whyItMatters: _resultSummary(result),
          nextStep: result.isSuccess
              ? 'Review the synced result and continue monitoring.'
              : 'Review the blocking message before trying again.',
          timestamp: message.timestamp,
        ),
      );
    }

    return items;
  }

  Widget _buildOperatingTimeline({
    required bool compact,
    AiProposalModel? proposalFilter,
  }) {
    final entries = _operatingTimelineEntries(proposalFilter: proposalFilter);
    if (entries.isEmpty) {
      return const _ExecutiveEmptyLine(
        icon: Icons.timeline_outlined,
        label: 'No session timeline events yet',
      );
    }

    final visibleEntries = entries.take(compact ? 4 : 12).toList();
    return Container(
      padding: EdgeInsets.all(compact ? 10 : 12),
      decoration: BoxDecoration(
        color: darkSurface.withValues(alpha: compact ? 0.34 : 0.45),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: premiumStroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.timeline_outlined, color: goldAccent, size: 15),
              const SizedBox(width: 7),
              const Expanded(
                child: Text(
                  'CFO Operating Timeline',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _statusPill('Session-level', textSecondary),
            ],
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _proposalMetaChip(
                Icons.route_outlined,
                '${entries.length} event${entries.length == 1 ? '' : 's'}',
                goldAccent,
              ),
              _proposalMetaChip(
                Icons.lock_clock_outlined,
                'No persistent history',
                textSecondary,
              ),
            ],
          ),
          SizedBox(height: compact ? 10 : 12),
          ...visibleEntries.map(
            (entry) => _buildOperatingTimelineEntry(
              entry,
              compact: compact,
              isLast: visibleEntries.last == entry,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOperatingTimelineEntry(
    _OperatingTimelineEntry entry, {
    required bool compact,
    required bool isLast,
  }) {
    final color = _timelineEventColor(entry.type);
    final timing = entry.timestamp == null
        ? 'Session'
        : '${_timelineTimingPrefix(entry.type)} ${_timeLabel(entry.timestamp!)}';

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : (compact ? 9 : 12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withValues(alpha: 0.34)),
                ),
                child: Icon(_timelineEventIcon(entry.type),
                    color: color, size: 14),
              ),
              if (!isLast)
                Container(
                  width: 1,
                  height: compact ? 58 : 78,
                  color: premiumStroke,
                ),
            ],
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Container(
              padding: EdgeInsets.all(compact ? 9 : 11),
              decoration: BoxDecoration(
                color: premiumPanelSoft.withValues(alpha: 0.56),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        entry.title,
                        maxLines: compact ? 2 : null,
                        overflow: compact ? TextOverflow.ellipsis : null,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                          height: 1.25,
                        ),
                      ),
                      _statusPill(_timelineEventLabel(entry.type), color),
                    ],
                  ),
                  const SizedBox(height: 7),
                  _actionInfoLine(
                    icon: Icons.schedule_outlined,
                    label: '$timing - session-level event',
                  ),
                  _actionInfoLine(
                    icon: Icons.source_outlined,
                    label: entry.reason,
                  ),
                  if (!compact)
                    _actionInfoLine(
                      icon: Icons.next_plan_outlined,
                      label: entry.nextStep,
                    )
                  else
                    Text(
                      entry.nextStep,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: textSecondary,
                        fontSize: 11,
                        height: 1.3,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<_OperatingTimelineEntry> _operatingTimelineEntries({
    AiProposalModel? proposalFilter,
  }) {
    final entries = <_OperatingTimelineEntry>[];
    final currentProposal = _activeProposal ?? _confirmationProposal;

    bool includeProposal(AiProposalModel? proposal) {
      return proposalFilter == null ||
          (proposal != null && identical(proposal, proposalFilter));
    }

    for (final message in _messages.reversed) {
      final proposal = message.proposal;
      if (proposal == null || !includeProposal(proposal)) continue;
      final isCurrent = identical(proposal, currentProposal);
      entries.add(
        _OperatingTimelineEntry(
          title: _proposalActionTitle(proposal),
          type: _OperatingTimelineEventType.proposalGenerated,
          reason: proposal.explanation,
          nextStep: isCurrent
              ? _requiredDecisionLabel(proposal, isCurrent: true)
              : 'Keep this as review-only session context.',
          timestamp: message.timestamp,
          proposal: proposal,
        ),
      );
      if (_proposalSessionState.isReviewed(_proposalSessionId(proposal))) {
        entries.add(
          _OperatingTimelineEntry(
            title: _proposalActionTitle(proposal),
            type: _OperatingTimelineEventType.reviewed,
            reason: _proposalFinancialImpact(proposal),
            nextStep: isCurrent
                ? _requiredDecisionLabel(proposal, isCurrent: true)
                : 'Ask AI CFO for another action or keep monitoring.',
            timestamp: message.timestamp,
            proposal: proposal,
          ),
        );
      }
      if (isCurrent) {
        entries.add(
          _OperatingTimelineEntry(
            title: _proposalActionTitle(proposal),
            type: _OperatingTimelineEventType.awaitingApproval,
            reason: _proposalFinancialImpact(proposal),
            nextStep: _requiredDecisionLabel(proposal, isCurrent: true),
            timestamp: message.timestamp,
            proposal: proposal,
          ),
        );
      }
    }

    if (proposalFilter == null) {
      for (final item in _deferredFollowUps.reversed) {
        entries.add(
          _OperatingTimelineEntry(
            title: item.title,
            type: _OperatingTimelineEventType.deferred,
            reason: item.whyItMatters,
            nextStep: item.nextStep,
            timestamp: item.timestamp,
          ),
        );
      }
    }

    for (final message in _messages.reversed) {
      final result = message.executionResult;
      if (result == null || proposalFilter != null) continue;
      entries.add(
        _OperatingTimelineEntry(
          title:
              result.isSuccess ? 'Execution completed' : 'Follow-up required',
          type: result.isSuccess
              ? _OperatingTimelineEventType.executed
              : _OperatingTimelineEventType.followUpNeeded,
          reason: _resultSummary(result),
          nextStep: result.isSuccess
              ? 'Review the synced result and continue monitoring.'
              : 'Review the blocking message before trying again.',
          timestamp: message.timestamp,
        ),
      );
    }

    return entries;
  }

  String _timelineEventLabel(_OperatingTimelineEventType type) {
    switch (type) {
      case _OperatingTimelineEventType.proposalGenerated:
        return 'Generated';
      case _OperatingTimelineEventType.reviewed:
        return 'Reviewed';
      case _OperatingTimelineEventType.awaitingApproval:
        return 'Awaiting';
      case _OperatingTimelineEventType.deferred:
        return 'Deferred';
      case _OperatingTimelineEventType.executed:
        return 'Executed';
      case _OperatingTimelineEventType.followUpNeeded:
        return 'Follow-up';
    }
  }

  String _timelineTimingPrefix(_OperatingTimelineEventType type) {
    switch (type) {
      case _OperatingTimelineEventType.proposalGenerated:
        return 'Generated';
      case _OperatingTimelineEventType.reviewed:
        return 'Reviewed';
      case _OperatingTimelineEventType.awaitingApproval:
        return 'Awaiting since';
      case _OperatingTimelineEventType.deferred:
        return 'Deferred';
      case _OperatingTimelineEventType.executed:
        return 'Executed';
      case _OperatingTimelineEventType.followUpNeeded:
        return 'Flagged';
    }
  }

  IconData _timelineEventIcon(_OperatingTimelineEventType type) {
    switch (type) {
      case _OperatingTimelineEventType.proposalGenerated:
        return Icons.auto_awesome_outlined;
      case _OperatingTimelineEventType.reviewed:
        return Icons.visibility_outlined;
      case _OperatingTimelineEventType.awaitingApproval:
        return Icons.rule_outlined;
      case _OperatingTimelineEventType.deferred:
        return Icons.pause_circle_outline;
      case _OperatingTimelineEventType.executed:
        return Icons.check_circle_outline;
      case _OperatingTimelineEventType.followUpNeeded:
        return Icons.pending_actions_outlined;
    }
  }

  Color _timelineEventColor(_OperatingTimelineEventType type) {
    switch (type) {
      case _OperatingTimelineEventType.proposalGenerated:
        return tealSuccess;
      case _OperatingTimelineEventType.reviewed:
        return AppTheme.accentCyan;
      case _OperatingTimelineEventType.awaitingApproval:
        return goldAccent;
      case _OperatingTimelineEventType.deferred:
        return AppTheme.warning;
      case _OperatingTimelineEventType.executed:
        return tealSuccess;
      case _OperatingTimelineEventType.followUpNeeded:
        return AppTheme.aiRed;
    }
  }

  void _deferProposal(AiProposalModel proposal, DateTime? generatedAt) {
    setState(() {
      _recordProposalState(
        AiCfoProposalStateEvent(
          type: AiCfoProposalStateEventType.deferred,
          proposal: proposal,
          reason: 'Proposal deferred in session.',
          occurredAt: DateTime.now(),
        ),
      );
      _deferredFollowUps.add(
        _SessionFollowUpItem(
          title: _proposalActionTitle(proposal),
          status: _FollowUpStatus.deferred,
          whyItMatters: _proposalFinancialImpact(proposal),
          nextStep: 'Return to this action from the session follow-up loop.',
          timestamp: generatedAt ?? _proposalGeneratedAt(proposal),
        ),
      );
      if (identical(_activeProposal, proposal)) {
        _activeProposal = null;
      }
      if (identical(_confirmationProposal, proposal)) {
        _confirmationProposal = null;
      }
      _ledgerRows.removeWhere(
        (row) => row.code == 'PENDING-AI',
      );
    });
  }

  String _followUpStatusLabel(_FollowUpStatus status) {
    switch (status) {
      case _FollowUpStatus.awaitingApproval:
        return 'Awaiting';
      case _FollowUpStatus.reviewed:
        return 'Reviewed';
      case _FollowUpStatus.deferred:
        return 'Deferred';
      case _FollowUpStatus.completed:
        return 'Completed';
    }
  }

  String _followUpStatusGroup(_FollowUpStatus status) {
    switch (status) {
      case _FollowUpStatus.awaitingApproval:
        return 'Awaiting approval';
      case _FollowUpStatus.reviewed:
        return 'Reviewed';
      case _FollowUpStatus.deferred:
        return 'Deferred / Not now';
      case _FollowUpStatus.completed:
        return 'Completed / executed';
    }
  }

  String _followUpTimingPrefix(_FollowUpStatus status) {
    switch (status) {
      case _FollowUpStatus.awaitingApproval:
        return 'Generated';
      case _FollowUpStatus.reviewed:
        return 'Reviewed';
      case _FollowUpStatus.deferred:
        return 'Deferred';
      case _FollowUpStatus.completed:
        return 'Completed';
    }
  }

  IconData _followUpStatusIcon(_FollowUpStatus status) {
    switch (status) {
      case _FollowUpStatus.awaitingApproval:
        return Icons.rule_outlined;
      case _FollowUpStatus.reviewed:
        return Icons.visibility_outlined;
      case _FollowUpStatus.deferred:
        return Icons.pause_circle_outline;
      case _FollowUpStatus.completed:
        return Icons.check_circle_outline;
    }
  }

  Color _followUpStatusColor(_FollowUpStatus status) {
    switch (status) {
      case _FollowUpStatus.awaitingApproval:
        return goldAccent;
      case _FollowUpStatus.reviewed:
        return tealSuccess;
      case _FollowUpStatus.deferred:
        return AppTheme.warning;
      case _FollowUpStatus.completed:
        return tealSuccess;
    }
  }

  Widget _buildEvidenceSection(
    AiProposalModel proposal, {
    required bool compact,
    required DateTime? generatedAt,
    required String impact,
    required String riskLevel,
  }) {
    final signals = _proposalEvidenceSignals(proposal);
    final shownSignals = signals.take(compact ? 3 : 5).toList();
    final timing = generatedAt == null
        ? (compact ? 'Session' : 'Session-level evidence')
        : (compact
            ? _timeLabel(generatedAt)
            : 'Generated ${_timeLabel(generatedAt)}');

    return Container(
      padding: EdgeInsets.all(compact ? 10 : 12),
      decoration: BoxDecoration(
        color: darkSurface.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: premiumStroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.source_outlined, color: goldAccent, size: 15),
              const SizedBox(width: 7),
              const Expanded(
                child: Text(
                  'Evidence',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _statusPill(timing, textSecondary),
            ],
          ),
          const SizedBox(height: 9),
          _evidenceLine(
            icon: Icons.psychology_alt_outlined,
            label: 'Reason',
            value: proposal.explanation,
            compact: compact,
          ),
          _evidenceLine(
            icon: Icons.payments_outlined,
            label: 'Impact',
            value: impact,
            compact: compact,
          ),
          _evidenceLine(
            icon: Icons.warning_amber_rounded,
            label: 'Risk note',
            value: _proposalRiskNote(proposal, riskLevel),
            compact: compact,
          ),
          _evidenceLine(
            icon: Icons.verified_user_outlined,
            label: 'Confidence',
            value:
                '${(proposal.confidenceScore * 100).clamp(0, 100).toStringAsFixed(0)}% - ${_proposalStatusLabel(proposal)}',
            compact: compact,
          ),
          if (shownSignals.isNotEmpty) ...[
            const SizedBox(height: 4),
            ...shownSignals.map(
              (signal) => _evidenceLine(
                icon: Icons.query_stats_outlined,
                label: 'Signal',
                value: signal,
                compact: compact,
              ),
            ),
          ] else
            _evidenceLine(
              icon: Icons.info_outline,
              label: 'Signal',
              value: 'No structured payload available for this card',
              compact: compact,
            ),
        ],
      ),
    );
  }

  Widget _buildDecisionTrail(
    AiProposalModel proposal, {
    required bool compact,
    required DateTime? generatedAt,
    required AiCfoProposalExecutionPresentationState executionState,
  }) {
    final isCurrent = _isCurrentActionProposal(proposal);
    final reviewed = _proposalSessionState.isReviewed(
      _proposalSessionId(proposal),
    );
    final generatedLabel = generatedAt == null
        ? 'Proposal available in current session'
        : 'Proposal generated at ${_timeLabel(generatedAt)}';
    final executionLabel = executionState.executionLabel;

    return Container(
      padding: EdgeInsets.all(compact ? 10 : 12),
      decoration: BoxDecoration(
        color: darkSurface.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: premiumStroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.timeline_outlined, color: tealSuccess, size: 15),
              const SizedBox(width: 7),
              const Expanded(
                child: Text(
                  'Decision Trail',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _statusPill('Session', tealSuccess),
            ],
          ),
          const SizedBox(height: 9),
          _trailLine(
            icon: Icons.auto_awesome_outlined,
            label: generatedLabel,
            color: tealSuccess,
          ),
          _trailLine(
            icon: Icons.visibility_outlined,
            label: reviewed
                ? 'Reviewed in this session'
                : 'Review not opened in this session',
            color: reviewed ? tealSuccess : textSecondary,
          ),
          _trailLine(
            icon: Icons.rule_outlined,
            label: executionState.decisionLabel,
            color: isCurrent ? goldAccent : textSecondary,
          ),
          if (!compact)
            _trailLine(
              icon: Icons.lock_clock_outlined,
              label: executionLabel,
              color: textSecondary,
            ),
        ],
      ),
    );
  }

  Widget _evidenceLine({
    required IconData icon,
    required String label,
    required String value,
    required bool compact,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: textSecondary, size: 14),
          const SizedBox(width: 7),
          SizedBox(
            width: compact ? 64 : 84,
            child: Text(
              label,
              style: const TextStyle(
                color: textSecondary,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              value,
              maxLines: compact ? 2 : null,
              overflow: compact ? TextOverflow.ellipsis : null,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11.5,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _trailLine({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: textSecondary,
                fontSize: 11.5,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<String> _proposalEvidenceSignals(AiProposalModel proposal) {
    final signals = <String>[];
    final inventory = proposal.inventoryPayload ?? const <String, dynamic>{};
    final financial = proposal.financialPayload ?? const <String, dynamic>{};
    final pricing = proposal.pricingPayload ?? const <String, dynamic>{};
    final customer = proposal.customerPayload ?? const <String, dynamic>{};

    void addSignal(String label, Object? value) {
      if (value == null) return;
      final text = '$value'.trim();
      if (text.isEmpty || text == '0.0' || text == '0') return;
      signals.add('$label: $text');
    }

    addSignal('Action type', proposal.actionType);
    addSignal('Item', inventory['name'] ?? inventory['productId']);
    addSignal('Quantity', inventory['quantity']);
    addSignal('Cost price', inventory['costPrice']);
    addSignal('Customer', customer['name'] ?? customer['customerName']);
    addSignal('Total amount', financial['totalAmount']);
    addSignal('Amount paid', financial['amountPaid']);
    addSignal('Destination', pricing['destination']);
    addSignal('Estimated units', pricing['estimatedTotalBoxes']);
    addSignal('Landed cost/unit', pricing['landedCostPerUnit']);
    addSignal('Suggested price/unit', pricing['suggestedPricePerUnit']);
    addSignal('Target margin', pricing['targetMarginPercentage']);

    return signals;
  }

  String _proposalRiskNote(AiProposalModel proposal, String riskLevel) {
    final executionState = _proposalExecutionState(proposal);
    if (executionState.state == AiCfoProposalExecutionUxState.deferred) {
      return '$riskLevel risk - deferred in this session';
    }
    if (executionState.state == AiCfoProposalExecutionUxState.failed) {
      return '$riskLevel risk - failed and needs follow-up';
    }
    if (executionState.state == AiCfoProposalExecutionUxState.blocked) {
      return '$riskLevel risk - blocked and needs follow-up';
    }
    if (executionState.state == AiCfoProposalExecutionUxState.executed) {
      return '$riskLevel risk - already executed';
    }
    if (identical(_confirmationProposal, proposal)) {
      return '$riskLevel risk - confirmation required before execution';
    }
    if (!_isCurrentActionProposal(proposal)) {
      return '$riskLevel risk - historical/review-only card';
    }
    if (!_isExecutableProposal(proposal)) {
      return '$riskLevel risk - execution is not wired for this action';
    }
    return '$riskLevel risk - guarded by user approval';
  }

  String _proposalStatusLabel(AiProposalModel proposal) {
    final executionState = _proposalExecutionState(proposal);
    if (executionState.state == AiCfoProposalExecutionUxState.deferred ||
        executionState.isTerminal ||
        executionState.state == AiCfoProposalExecutionUxState.executing) {
      return executionState.statusLabel.toLowerCase();
    }
    if (identical(_activeProposal, proposal)) return 'active proposal';
    if (identical(_confirmationProposal, proposal)) {
      return 'awaiting confirmation';
    }
    return 'review-only';
  }

  DateTime? _proposalGeneratedAt(AiProposalModel proposal) {
    for (final message in _messages.reversed) {
      if (identical(message.proposal, proposal)) return message.timestamp;
    }
    return null;
  }

  bool _isCurrentActionProposal(AiProposalModel proposal) {
    return identical(_activeProposal, proposal) ||
        identical(_confirmationProposal, proposal);
  }

  String _proposalActionTitle(AiProposalModel proposal) {
    switch (proposal.actionType) {
      case 'purchase':
        return 'Approve purchase action';
      case 'sale':
        return 'Approve sales action';
      case 'pricing_simulation':
        return 'Review pricing action';
      default:
        return 'Review CFO action';
    }
  }

  String _proposalFinancialImpact(AiProposalModel proposal) {
    final financial = proposal.financialPayload ?? const <String, dynamic>{};
    final pricing = proposal.pricingPayload ?? const <String, dynamic>{};
    final total = financial['totalAmount'];
    if (total != null) return '$total total value';
    final suggestedPrice = pricing['suggestedPricePerUnit'];
    if (suggestedPrice != null) return '$suggestedPrice suggested/unit';
    final margin = pricing['targetMarginPercentage'];
    if (margin != null) return '$margin% target margin';
    return 'Needs review';
  }

  String _requiredDecisionLabel(
    AiProposalModel proposal, {
    required bool isCurrent,
  }) {
    return _proposalExecutionState(
      proposal,
      isCurrent: isCurrent,
    ).decisionLabel;
  }

  Widget _actionInfoLine({
    required IconData icon,
    required String label,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: textSecondary, size: 15),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: textSecondary,
                fontSize: 11,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showActionExecutionDetails(
    AiProposalModel proposal, {
    DateTime? generatedAt,
  }) {
    setState(() {
      _recordProposalState(
        AiCfoProposalStateEvent(
          type: AiCfoProposalStateEventType.reviewed,
          proposal: proposal,
          reason: 'Proposal reviewed in session.',
          occurredAt: DateTime.now(),
        ),
      );
    });

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: premiumPanel,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: premiumStroke),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Action details',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close',
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(
                            Icons.close_rounded,
                            color: textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildActionExecutionCard(
                      proposal,
                      compact: false,
                      source: _ActionCardSource.details,
                      generatedAt:
                          generatedAt ?? _proposalGeneratedAt(proposal),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'CFO Follow-up Loop',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildFollowUpLoop(compact: false),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _proposalMetaChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExecutionResultCard(ProposalExecutionResult result) {
    final data = _asMap(result.data);
    final product = _asMap(data['product']);
    final invoice = _asMap(data['invoice']);
    final journal = _asMap(data['journalEntry']);
    final pricing = _asMap(data['pricingSimulation']);
    final sync = _asMap(data['syncQueue']);
    final audit = _asMap(data['auditLog']);
    final candidates = _asMapList(data['candidates']);
    final partialSync =
        result.success && audit['status']?.toString() == 'failed';
    final statusColor = result.requiresUserConfirmation
        ? goldAccent
        : result.success
            ? (partialSync ? AppTheme.warning : tealSuccess)
            : AppTheme.aiRed;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.aiCardElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withValues(alpha: 0.65)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(_statusIcon(result, partialSync),
                  color: statusColor, size: 19),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _statusLabel(result, data),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const Divider(color: borderTerminal, height: 22),
          Text(
            result.message ?? result.error ?? 'No additional details.',
            style:
                const TextStyle(color: Colors.white, fontSize: 12, height: 1.5),
          ),
          const SizedBox(height: 12),
          if (product.isNotEmpty)
            Command360DetailLine(
              icon: Icons.inventory_2_outlined,
              label: 'Product',
              value: '${product['id'] ?? '-'} | ${product['name'] ?? '-'}',
            ),
          if (invoice.isNotEmpty)
            Command360DetailLine(
              icon: Icons.receipt_long_outlined,
              label: 'Invoice',
              value: '${invoice['id'] ?? '-'} | ${invoice['number'] ?? '-'}',
            ),
          if (journal.isNotEmpty)
            Command360DetailLine(
              icon: Icons.account_balance_outlined,
              label: 'Journal',
              value: '${journal['id'] ?? '-'} | ${journal['code'] ?? '-'}',
            ),
          if (pricing.isNotEmpty)
            Command360DetailLine(
              icon: Icons.price_check_outlined,
              label: 'Pricing simulation',
              value:
                  '${pricing['id'] ?? '-'} | ${pricing['suggestedPrice'] ?? pricing['suggestedPricePerUnit'] ?? '-'}',
            ),
          Command360DetailLine(
            icon: Icons.sync_rounded,
            label: 'Sync',
            value:
                sync['status']?.toString() ?? (result.success ? 'queued' : '-'),
          ),
          Command360DetailLine(
            icon: Icons.fact_check_outlined,
            label: 'Audit',
            value: audit['status']?.toString() ??
                (result.success ? 'stored' : '-'),
          ),
          if (result.requiresUserConfirmation && candidates.isNotEmpty)
            _buildCandidateProductList(candidates),
          if (data['reason'] == 'missing_chart_accounts')
            _buildChartSetupAction(),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              if ((product['id'] ?? '').toString().isNotEmpty)
                TextButton.icon(
                  onPressed: () => _openProduct(product['id'].toString()),
                  icon: const Icon(Icons.inventory_2_outlined, size: 16),
                  label: const Text('Open product'),
                ),
              if ((invoice['id'] ?? '').toString().isNotEmpty)
                TextButton.icon(
                  onPressed: () => _openInvoice(invoice['id'].toString()),
                  icon: const Icon(Icons.receipt_long_outlined, size: 16),
                  label: const Text('Open invoice'),
                ),
              if ((journal['id'] ?? '').toString().isNotEmpty)
                TextButton.icon(
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content:
                          Text('Review the journal entry in ledger context.'),
                    ),
                  ),
                  icon: const Icon(Icons.account_balance_outlined, size: 16),
                  label: const Text('Show journal'),
                ),
              TextButton.icon(
                onPressed: () => _copyExecutionSummary(result),
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: const Text('Copy summary'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCandidateProductList(List<Map<String, dynamic>> candidates) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: goldAccent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: goldAccent.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Choose the correct product before execution',
            style: TextStyle(
              color: goldAccent,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          ...candidates.map((candidate) {
            final id =
                (candidate['id'] ?? candidate['productId'] ?? '').toString();
            final name = (candidate['name'] ??
                    candidate['productName'] ??
                    'Unnamed item')
                .toString();
            final stock =
                (candidate['stock'] ?? candidate['quantity'] ?? '-').toString();
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: OutlinedButton(
                onPressed: _isCommitting || id.isEmpty
                    ? null
                    : () => _confirmProductAndExecute(id),
                style:
                    OutlinedButton.styleFrom(alignment: Alignment.centerLeft),
                child: Text(
                  '$name | $id | stock: $stock',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildChartSetupAction() {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: OutlinedButton.icon(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SettingsScreen()),
        ),
        icon: const Icon(Icons.settings_outlined, size: 16),
        label: const Text('Complete chart of accounts setup'),
      ),
    );
  }

  Widget _statusPill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Text(
        label,
        style:
            TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _miniProgress() {
    return const SizedBox(
      width: 16,
      height: 16,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }

  // ignore: unused_element
  Widget _buildQuickPromptsStrip() {
    final prompts = [
      'I want to export chocolate to Saudi Arabia. What do you recommend?',
      'Is a 25% margin suitable?',
      'I bought 150 cartons of chocolate at 85 dollars cash',
    ];
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: prompts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          return ActionChip(
            backgroundColor: darkSurface,
            side: const BorderSide(color: borderTerminal),
            label: Text(
              prompts[index],
              style: const TextStyle(color: textSecondary, fontSize: 11),
            ),
            onPressed: _isAnalyzing || _isCommitting
                ? null
                : () => _processAiCommand(customText: prompts[index]),
          );
        },
      ),
    );
  }

  Widget _buildInputField() {
    return Container(
      decoration: BoxDecoration(
        color: darkSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderTerminal),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              textInputAction: TextInputAction.send,
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.symmetric(horizontal: 14),
                hintText:
                    'Ask about invoices, cash, expenses, or any financial topic...',
                hintStyle: TextStyle(color: AppTheme.aiTextMuted, fontSize: 12),
                border: InputBorder.none,
              ),
              onSubmitted: (_) => _processAiCommand(),
            ),
          ),
          IconButton(
            tooltip: 'Send',
            icon: _isAnalyzing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      color: goldAccent,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.send_rounded, color: goldAccent, size: 18),
            onPressed: _isAnalyzing || _isCommitting
                ? null
                : () => _processAiCommand(),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  bool _isExecutionIntent(String text) {
    final normalized = _normalized(text);
    return _containsAny(normalized, [
      'execute',
      'approve',
      'save',
      'commit',
      'confirm',
      'convert',
      'حول',
      'حولها',
      'نفذ',
      'اعتمد',
      'احفظ',
      'ثبت',
      'اكد',
      'أكد',
      'حول',
    ]);
  }

  // ignore: unused_element
  bool _isClearTransactionCommand(String normalized) {
    return _containsAny(normalized, [
      'bought',
      'purchased',
      'sold',
      'sale',
      'purchase',
      'invoice',
      'quotation',
      'quote',
      'pricing simulation',
      'calculate price',
      'run pricing',
      'اشتريت',
      'اشتر',
      'شراء',
      'بعت',
      'بيع',
      'فاتورة',
      'عرض سعر',
      'تسعير',
      'احسب سعر',
      'اشتريت',
      'اشتر',
      'شراء',
      'بعت',
      'بيع',
      'فاتورة',
      'عرض سعر',
      'تسعير',
      'احسب سعر',
    ]);
  }

  // ignore: unused_element
  bool _isPreparationRequest(String normalized) {
    return _containsAny(normalized, [
      'prepare',
      'create proposal',
      'purchase proposal',
      'sale proposal',
      'prepare purchase',
      'prepare sale',
      'prepare pricing',
      'جهز',
      'حضّر',
      'حضر',
      'مقترح',
    ]);
  }

  bool _isExecutableProposal(AiProposalModel proposal) {
    return proposal.actionType == 'purchase' ||
        proposal.actionType == 'sale' ||
        proposal.actionType == 'pricing_simulation';
  }

  AiCfoProposalExecutionPresentationState _proposalExecutionState(
    AiProposalModel proposal, {
    bool? isCurrent,
  }) {
    final current = isCurrent ?? _isCurrentActionProposal(proposal);
    return AiCfoProposalExecutionPresentationState.resolve(
      proposal: proposal,
      proposalSessionId: _proposalSessionId(proposal),
      sessionState: _proposalSessionState,
      isCurrent: current,
      requiresConfirmation: identical(_confirmationProposal, proposal),
      isExecuting: _isCommitting,
    );
  }

  bool _canDelegateProposalExecution(AiProposalModel proposal) {
    return _proposalExecutionState(
      proposal,
      isCurrent: identical(_activeProposal, proposal),
    ).canDelegateExecution;
  }

  bool _guardProposalExecutionRequest(AiProposalModel proposal) {
    final state = _proposalExecutionState(
      proposal,
      isCurrent: identical(_activeProposal, proposal),
    );
    if (state.canDelegateExecution) return true;
    _appendExecutionGuardMessage(state.decisionLabel);
    return false;
  }

  void _appendExecutionGuardMessage(String text) {
    _appendMessage(
      role: AiChatRole.assistant,
      type: AiChatMessageType.confirmation,
      text: text,
      suggestedReplies: const [
        'Review proposal',
        'What is missing?',
        'Continue discussion',
      ],
    );
  }

  List<String> _proposalSuggestedReplies(AiProposalModel proposal) {
    if (proposal.actionType == 'pricing_simulation') {
      return _lastInputWasArabic
          ? const [
              'اشرح التسعير',
              'حول لعرض سعر',
              'قارن الهوامش',
            ]
          : const [
              'Explain this pricing',
              'Convert to quote',
              'Compare margins',
            ];
    }
    return _lastInputWasArabic
        ? const [
            'وافق',
            'اشرح الأثر المحاسبي',
            'غير التفاصيل',
          ]
        : const [
            'Approve',
            'Explain accounting impact',
            'Change details',
          ];
  }

  bool _containsAny(String value, List<String> needles) {
    return needles.any(value.contains);
  }

  String _normalized(String value) {
    return value.toLowerCase().trim();
  }

  String _workflowTitle(AiWorkflowType type) {
    switch (type) {
      case AiWorkflowType.purchase:
        return 'Purchase';
      case AiWorkflowType.sale:
        return 'Sale';
      case AiWorkflowType.pricing:
        return 'Pricing';
      case AiWorkflowType.inventoryAdjustment:
        return 'Inventory Adjustment';
      case AiWorkflowType.customerBalanceInquiry:
        return 'Customer Balance';
      case AiWorkflowType.supplierInquiry:
        return 'Supplier';
    }
  }

  String _timeLabel(DateTime timestamp) {
    final hour = timestamp.hour.toString().padLeft(2, '0');
    final minute = timestamp.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  List<Map<String, dynamic>> _asMapList(dynamic value) {
    if (value is! List) return <Map<String, dynamic>>[];
    return value
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  String _statusLabel(
      ProposalExecutionResult result, Map<String, dynamic> data) {
    if (result.requiresUserConfirmation) return 'Needs confirmation';
    if (result.success && _asMap(data['auditLog'])['status'] == 'failed') {
      return 'Executed with partial sync';
    }
    if (result.success) return 'Executed';
    return 'Execution blocked';
  }

  IconData _statusIcon(ProposalExecutionResult result, bool partialSync) {
    if (result.requiresUserConfirmation) return Icons.rule_folder_outlined;
    if (partialSync) return Icons.sync_problem_outlined;
    if (result.success) return Icons.verified_rounded;
    return Icons.report_problem_outlined;
  }

  IconData _messageIcon(AiChatMessageType type) {
    switch (type) {
      case AiChatMessageType.recommendation:
        return Icons.psychology_alt_outlined;
      case AiChatMessageType.question:
        return Icons.help_outline_rounded;
      case AiChatMessageType.scenarioComparison:
        return Icons.compare_arrows_rounded;
      case AiChatMessageType.proposal:
        return Icons.fact_check_outlined;
      case AiChatMessageType.confirmation:
        return Icons.rule_folder_outlined;
      case AiChatMessageType.executionResult:
        return Icons.verified_outlined;
      case AiChatMessageType.error:
        return Icons.report_problem_outlined;
      case AiChatMessageType.normal:
        return Icons.account_balance_outlined;
    }
  }

  AiChatMessageType _messageTypeForMode(AiAdvisorMode mode) {
    switch (mode) {
      case AiAdvisorMode.chat:
        return AiChatMessageType.normal;
      case AiAdvisorMode.advice:
      case AiAdvisorMode.analysis:
        return AiChatMessageType.recommendation;
      case AiAdvisorMode.pricing:
      case AiAdvisorMode.export:
        return AiChatMessageType.scenarioComparison;
      case AiAdvisorMode.proposalReview:
        return AiChatMessageType.proposal;
      case AiAdvisorMode.executionGuard:
        return AiChatMessageType.confirmation;
    }
  }

  Color _messageColor(AiChatMessageType type) {
    switch (type) {
      case AiChatMessageType.recommendation:
      case AiChatMessageType.scenarioComparison:
        return tealSuccess;
      case AiChatMessageType.question:
      case AiChatMessageType.proposal:
      case AiChatMessageType.confirmation:
        return goldAccent;
      case AiChatMessageType.executionResult:
        return AppTheme.aiGreen;
      case AiChatMessageType.error:
        return AppTheme.aiRed;
      case AiChatMessageType.normal:
        return textSecondary;
    }
  }

  Color _confidenceColor(AiEvidenceConfidence confidence) {
    switch (confidence) {
      case AiEvidenceConfidence.high:
        return tealSuccess;
      case AiEvidenceConfidence.medium:
        return goldAccent;
      case AiEvidenceConfidence.low:
        return AppTheme.aiRed;
    }
  }
}

class _CommandSection extends StatelessWidget {
  const _CommandSection({
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _AiAccountantScreenState.premiumPanel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _AiAccountantScreenState.premiumStroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          color: _AiAccountantScreenState.textSecondary,
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 12),
                trailing!,
              ],
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _CommandSignalData {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool hasEvidence;

  const _CommandSignalData({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.hasEvidence,
  });
}

class _CommandSignalCard extends StatelessWidget {
  final _CommandSignalData signal;

  const _CommandSignalCard({required this.signal});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 82),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _AiAccountantScreenState.premiumPanelSoft.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: signal.hasEvidence
              ? signal.color.withValues(alpha: 0.32)
              : _AiAccountantScreenState.premiumStroke,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: signal.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(signal.icon, color: signal.color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  signal.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _AiAccountantScreenState.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  signal.value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: signal.hasEvidence
                        ? Colors.white
                        : _AiAccountantScreenState.textSecondary,
                    fontSize: 12,
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExecutiveKpiData {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _ExecutiveKpiData({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
}

class _ExecutiveKpiCard extends StatelessWidget {
  const _ExecutiveKpiCard({required this.data});

  final _ExecutiveKpiData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:
            _AiAccountantScreenState.premiumPanelSoft.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _AiAccountantScreenState.premiumStroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: data.color.withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(data.icon, color: data.color, size: 16),
          ),
          const SizedBox(height: 8),
          Text(
            data.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _AiAccountantScreenState.textSecondary,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            data.value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w900,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExecutiveFindingTile extends StatelessWidget {
  const _ExecutiveFindingTile({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 220, maxWidth: 360),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _AiAccountantScreenState.goldAccent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _AiAccountantScreenState.goldAccent.withValues(alpha: 0.24),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.auto_awesome_outlined,
            color: _AiAccountantScreenState.goldAccent,
            size: 17,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExecutiveEmptyLine extends StatelessWidget {
  const _ExecutiveEmptyLine({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _AiAccountantScreenState.premiumPanelSoft.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _AiAccountantScreenState.premiumStroke),
      ),
      child: Row(
        children: [
          Icon(icon, color: _AiAccountantScreenState.textSecondary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _AiAccountantScreenState.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExecutiveRecommendationCard extends StatelessWidget {
  const _ExecutiveRecommendationCard({required this.item});

  final AiFinancialRecommendation item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:
            _AiAccountantScreenState.premiumPanelSoft.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _AiAccountantScreenState.tealSuccess.withValues(alpha: 0.24),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.task_alt_rounded,
            color: _AiAccountantScreenState.tealSuccess,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  item.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _AiAccountantScreenState.textSecondary,
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightData {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _InsightData(this.label, this.value, this.icon, this.color);
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.data});

  final _InsightData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 148,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _AiAccountantScreenState.premiumPanel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _AiAccountantScreenState.premiumStroke),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: data.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(data.icon, color: data.color, size: 17),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  data.label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _AiAccountantScreenState.textSecondary,
                    fontSize: 10.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  data.value,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Shared Colors Helper ─────────────────────────────────────────────────────

class _SheetColors {
  final Color premiumPanel;
  final Color premiumStroke;
  final Color goldAccent;
  final Color tealSuccess;
  final Color textSecondary;
  final Color darkBg;
  final Color premiumPanelSoft;

  const _SheetColors({
    required this.premiumPanel,
    required this.premiumStroke,
    required this.goldAccent,
    required this.tealSuccess,
    required this.textSecondary,
    required this.darkBg,
    required this.premiumPanelSoft,
  });

  factory _SheetColors.of(_AiAccountantScreenState s) => _SheetColors(
        premiumPanel: _AiAccountantScreenState.premiumPanel,
        premiumStroke: _AiAccountantScreenState.premiumStroke,
        goldAccent: _AiAccountantScreenState.goldAccent,
        tealSuccess: _AiAccountantScreenState.tealSuccess,
        textSecondary: _AiAccountantScreenState.textSecondary,
        darkBg: _AiAccountantScreenState.darkBg,
        premiumPanelSoft: _AiAccountantScreenState.premiumPanelSoft,
      );
}

class _SheetAction {
  final String label;
  final IconData icon;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;
  const _SheetAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.enabled = true,
  });
}

// ─── Generic Full-Height Sheet ────────────────────────────────────────────────

class _FullHeightSheet extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;
  final List<_SheetAction> actions;
  final _SheetColors colors;

  const _FullHeightSheet({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
    required this.colors,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final c = colors;
    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: 0.90,
        child: Container(
          margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          decoration: BoxDecoration(
            color: c.premiumPanel,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.premiumStroke),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
                child: Row(children: [
                  Icon(icon, color: c.goldAccent, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(title,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w900),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        if (subtitle.isNotEmpty)
                          Text(subtitle,
                              style: TextStyle(
                                  color: c.textSecondary, fontSize: 10)),
                      ])),
                  IconButton(
                    icon: Icon(Icons.close, color: c.textSecondary, size: 18),
                    onPressed: () => Navigator.pop(context),
                  ),
                ]),
              ),
              Divider(color: c.premiumStroke, height: 1),
              Expanded(
                  child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16), child: child)),
              if (actions.isNotEmpty) ...[
                Divider(color: c.premiumStroke, height: 1),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                      children: actions
                          .map((a) {
                            Widget btn = a.enabled
                                ? OutlinedButton.icon(
                                    onPressed: a.onTap,
                                    icon: Icon(a.icon, size: 14),
                                    label: Text(a.label),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: a.color,
                                      side: BorderSide(
                                          color:
                                              a.color.withValues(alpha: 0.4)),
                                    ),
                                  )
                                : OutlinedButton.icon(
                                    onPressed: null,
                                    icon: Icon(a.icon, size: 14),
                                    label: Text(a.label),
                                    style: OutlinedButton.styleFrom(
                                        foregroundColor: c.textSecondary),
                                  );
                            return Expanded(child: btn);
                          })
                          .expand((w) => [w, const SizedBox(width: 8)])
                          .toList()
                        ..removeLast()),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Empty Hint Widget ────────────────────────────────────────────────────────

class _EmptyHint extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  const _EmptyHint(
      {required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _AiAccountantScreenState.darkBg.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _AiAccountantScreenState.premiumStroke),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: _AiAccountantScreenState.textSecondary, size: 14),
          const SizedBox(width: 6),
          Text(title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w900)),
        ]),
        const SizedBox(height: 5),
        Text(body,
            style: const TextStyle(
                color: _AiAccountantScreenState.textSecondary,
                fontSize: 10.5,
                height: 1.4)),
      ]),
    );
  }
}

// ─── Draft Detail / Edit Sheet ────────────────────────────────────────────────

class _DraftDetailSheet extends StatefulWidget {
  final _AccountingDraft draft;
  final ValueChanged<_AccountingDraft> onUpdate;
  final VoidCallback onMarkReady;
  final VoidCallback onMarkNeedsReview;
  final _SheetColors colors;

  const _DraftDetailSheet({
    required this.draft,
    required this.onUpdate,
    required this.onMarkReady,
    required this.onMarkNeedsReview,
    required this.colors,
  });

  @override
  State<_DraftDetailSheet> createState() => _DraftDetailSheetState();
}

class _DraftDetailSheetState extends State<_DraftDetailSheet> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _summaryCtrl;
  late final TextEditingController _customerCtrl;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _currencyCtrl;
  late final TextEditingController _dateCtrl;
  late final TextEditingController _categoryCtrl;
  late final TextEditingController _detailsCtrl;

  @override
  void initState() {
    super.initState();
    final d = widget.draft;
    _titleCtrl = TextEditingController(text: d.title);
    _summaryCtrl = TextEditingController(text: d.summary);
    _customerCtrl = TextEditingController(text: d.customerOrSupplier ?? '');
    _amountCtrl = TextEditingController(
        text: d.amount != null ? d.amount!.toStringAsFixed(2) : '');
    _currencyCtrl = TextEditingController(text: d.currency ?? '');
    _dateCtrl = TextEditingController(text: d.dateOrDueDate ?? '');
    _categoryCtrl = TextEditingController(text: d.category ?? '');
    _detailsCtrl = TextEditingController(text: d.details ?? '');
  }

  @override
  void dispose() {
    for (final c in [
      _titleCtrl,
      _summaryCtrl,
      _customerCtrl,
      _amountCtrl,
      _currencyCtrl,
      _dateCtrl,
      _categoryCtrl,
      _detailsCtrl
    ]) c.dispose();
    super.dispose();
  }

  _AccountingDraft _built() => widget.draft.copyWith(
        title: _titleCtrl.text.trim().isEmpty ? null : _titleCtrl.text.trim(),
        summary:
            _summaryCtrl.text.trim().isEmpty ? null : _summaryCtrl.text.trim(),
        customerOrSupplier: _customerCtrl.text.trim().isEmpty
            ? null
            : _customerCtrl.text.trim(),
        amount: double.tryParse(_amountCtrl.text.replaceAll(',', '.')),
        currency: _currencyCtrl.text.trim().isEmpty
            ? null
            : _currencyCtrl.text.trim(),
        dateOrDueDate:
            _dateCtrl.text.trim().isEmpty ? null : _dateCtrl.text.trim(),
        category: _categoryCtrl.text.trim().isEmpty
            ? null
            : _categoryCtrl.text.trim(),
        details:
            _detailsCtrl.text.trim().isEmpty ? null : _detailsCtrl.text.trim(),
      );

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    final d = widget.draft;
    final statusColor = switch (d.status) {
      _DraftStatus.ready => c.tealSuccess,
      _DraftStatus.needsReview => c.goldAccent,
      _DraftStatus.draft => c.textSecondary,
    };
    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: 0.92,
        child: Container(
          margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          decoration: BoxDecoration(
              color: c.premiumPanel,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.premiumStroke)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
              child: Row(children: [
                Icon(d.typeIcon, color: c.goldAccent, size: 17),
                const SizedBox(width: 8),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('${d.typeLabel} · ${d.sourceLabel}',
                          style: TextStyle(
                              color: c.goldAccent,
                              fontSize: 10,
                              fontWeight: FontWeight.w800)),
                      Text(d.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w900)),
                    ])),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(5)),
                  child: Text(d.statusLabel,
                      style: TextStyle(
                          color: statusColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w900)),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: c.textSecondary, size: 18),
                  onPressed: () {
                    widget.onUpdate(_built());
                    Navigator.pop(context);
                  },
                ),
              ]),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 2, 16, 6),
              child: Text(
                  'Session draft only — not posted to accounting records.',
                  style: TextStyle(color: AppTheme.aiTextMuted, fontSize: 9)),
            ),
            Divider(color: c.premiumStroke, height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _field('Title', _titleCtrl, c),
                      _field('Summary', _summaryCtrl, c, maxLines: 3),
                      _field('Customer / Supplier', _customerCtrl, c,
                          hint: 'e.g. Al-Noor Trading'),
                      Row(children: [
                        Expanded(
                            child: _field('Amount', _amountCtrl, c,
                                hint: '2500.00',
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true))),
                        const SizedBox(width: 10),
                        Expanded(
                            child: _field('Currency', _currencyCtrl, c,
                                hint: 'SAR')),
                      ]),
                      _field('Date / Due Date', _dateCtrl, c,
                          hint: 'e.g. 2026-07-15'),
                      _field('Category', _categoryCtrl, c,
                          hint: 'e.g. Receivables'),
                      _field('Notes / Details', _detailsCtrl, c, maxLines: 4),
                      if (d.missingInfo.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text('Missing Information',
                            style: TextStyle(
                                color: c.goldAccent,
                                fontSize: 11,
                                fontWeight: FontWeight.w900)),
                        const SizedBox(height: 6),
                        ...d.missingInfo.map((m) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.info_outline,
                                        size: 12, color: c.goldAccent),
                                    const SizedBox(width: 6),
                                    Expanded(
                                        child: Text(m,
                                            style: TextStyle(
                                                color: c.textSecondary,
                                                fontSize: 10.5,
                                                height: 1.35))),
                                  ]),
                            )),
                      ],
                      if (d.recommendedNextAction != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: c.tealSuccess.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: c.tealSuccess.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.lightbulb_outline,
                                    size: 13, color: c.tealSuccess),
                                const SizedBox(width: 7),
                                Expanded(
                                    child: Text(d.recommendedNextAction!,
                                        style: TextStyle(
                                            color: c.tealSuccess,
                                            fontSize: 10.5,
                                            height: 1.35))),
                              ]),
                        ),
                      ],
                    ]),
              ),
            ),
            Divider(color: c.premiumStroke, height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      if (d.status != _DraftStatus.needsReview)
                        widget.onMarkNeedsReview();
                      else
                        widget.onMarkReady();
                      widget.onUpdate(_built());
                      Navigator.pop(context);
                    },
                    style: OutlinedButton.styleFrom(
                        foregroundColor: c.goldAccent,
                        side: BorderSide(
                            color: c.goldAccent.withValues(alpha: 0.4))),
                    child: Text(d.status == _DraftStatus.ready
                        ? 'Needs Review'
                        : 'Mark Ready'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      widget.onUpdate(_built());
                      Navigator.pop(context);
                    },
                    style: FilledButton.styleFrom(
                        backgroundColor: c.tealSuccess.withValues(alpha: 0.18),
                        foregroundColor: c.tealSuccess),
                    child: const Text('Save Changes'),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, _SheetColors c,
      {String? hint, int maxLines = 1, TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: TextStyle(
                color: c.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AppTheme.aiTextMuted, fontSize: 12),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            filled: true,
            fillColor: c.darkBg.withValues(alpha: 0.6),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: c.premiumStroke)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: c.premiumStroke)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    BorderSide(color: c.goldAccent.withValues(alpha: 0.5))),
          ),
        ),
      ]),
    );
  }
}

// ─── Saved Session Model (lightweight, uses ai_cfo_sessions via DBHelper) ─────

class _SavedAiCfoSession {
  final String id;
  final String title;
  final String reportText;
  final String draftsJson;
  final DateTime createdAt;

  const _SavedAiCfoSession({
    required this.id,
    required this.title,
    required this.reportText,
    required this.draftsJson,
    required this.createdAt,
  });

  String get shortDate {
    final d = createdAt;
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'businessId': '',
        'userId': '',
        'title': title,
        'reportText': reportText,
        'draftsJson': draftsJson,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': createdAt.toIso8601String(),
      };

  factory _SavedAiCfoSession.fromMap(Map<String, dynamic> map) {
    return _SavedAiCfoSession(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? 'Untitled',
      reportText: map['reportText']?.toString() ?? '',
      draftsJson: map['draftsJson']?.toString() ?? '[]',
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Future<void> save() async {
    try {
      final db = await DBHelper.database();
      await db.insert('ai_cfo_sessions', toMap());
    } catch (e) {
      debugPrint('[_SavedAiCfoSession] save error: $e');
      rethrow;
    }
  }

  Future<void> delete() async {
    try {
      final db = await DBHelper.database();
      await db.delete('ai_cfo_sessions', where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      debugPrint('[_SavedAiCfoSession] delete error: $e');
    }
  }

  static Future<List<_SavedAiCfoSession>> loadAll() async {
    try {
      final db = await DBHelper.database();
      final rows = await db.query(
        'ai_cfo_sessions',
        orderBy: 'createdAt DESC',
      );
      return rows.map(_SavedAiCfoSession.fromMap).toList();
    } catch (e) {
      debugPrint('[_SavedAiCfoSession] loadAll error: $e');
      return const [];
    }
  }
}

// ─── Document Intake Sheet ────────────────────────────────────────────────────

typedef _IntakeCallback = void Function(
    _AccountingDraft draft, String chatMessage);

class _DocumentIntakeSheet extends StatefulWidget {
  final _SheetColors colors;
  final _IntakeCallback onDraftCreated;
  const _DocumentIntakeSheet(
      {required this.colors, required this.onDraftCreated});
  @override
  State<_DocumentIntakeSheet> createState() => _DocumentIntakeSheetState();
}

class _DocumentIntakeSheetState extends State<_DocumentIntakeSheet> {
  final _typeOptions = const [
    'Invoice',
    'Receipt',
    'Quotation',
    'Payment Note',
    'Expense Note',
    'Receivable Note',
    'Payable Note',
    'General Note'
  ];
  String _selectedType = 'Invoice';
  final _titleCtrl = TextEditingController();
  final _textCtrl = TextEditingController();

  @override
  void dispose() {
    _titleCtrl.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  double? _extractAmount(String text) {
    final m = RegExp(r'(\d{2,}(?:[.,]\d+)?)').firstMatch(text.toLowerCase());
    if (m == null) return null;
    return double.tryParse(m.group(1)!.replaceAll(',', '.'));
  }

  String? _extractCurrency(String text) {
    final t = text.toUpperCase();
    for (final c in ['SAR', 'USD', 'EUR', 'TRY', 'AED', 'GBP', 'EGP', 'KWD']) {
      if (t.contains(c)) return c;
    }
    return null;
  }

  String? _extractCustomer(String text) {
    final t = text.toLowerCase();
    final patterns = [
      'from:',
      'to:',
      'customer:',
      'supplier:',
      'bill to:',
      'sold to:',
      'client:'
    ];
    for (final p in patterns) {
      final idx = t.indexOf(p);
      if (idx >= 0) {
        final rest = text.substring(idx + p.length).trim();
        final end = rest.indexOf('\n');
        return (end > 0 ? rest.substring(0, end) : rest)
            .trim()
            .split(',')
            .first
            .trim();
      }
    }
    return null;
  }

  String? _extractDate(String text) {
    final m = RegExp(r'\d{4}[-/]\d{2}[-/]\d{2}|\d{2}[-/]\d{2}[-/]\d{4}')
        .firstMatch(text);
    return m?.group(0);
  }

  String? _extractRef(String text) {
    final t = text.toLowerCase();
    final patterns = [
      'invoice #',
      'inv #',
      'ref:',
      'reference:',
      'no.:',
      'no:'
    ];
    for (final p in patterns) {
      final idx = t.indexOf(p);
      if (idx >= 0) {
        final rest = text.substring(idx + p.length).trim();
        return rest.split(RegExp(r'[\s\n]')).first.trim();
      }
    }
    return null;
  }

  bool _containsAny(String text, List<String> keywords) =>
      keywords.any(text.toLowerCase().contains);

  void _analyze() {
    final pasted = _textCtrl.text.trim();
    if (pasted.isEmpty) return;
    final isArabic = _containsArabicText(pasted);
    final title = _titleCtrl.text.trim().isEmpty
        ? '$_selectedType Draft'
        : _titleCtrl.text.trim();
    final amount = _extractAmount(pasted);
    final currency = _extractCurrency(pasted);
    final customer = _extractCustomer(pasted);
    final date = _extractDate(pasted);
    final ref = _extractRef(pasted);
    final hasVat = _containsAny(pasted, ['vat', 'tax', '15%', 'ضريبة']);
    final hasPaid = _containsAny(pasted, ['paid', 'مدفوع']);
    final missing = <String>[
      if (customer == null)
        (isArabic ? 'العميل / المورد' : 'Customer / Supplier'),
      if (amount == null) (isArabic ? 'المبلغ' : 'Amount'),
      if (currency == null) (isArabic ? 'العملة' : 'Currency'),
      if (date == null)
        (isArabic ? 'التاريخ / تاريخ الاستحقاق' : 'Date / Due Date'),
      if (!hasVat) (isArabic ? 'حالة الضريبة' : 'VAT / Tax status'),
      if (!hasPaid) (isArabic ? 'حالة الدفع' : 'Payment status'),
    ];
    final draftType = switch (_selectedType) {
      'Invoice' ||
      'Receipt' ||
      'Quotation' ||
      'Payment Note' ||
      'Receivable Note' =>
        _DraftType.invoice,
      'Expense Note' || 'Payable Note' => _DraftType.account,
      _ => _DraftType.note,
    };
    final confidence = (amount != null && customer != null)
        ? _DraftConfidence.medium
        : _DraftConfidence.low;
    final status =
        missing.length > 3 ? _DraftStatus.needsReview : _DraftStatus.draft;

    final draft = _AccountingDraft(
      id: 'doc_${DateTime.now().millisecondsSinceEpoch}',
      type: draftType,
      source: _DraftSource.documentIntake,
      title: title,
      summary: isArabic
          ? 'ملاحظة $_selectedType. ${customer != null ? 'العميل/المورد: $customer. ' : ''}${amount != null ? 'المبلغ: ${amount.toStringAsFixed(2)} ${currency ?? ''}. ' : ''}${ref != null ? 'المرجع: $ref. ' : ''}'
          : 'Document intake: $_selectedType. ${customer != null ? 'From/To: $customer. ' : ''}${amount != null ? 'Amount: ${amount.toStringAsFixed(2)} ${currency ?? ''}. ' : ''}${ref != null ? 'Ref: $ref.' : ''}',
      details: pasted,
      status: status,
      confidence: confidence,
      sourceSummary:
          isArabic ? 'إدخال مستند — نص ملصق' : 'Document Intake — pasted text',
      amount: amount,
      currency: currency,
      customerOrSupplier: customer,
      dateOrDueDate: date,
      missingInfo: missing,
      recommendedNextAction: isArabic
          ? 'أكمل البيانات الناقصة في صفحة التفاصيل، ثم علّم المسودة "جاهز" للتقرير النهائي.'
          : 'Complete missing fields in the draft detail view, then mark Ready for the final report.',
    );

    final foundMsg = <String>[
      if (amount != null)
        (isArabic
            ? 'المبلغ ${amount.toStringAsFixed(2)} ${currency ?? ''}'
            : 'amount ${amount.toStringAsFixed(2)} ${currency ?? ''}'),
      if (customer != null)
        (isArabic ? 'العميل "$customer"' : 'party "$customer"'),
      if (date != null) (isArabic ? 'التاريخ $date' : 'date $date'),
      if (ref != null) (isArabic ? 'المرجع $ref' : 'reference $ref'),
    ];
    final chatMsg = isArabic
        ? 'فهمت. نظمت ملاحظة $_selectedType في مسودة للمراجعة. ${foundMsg.isEmpty ? 'البيانات مبدئية، ومحتاج أكتر لأعطيك حكمة مالية موثوقة.' : 'استخرجت: ${foundMsg.join('، ')}.'}${missing.isEmpty ? '' : ' الناقص: ${missing.take(3).join('، ')}.'} أكّد المسودة وأكمل البيانات الناقصة قبل ما تعلّمه جاهز.'
        : 'I organized this $_selectedType note into a review draft. ${foundMsg.isEmpty ? 'I could not extract specific fields automatically.' : 'I found: ${foundMsg.join(', ')}.'}${missing.isEmpty ? '' : ' Missing: ${missing.take(3).join(', ')}.'} Review the draft, complete missing fields, and mark it Ready.';

    widget.onDraftCreated(draft, chatMsg);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: 0.88,
        child: Container(
          margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          decoration: BoxDecoration(
              color: c.premiumPanel,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.premiumStroke)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
              child: Row(children: [
                Icon(Icons.paste_outlined, color: c.goldAccent, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('Document Intake',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w900)),
                      Text(
                          'Paste invoice / receipt / quotation text. HASOOB extracts what is clear.',
                          style: TextStyle(
                              color: _AiAccountantScreenState.textSecondary,
                              fontSize: 10)),
                    ])),
                IconButton(
                    icon: Icon(Icons.close, color: c.textSecondary, size: 18),
                    onPressed: () => Navigator.pop(context)),
              ]),
            ),
            Divider(color: c.premiumStroke, height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Document Type',
                          style: TextStyle(
                              color: c.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _typeOptions.map((t) {
                            final sel = t == _selectedType;
                            return GestureDetector(
                              onTap: () => setState(() => _selectedType = t),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: sel
                                      ? c.goldAccent.withValues(alpha: 0.18)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                      color: sel
                                          ? c.goldAccent.withValues(alpha: 0.5)
                                          : c.premiumStroke),
                                ),
                                child: Text(t,
                                    style: TextStyle(
                                        color: sel
                                            ? c.goldAccent
                                            : c.textSecondary,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800)),
                              ),
                            );
                          }).toList()),
                      const SizedBox(height: 14),
                      Text('Title / Reference (optional)',
                          style: TextStyle(
                              color: c.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      _buildTextField(c, _titleCtrl,
                          hint: 'e.g. Invoice INV-2026-001'),
                      const SizedBox(height: 12),
                      Text('Paste Document / Note Text',
                          style: TextStyle(
                              color: c.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      _buildTextField(c, _textCtrl,
                          hint:
                              'Paste invoice text, receipt details, quotation content, or any accounting note here...',
                          maxLines: 9),
                      const SizedBox(height: 6),
                      Text(
                          'Session draft only — not posted to accounting records.',
                          style: TextStyle(
                              color: AppTheme.aiTextMuted, fontSize: 9)),
                    ]),
              ),
            ),
            Divider(color: c.premiumStroke, height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      _titleCtrl.clear();
                      _textCtrl.clear();
                    },
                    style: OutlinedButton.styleFrom(
                        foregroundColor: c.textSecondary,
                        side: BorderSide(color: c.premiumStroke)),
                    child: const Text('Clear'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: _textCtrl.text.trim().isEmpty ? null : _analyze,
                    icon: const Icon(Icons.auto_awesome_outlined, size: 15),
                    label: const Text('Analyze & Create Draft'),
                    style: FilledButton.styleFrom(
                        backgroundColor: c.goldAccent.withValues(alpha: 0.22),
                        foregroundColor: c.goldAccent),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildTextField(_SheetColors c, TextEditingController ctrl,
      {String? hint, int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white, fontSize: 12),
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppTheme.aiTextMuted, fontSize: 11),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        filled: true,
        fillColor: c.darkBg.withValues(alpha: 0.6),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: c.premiumStroke)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: c.premiumStroke)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: c.goldAccent.withValues(alpha: 0.5))),
      ),
    );
  }
}

// ─── Quick Transaction Sheet ──────────────────────────────────────────────────

class _QuickTransactionSheet extends StatefulWidget {
  final _SheetColors colors;
  final _IntakeCallback onDraftCreated;
  const _QuickTransactionSheet(
      {required this.colors, required this.onDraftCreated});
  @override
  State<_QuickTransactionSheet> createState() => _QuickTransactionSheetState();
}

class _QuickTransactionSheetState extends State<_QuickTransactionSheet> {
  final _txTypes = const [
    'Sale',
    'Expense',
    'Payment Received',
    'Payment Made',
    'Transfer',
    'Adjustment',
    'General'
  ];
  String _txType = 'Sale';
  final _amountCtrl = TextEditingController();
  final _currencyCtrl = TextEditingController(text: 'SAR');
  final _partyCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  String _payStatus = 'Unpaid';

  @override
  void dispose() {
    for (final c in [
      _amountCtrl,
      _currencyCtrl,
      _partyCtrl,
      _dateCtrl,
      _noteCtrl
    ]) c.dispose();
    super.dispose();
  }

  void _create() {
    final amt = double.tryParse(_amountCtrl.text.replaceAll(',', '.'));
    final party = _partyCtrl.text.trim();
    final date = _dateCtrl.text.trim();
    final note = _noteCtrl.text.trim();
    final currency =
        _currencyCtrl.text.trim().isEmpty ? 'SAR' : _currencyCtrl.text.trim();
    final isArabic = _containsArabicText('$party$note');

    final draftType = switch (_txType) {
      'Sale' || 'Payment Received' => _DraftType.invoice,
      'Expense' || 'Payment Made' => _DraftType.account,
      'Transfer' => _DraftType.account,
      _ => _DraftType.note,
    };
    final missing = <String>[
      if (amt == null) (isArabic ? 'المبلغ' : 'Amount'),
      if (party.isEmpty)
        (isArabic
            ? 'العميل / المورد / الحساب'
            : 'Customer / Supplier / Account'),
      if (date.isEmpty) (isArabic ? 'التاريخ' : 'Date'),
    ];
    final confidence = (amt != null && party.isNotEmpty)
        ? _DraftConfidence.medium
        : _DraftConfidence.low;

    final draft = _AccountingDraft(
      id: 'tx_${DateTime.now().millisecondsSinceEpoch}',
      type: draftType,
      source: _DraftSource.quickTransaction,
      title: '$_txType${party.isNotEmpty ? ' — $party' : ''}',
      summary:
          '$_txType${amt != null ? ': ${amt.toStringAsFixed(2)} $currency' : ''}.${party.isNotEmpty ? ' Party: $party.' : ''}${date.isNotEmpty ? ' Date: $date.' : ''} Status: $_payStatus.',
      details: note.isNotEmpty ? note : null,
      status: missing.isEmpty ? _DraftStatus.draft : _DraftStatus.needsReview,
      confidence: confidence,
      sourceSummary: 'Quick Transaction Intake',
      amount: amt,
      currency: currency,
      customerOrSupplier: party.isEmpty ? null : party,
      dateOrDueDate: date.isEmpty ? null : date,
      missingInfo: missing,
      recommendedNextAction: isArabic
          ? (_txType == 'Sale'
              ? 'أكّد الحساب والفئة والحالة. هذا ليس بيعًا مسجلاً — راجع قبل أي تسجيل رسمي.'
              : 'أكّد التصنيف والحساب والحالة. لم يُرفع للقيد بعد.')
          : (_txType == 'Sale'
              ? 'Confirm account/category and payment status. This is not a posted sale — review before any official recording.'
              : 'Confirm classification, account, and payment status. Not posted to ledger.'),
    );

    // ignore: unused_local_variable, no_leading_underscores_for_local_identifiers
    final _txTypeArabic = switch (_txType) {
      'Sale' => 'بيع',
      'Expense' => 'مصروف',
      'Payment Received' => 'دفعة مستلمة',
      'Payment Made' => 'دفعة مدفوعة',
      'Transfer' => 'تحويل',
      'Adjustment' => 'تعديل',
      _ => 'عام',
    };
    final chatMsg = isArabic
        ? 'سجلت مسودة $_txType${party.isNotEmpty ? ' لـ $party' : ''}. ${amt != null ? 'المبلغ: ${amt.toStringAsFixed(2)} $currency. ' : ''}هذا لم يُرفع للقيد بعد. أكّد التصنيف والحساب والحالة قبل أي تسجيل رسمي.'
        : 'I created a $_txType draft. ${amt != null ? 'Amount: ${amt.toStringAsFixed(2)} $currency. ' : ''}${party.isNotEmpty ? 'Party: $party. ' : ''}This is not posted to ledger. Confirm the account/category and payment status before any official recording.';

    widget.onDraftCreated(draft, chatMsg);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: 0.88,
        child: Container(
          margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          decoration: BoxDecoration(
              color: c.premiumPanel,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.premiumStroke)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
              child: Row(children: [
                Icon(Icons.receipt_outlined, color: c.goldAccent, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('Quick Transaction Note',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w900)),
                      Text(
                          'Record a transaction note. Not posted to ledger — creates a review draft only.',
                          style: TextStyle(
                              color: _AiAccountantScreenState.textSecondary,
                              fontSize: 10)),
                    ])),
                IconButton(
                    icon: Icon(Icons.close, color: c.textSecondary, size: 18),
                    onPressed: () => Navigator.pop(context)),
              ]),
            ),
            Divider(color: c.premiumStroke, height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _label('Transaction Type', c),
                      const SizedBox(height: 6),
                      Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _txTypes.map((t) {
                            final sel = t == _txType;
                            return GestureDetector(
                              onTap: () => setState(() => _txType = t),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: sel
                                      ? c.goldAccent.withValues(alpha: 0.18)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                      color: sel
                                          ? c.goldAccent.withValues(alpha: 0.5)
                                          : c.premiumStroke),
                                ),
                                child: Text(t,
                                    style: TextStyle(
                                        color: sel
                                            ? c.goldAccent
                                            : c.textSecondary,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800)),
                              ),
                            );
                          }).toList()),
                      const SizedBox(height: 14),
                      Row(children: [
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              _label('Amount', c),
                              const SizedBox(height: 4),
                              _tf(c, _amountCtrl,
                                  hint: '2500.00',
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true)),
                            ])),
                        const SizedBox(width: 10),
                        SizedBox(
                            width: 80,
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _label('Currency', c),
                                  const SizedBox(height: 4),
                                  _tf(c, _currencyCtrl, hint: 'SAR'),
                                ])),
                      ]),
                      const SizedBox(height: 12),
                      _label('Customer / Supplier / Account', c),
                      const SizedBox(height: 4),
                      _tf(c, _partyCtrl, hint: 'e.g. Ahmed Trading'),
                      const SizedBox(height: 12),
                      _label('Date', c),
                      const SizedBox(height: 4),
                      _tf(c, _dateCtrl, hint: '2026-07-01'),
                      const SizedBox(height: 12),
                      _label('Payment Status', c),
                      const SizedBox(height: 6),
                      Wrap(
                          spacing: 6,
                          children:
                              ['Paid', 'Unpaid', 'Partial', 'N/A'].map((s) {
                            final sel = s == _payStatus;
                            return GestureDetector(
                              onTap: () => setState(() => _payStatus = s),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 9, vertical: 4),
                                decoration: BoxDecoration(
                                  color: sel
                                      ? c.tealSuccess.withValues(alpha: 0.14)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(
                                      color: sel
                                          ? c.tealSuccess.withValues(alpha: 0.4)
                                          : c.premiumStroke),
                                ),
                                child: Text(s,
                                    style: TextStyle(
                                        color: sel
                                            ? c.tealSuccess
                                            : c.textSecondary,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800)),
                              ),
                            );
                          }).toList()),
                      const SizedBox(height: 12),
                      _label('Note / Description', c),
                      const SizedBox(height: 4),
                      _tf(c, _noteCtrl,
                          hint: 'Additional details...', maxLines: 3),
                      const SizedBox(height: 6),
                      Text(
                          'Not posted to ledger — creates a review draft only.',
                          style: TextStyle(
                              color: AppTheme.aiTextMuted, fontSize: 9)),
                    ]),
              ),
            ),
            Divider(color: c.premiumStroke, height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: FilledButton.icon(
                onPressed: _create,
                icon: const Icon(Icons.add_circle_outline, size: 15),
                label: const Text('Create Draft'),
                style: FilledButton.styleFrom(
                    backgroundColor: c.goldAccent.withValues(alpha: 0.22),
                    foregroundColor: c.goldAccent),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _label(String text, _SheetColors c) => Text(text,
      style: TextStyle(
          color: c.textSecondary, fontSize: 10, fontWeight: FontWeight.w800));

  Widget _tf(_SheetColors c, TextEditingController ctrl,
      {String? hint, int maxLines = 1, TextInputType? keyboardType}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white, fontSize: 12),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppTheme.aiTextMuted, fontSize: 11),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        filled: true,
        fillColor: c.darkBg.withValues(alpha: 0.6),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: c.premiumStroke)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: c.premiumStroke)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: c.goldAccent.withValues(alpha: 0.5))),
      ),
    );
  }
}

// ─── Receivables Follow-up Sheet ─────────────────────────────────────────────

class _ReceivablesSheet extends StatefulWidget {
  final _SheetColors colors;
  final _IntakeCallback onDraftCreated;
  const _ReceivablesSheet({required this.colors, required this.onDraftCreated});
  @override
  State<_ReceivablesSheet> createState() => _ReceivablesSheetState();
}

class _ReceivablesSheetState extends State<_ReceivablesSheet> {
  final _customerCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _currencyCtrl = TextEditingController(text: 'SAR');
  final _dueDateCtrl = TextEditingController();
  final _overdueDaysCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  @override
  void dispose() {
    for (final c in [
      _customerCtrl,
      _amountCtrl,
      _currencyCtrl,
      _dueDateCtrl,
      _overdueDaysCtrl,
      _refCtrl,
      _noteCtrl
    ]) c.dispose();
    super.dispose();
  }

  void _create() {
    final customer = _customerCtrl.text.trim();
    final amt = double.tryParse(_amountCtrl.text.replaceAll(',', '.'));
    final currency =
        _currencyCtrl.text.trim().isEmpty ? 'SAR' : _currencyCtrl.text.trim();
    final dueDate = _dueDateCtrl.text.trim();
    final overdue = _overdueDaysCtrl.text.trim();
    final ref = _refCtrl.text.trim();
    final note = _noteCtrl.text.trim();
    final isArabic = _containsArabicText('$customer$note');

    final missing = <String>[
      if (customer.isEmpty) (isArabic ? 'اسم العميل' : 'Customer name'),
      if (amt == null) (isArabic ? 'المبلغ' : 'Amount'),
      if (dueDate.isEmpty) (isArabic ? 'تاريخ الاستحقاق' : 'Due date'),
      if (ref.isEmpty)
        (isArabic ? 'رقم الفاتورة / المرجع' : 'Invoice / Reference number'),
    ];

    final urgency = overdue.isNotEmpty
        ? (int.tryParse(overdue) ?? 0) > 30
            ? (isArabic ? 'عاجل جدًا' : 'High urgency')
            : (isArabic ? 'أولوية متوسطة' : 'Medium urgency')
        : (isArabic ? 'تحقق من حالة التأخير' : 'Check overdue status');

    final draft = _AccountingDraft(
      id: 'rec_${DateTime.now().millisecondsSinceEpoch}',
      type: _DraftType.task,
      source: _DraftSource.receivablesFollowUp,
      title: 'Receivable Follow-up${customer.isNotEmpty ? ' — $customer' : ''}',
      summary:
          '${customer.isNotEmpty ? 'Customer: $customer. ' : ''}${amt != null ? 'Amount: ${amt.toStringAsFixed(2)} $currency. ' : ''}${dueDate.isNotEmpty ? 'Due: $dueDate. ' : ''}${overdue.isNotEmpty ? '$overdue days overdue. ' : ''}$urgency.',
      details: note.isNotEmpty ? note : null,
      status: missing.isEmpty ? _DraftStatus.draft : _DraftStatus.needsReview,
      confidence: (customer.isNotEmpty && amt != null)
          ? _DraftConfidence.medium
          : _DraftConfidence.low,
      sourceSummary: 'Receivables Follow-up Intake',
      amount: amt,
      currency: currency,
      customerOrSupplier: customer.isEmpty ? null : customer,
      dateOrDueDate: dueDate.isEmpty ? null : dueDate,
      category: 'Receivables',
      missingInfo: missing,
      recommendedNextAction: ref.isNotEmpty
          ? (isArabic
              ? 'أكّد الفاتورة $ref واتّصل بـ $customer وحدد تاريخ متابعة.'
              : 'Confirm invoice $ref is correct. Contact $customer and set a follow-up date.')
          : (isArabic
              ? 'أكّد مرجع الفاتورة واتّصل بـ $customer. علّم جاهزًا بعد تأكيد المبلغ وتاريخ الاستحقاق.'
              : 'Confirm invoice reference and contact $customer. Mark Ready after confirming amount and due date.'),
    );

    final chatMsg = isArabic
        ? 'أنشأت مسودة متابعة ذمم مدين${customer.isNotEmpty ? ' للعميل "$customer"' : ''}. ${amt != null ? 'المبلغ: ${amt.toStringAsFixed(2)} $currency. ' : ''}${overdue.isNotEmpty ? '$overdue أيام متأخرة. ' : ''}أكّد رقم الفاتورة وتاريخ الاستحقاق، ثم علّم المسودة جاهز للتقرير.'
        : 'I created a receivables follow-up task${customer.isNotEmpty ? ' for $customer' : ''}. ${amt != null ? 'Amount: ${amt.toStringAsFixed(2)} $currency. ' : ''}${overdue.isNotEmpty ? '$overdue days overdue. ' : ''}Confirm the invoice reference and due date, then mark it Ready for your session report.';

    widget.onDraftCreated(draft, chatMsg);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: 0.88,
        child: Container(
          margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          decoration: BoxDecoration(
              color: c.premiumPanel,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.premiumStroke)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
              child: Row(children: [
                Icon(Icons.people_alt_outlined, color: c.goldAccent, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('Receivables Follow-up',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w900)),
                      Text(
                          'Log a customer receivable follow-up task. Does not update customer balance.',
                          style: TextStyle(
                              color: _AiAccountantScreenState.textSecondary,
                              fontSize: 10)),
                    ])),
                IconButton(
                    icon: Icon(Icons.close, color: c.textSecondary, size: 18),
                    onPressed: () => Navigator.pop(context)),
              ]),
            ),
            Divider(color: c.premiumStroke, height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _lbl('Customer Name', c),
                      const SizedBox(height: 4),
                      _tf(c, _customerCtrl, hint: 'e.g. Ahmed Al-Salam'),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              _lbl('Amount', c),
                              const SizedBox(height: 4),
                              _tf(c, _amountCtrl,
                                  hint: '1200.00',
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true)),
                            ])),
                        const SizedBox(width: 10),
                        SizedBox(
                            width: 80,
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _lbl('Currency', c),
                                  const SizedBox(height: 4),
                                  _tf(c, _currencyCtrl, hint: 'SAR'),
                                ])),
                      ]),
                      const SizedBox(height: 12),
                      _lbl('Due Date', c),
                      const SizedBox(height: 4),
                      _tf(c, _dueDateCtrl, hint: '2026-07-01'),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              _lbl('Days Overdue (if known)', c),
                              const SizedBox(height: 4),
                              _tf(c, _overdueDaysCtrl,
                                  hint: 'e.g. 14',
                                  keyboardType: TextInputType.number),
                            ])),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              _lbl('Invoice / Reference', c),
                              const SizedBox(height: 4),
                              _tf(c, _refCtrl, hint: 'INV-001'),
                            ])),
                      ]),
                      const SizedBox(height: 12),
                      _lbl('Note', c),
                      const SizedBox(height: 4),
                      _tf(c, _noteCtrl,
                          hint: 'Additional context...', maxLines: 3),
                      const SizedBox(height: 6),
                      Text(
                          'Does not update customer balance — creates a follow-up task draft only.',
                          style: TextStyle(
                              color: AppTheme.aiTextMuted, fontSize: 9)),
                    ]),
              ),
            ),
            Divider(color: c.premiumStroke, height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: FilledButton.icon(
                onPressed: _create,
                icon: const Icon(Icons.task_alt_outlined, size: 15),
                label: const Text('Create Follow-up Task'),
                style: FilledButton.styleFrom(
                    backgroundColor: c.goldAccent.withValues(alpha: 0.22),
                    foregroundColor: c.goldAccent),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _lbl(String t, _SheetColors c) => Text(t,
      style: TextStyle(
          color: c.textSecondary, fontSize: 10, fontWeight: FontWeight.w800));
  Widget _tf(_SheetColors c, TextEditingController ctrl,
      {String? hint, int maxLines = 1, TextInputType? keyboardType}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white, fontSize: 12),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppTheme.aiTextMuted, fontSize: 11),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        filled: true,
        fillColor: c.darkBg.withValues(alpha: 0.6),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: c.premiumStroke)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: c.premiumStroke)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: c.goldAccent.withValues(alpha: 0.5))),
      ),
    );
  }
}

// ─── Payables / Expense Sheet ─────────────────────────────────────────────────

class _PayablesSheet extends StatefulWidget {
  final _SheetColors colors;
  final _IntakeCallback onDraftCreated;
  const _PayablesSheet({required this.colors, required this.onDraftCreated});
  @override
  State<_PayablesSheet> createState() => _PayablesSheetState();
}

class _PayablesSheetState extends State<_PayablesSheet> {
  final _supplierCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _currencyCtrl = TextEditingController(text: 'SAR');
  final _dueDateCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  String _payStatus = 'Unpaid';

  final _categories = const [
    'Rent',
    'Utilities',
    'Salaries',
    'Freight',
    'Raw Materials',
    'Services',
    'Maintenance',
    'Other'
  ];
  String? _selectedCategory;

  @override
  void dispose() {
    for (final c in [
      _supplierCtrl,
      _amountCtrl,
      _currencyCtrl,
      _dueDateCtrl,
      _categoryCtrl,
      _refCtrl,
      _noteCtrl
    ]) c.dispose();
    super.dispose();
  }

  void _create() {
    final supplier = _supplierCtrl.text.trim();
    final amt = double.tryParse(_amountCtrl.text.replaceAll(',', '.'));
    final currency =
        _currencyCtrl.text.trim().isEmpty ? 'SAR' : _currencyCtrl.text.trim();
    final dueDate = _dueDateCtrl.text.trim();
    final category = _selectedCategory ?? _categoryCtrl.text.trim();
    final note = _noteCtrl.text.trim();
    final isArabic = _containsArabicText('$supplier$category$note');

    final missing = <String>[
      if (supplier.isEmpty) 'Supplier / Payee',
      if (amt == null) 'Amount',
      if (category.isEmpty) 'Expense Category',
      if (dueDate.isEmpty) 'Due Date',
    ];

    final draft = _AccountingDraft(
      id: 'pay_${DateTime.now().millisecondsSinceEpoch}',
      type: _DraftType.account,
      source: _DraftSource.payablesExpense,
      title:
          'Payable/Expense${supplier.isNotEmpty ? ' — $supplier' : ''}${category.isNotEmpty ? ' ($category)' : ''}',
      summary:
          '${supplier.isNotEmpty ? 'Supplier: $supplier. ' : ''}${amt != null ? 'Amount: ${amt.toStringAsFixed(2)} $currency. ' : ''}${category.isNotEmpty ? 'Category: $category. ' : ''}${dueDate.isNotEmpty ? 'Due: $dueDate. ' : ''}Payment status: $_payStatus.',
      details: note.isNotEmpty ? note : null,
      status: missing.isEmpty ? _DraftStatus.draft : _DraftStatus.needsReview,
      confidence: (supplier.isNotEmpty && amt != null)
          ? _DraftConfidence.medium
          : _DraftConfidence.low,
      sourceSummary: 'Payables / Expense Intake',
      amount: amt,
      currency: currency,
      customerOrSupplier: supplier.isEmpty ? null : supplier,
      dateOrDueDate: dueDate.isEmpty ? null : dueDate,
      category: category.isEmpty ? null : category,
      missingInfo: missing,
      recommendedNextAction: isArabic
          ? 'أكّد المورد والفئة والحالة. لم يُرفع للقيد بعد — راجع قبل أي تسجيل محاسبي.'
          : 'Confirm supplier, category, and payment status. Not posted to ledger — review before any official accounting entry.',
    );

    final chatMsg = isArabic
        ? 'أنشأت مسودة ${category.isNotEmpty ? "مصروف/$category" : "دفعة مستحقة"}${supplier.isNotEmpty ? ' للمورد "$supplier"' : ''}. ${amt != null ? 'المبلغ: ${amt.toStringAsFixed(2)} $currency. ' : ''}أكّد المورد والفئة والحالة، وهذا لم يُرفع للقيد بعد.'
        : 'I created a payable/expense draft${supplier.isNotEmpty ? ' for $supplier' : ''}. ${amt != null ? 'Amount: ${amt.toStringAsFixed(2)} $currency. ' : ''}${category.isNotEmpty ? 'Category: $category. ' : ''}Confirm supplier, category, and payment status. This is not posted to the ledger.';

    widget.onDraftCreated(draft, chatMsg);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: 0.88,
        child: Container(
          margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          decoration: BoxDecoration(
              color: c.premiumPanel,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.premiumStroke)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
              child: Row(children: [
                Icon(Icons.payment_outlined, color: c.goldAccent, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('Payable / Expense Note',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w900)),
                      Text(
                          'Log a supplier payable or expense note. Does not affect supplier balance or ledger.',
                          style: TextStyle(
                              color: _AiAccountantScreenState.textSecondary,
                              fontSize: 10)),
                    ])),
                IconButton(
                    icon: Icon(Icons.close, color: c.textSecondary, size: 18),
                    onPressed: () => Navigator.pop(context)),
              ]),
            ),
            Divider(color: c.premiumStroke, height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _lbl('Supplier / Payee', c),
                      const SizedBox(height: 4),
                      _tf(c, _supplierCtrl, hint: 'e.g. Al-Noor Supplies'),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              _lbl('Amount', c),
                              const SizedBox(height: 4),
                              _tf(c, _amountCtrl,
                                  hint: '3500.00',
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true)),
                            ])),
                        const SizedBox(width: 10),
                        SizedBox(
                            width: 80,
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _lbl('Currency', c),
                                  const SizedBox(height: 4),
                                  _tf(c, _currencyCtrl, hint: 'SAR'),
                                ])),
                      ]),
                      const SizedBox(height: 12),
                      _lbl('Due Date', c),
                      const SizedBox(height: 4),
                      _tf(c, _dueDateCtrl, hint: '2026-07-15'),
                      const SizedBox(height: 12),
                      _lbl('Expense Category', c),
                      const SizedBox(height: 6),
                      Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _categories.map((cat) {
                            final sel = cat == _selectedCategory;
                            return GestureDetector(
                              onTap: () => setState(
                                  () => _selectedCategory = sel ? null : cat),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 9, vertical: 4),
                                decoration: BoxDecoration(
                                  color: sel
                                      ? c.goldAccent.withValues(alpha: 0.16)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(
                                      color: sel
                                          ? c.goldAccent.withValues(alpha: 0.4)
                                          : c.premiumStroke),
                                ),
                                child: Text(cat,
                                    style: TextStyle(
                                        color: sel
                                            ? c.goldAccent
                                            : c.textSecondary,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800)),
                              ),
                            );
                          }).toList()),
                      const SizedBox(height: 8),
                      _lbl('Or type custom category', c),
                      const SizedBox(height: 4),
                      _tf(c, _categoryCtrl, hint: 'e.g. Import Duties'),
                      const SizedBox(height: 12),
                      _lbl('Payment Status', c),
                      const SizedBox(height: 6),
                      Wrap(
                          spacing: 6,
                          children: ['Unpaid', 'Paid', 'Partial', 'Scheduled']
                              .map((s) {
                            final sel = s == _payStatus;
                            return GestureDetector(
                              onTap: () => setState(() => _payStatus = s),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 9, vertical: 4),
                                decoration: BoxDecoration(
                                  color: sel
                                      ? c.tealSuccess.withValues(alpha: 0.14)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(
                                      color: sel
                                          ? c.tealSuccess.withValues(alpha: 0.4)
                                          : c.premiumStroke),
                                ),
                                child: Text(s,
                                    style: TextStyle(
                                        color: sel
                                            ? c.tealSuccess
                                            : c.textSecondary,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800)),
                              ),
                            );
                          }).toList()),
                      const SizedBox(height: 12),
                      _lbl('Note / Reference', c),
                      const SizedBox(height: 4),
                      _tf(c, _noteCtrl,
                          hint: 'Invoice ref, note...', maxLines: 3),
                      const SizedBox(height: 6),
                      Text(
                          'Does not affect supplier balance or ledger — creates a review draft only.',
                          style: TextStyle(
                              color: AppTheme.aiTextMuted, fontSize: 9)),
                    ]),
              ),
            ),
            Divider(color: c.premiumStroke, height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: FilledButton.icon(
                onPressed: _create,
                icon: const Icon(Icons.add_circle_outline, size: 15),
                label: const Text('Create Payable/Expense Draft'),
                style: FilledButton.styleFrom(
                    backgroundColor: c.goldAccent.withValues(alpha: 0.22),
                    foregroundColor: c.goldAccent),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _lbl(String t, _SheetColors c) => Text(t,
      style: TextStyle(
          color: c.textSecondary, fontSize: 10, fontWeight: FontWeight.w800));
  Widget _tf(_SheetColors c, TextEditingController ctrl,
      {String? hint, int maxLines = 1, TextInputType? keyboardType}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white, fontSize: 12),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppTheme.aiTextMuted, fontSize: 11),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        filled: true,
        fillColor: c.darkBg.withValues(alpha: 0.6),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: c.premiumStroke)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: c.premiumStroke)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: c.goldAccent.withValues(alpha: 0.5))),
      ),
    );
  }
}
