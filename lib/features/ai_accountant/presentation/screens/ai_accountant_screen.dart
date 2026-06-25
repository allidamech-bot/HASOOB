import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/app_theme.dart';
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

class AiAccountantScreen extends StatefulWidget {
  final bool workspaceMode;

  const AiAccountantScreen({
    super.key,
    this.workspaceMode = false,
  });

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
          'Welcome. I can help with pricing, exports, inventory, customer balances, profitability, and preparing accounting operations for review. Add invoices, customers, products, expenses, and shipment costs to unlock evidence-backed CFO analysis. What would you like to work on?',
      timestamp: DateTime(2026, 6, 11),
      suggestedReplies: [
        'Price a shipment',
        'Compare three scenarios',
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
  void dispose() {
    _textController.dispose();
    _chatScrollController.dispose();
    super.dispose();
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

  Future<void> _processAiCommand({String? customText}) async {
    final text = customText ?? _textController.text.trim();
    if (text.isEmpty) return;
    if (customText == null) _textController.clear();

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
        text:
            'I could not prepare a reliable CFO answer from the available data. Please try again, or ask for a narrower analysis such as cash flow, customer risk, inventory, or shipment pricing.',
        suggestedReplies: const [
          'Check business health',
          'Review customer risk',
          'Price a shipment',
        ],
      );
      return;
    }

    if (_isExecutionIntent(text)) {
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
          text:
              'I need a little more detail before I can prepare a safe proposal. Is this a purchase, sale, or pricing simulation? Please include product, quantity, amount, and customer or supplier when relevant.',
          suggestedReplies: const [
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
        text:
            'I prepared a reviewable proposal. Check the details before approving. Execution will still go through the guarded accounting engine.',
        proposal: proposal,
        suggestedReplies: _proposalSuggestedReplies(proposal),
      );
    } catch (e) {
      debugPrint('[AiAccountantScreen] Proposal parsing stopped safely: $e');
      if (!mounted) return;
      _appendMessage(
        role: AiChatRole.assistant,
        type: AiChatMessageType.error,
        text:
            'I could not prepare a safe proposal from that request. Please add the transaction type, product, quantity, amount, and customer or supplier when relevant.',
        suggestedReplies: const [
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
    final suggestions = response.type == AiCfoResponseType.blocked
        ? const [
            'Prepare a proposal',
            'Review business health',
            'Continue discussion',
          ]
        : response.evidence.isEmpty
            ? const [
                'What data is missing?',
                'Review inventory risk',
                'Review cash flow',
              ]
            : const [
                'Explain evidence',
                'What data is missing?',
                'Review next risk',
              ];
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
            suggestedReplies: const [
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
    final lines = <String>[
      response.title,
      response.message,
    ];
    if (response.evidence.isNotEmpty) {
      lines.add('What you already have:');
      lines.addAll(response.evidence
          .take(4)
          .map((item) => '- ${item.label}: ${item.value}'));
      lines.add('Evidence sources:');
      lines.addAll(response.evidence.take(6).map((item) => '- ${item.source}'));
      lines.add('Risk to check first:');
      lines.add(_firstRiskToCheck(response));
    }
    if (response.risks.isNotEmpty) {
      lines.add('Missing data / limits:');
      lines.addAll(response.risks.take(4).map((item) => '- $item'));
    }
    if (response.evidence.isEmpty) {
      lines.add('What to add next:');
      lines.add('- Products with stock, cost, and selling price.');
      lines.add('- Customers and invoices with paid or unpaid balances.');
      lines.add('- Recorded sales, payments, expenses, or ledger entries.');
      lines.add('Useful next questions:');
      lines.add('- What cash-flow data is missing?');
      lines.add('- Which stock needs attention?');
      lines.add('- What can you say from the data I have?');
    }
    return lines.join('\n');
  }

  String _firstRiskToCheck(AiCfoConversationResponse response) {
    final hasLowConfidence = response.evidence
        .any((item) => item.confidence == AiCfoEvidenceConfidence.low);
    if (hasLowConfidence) {
      return '- Verify low-confidence evidence before making a financial decision.';
    }
    if (response.risks.isNotEmpty) {
      return '- ${response.risks.first}';
    }
    return '- Ask for a focused cash flow, inventory, profit, or receivables review before acting.';
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
            _buildExecutiveCommandHeader(isDesktop: false),
            const SizedBox(height: 10),
            _buildCommandSignalStrip(isDesktop: false),
            const SizedBox(height: 10),
            Expanded(child: _buildConversationPanel(isDesktop: false)),
          ],
        ),
      );
    }

    return Padding(
      padding: padding,
      child: Column(
        children: [
          _buildExecutiveCommandHeader(isDesktop: true),
          const SizedBox(height: 12),
          _buildCommandSignalStrip(isDesktop: true),
          const SizedBox(height: 14),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 72,
                  child: _buildConversationPanel(isDesktop: true),
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 24,
                  child: _buildRightContextPanel(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

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
        label: 'Cash',
        value: _firstInsightSignal(['cash', 'payment', 'liquidity']) ??
            'No cash signal yet',
        color: tealSuccess,
        hasEvidence: _hasInsightSignal(['cash', 'payment', 'liquidity']),
      ),
      _CommandSignalData(
        icon: Icons.trending_up_rounded,
        label: 'Revenue',
        value: _firstInsightSignal(['revenue', 'sales', 'profit']) ??
            'Awaiting revenue analysis',
        color: goldAccent,
        hasEvidence: _hasInsightSignal(['revenue', 'sales', 'profit']),
      ),
      _CommandSignalData(
        icon: Icons.inventory_2_outlined,
        label: 'Inventory',
        value: _orchestrator.businessMemory.recentProducts.isEmpty
            ? 'No inventory focus yet'
            : _orchestrator.businessMemory.recentProducts.first,
        color: AppTheme.aiBlue,
        hasEvidence: _orchestrator.businessMemory.recentProducts.isNotEmpty,
      ),
      _CommandSignalData(
        icon: Icons.people_alt_outlined,
        label: 'Receivables',
        value: _orchestrator.memory.latestCustomer ??
            _firstInsightSignal(['receivable', 'customer', 'balance']) ??
            'No receivables signal yet',
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
      child: Row(
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
            child: Text(
              'AI Accountant',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          _statusPill('AI CFO Beta', goldAccent),
          const SizedBox(width: 8),
          if (!isDesktop)
            IconButton(
              tooltip: 'Context',
              icon:
                  const Icon(Icons.view_sidebar_outlined, color: textSecondary),
              onPressed: _showMobileContextSheet,
            )
          else
            _statusPill(
              _activeProposal != null ? 'Proposal ready' : 'Advisory mode',
              _activeProposal != null ? goldAccent : tealSuccess,
            ),
        ],
      ),
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
              child: _buildRightContextPanel(),
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
      ('What should I do today?', Icons.today_outlined),
      ('How is my business doing?', Icons.query_stats_outlined),
      ('Which products need attention?', Icons.inventory_2_outlined),
      ('What are my risks?', Icons.warning_amber_outlined),
      ('Before I decide, what should I check?', Icons.fact_check_outlined),
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

  Widget _buildRightContextPanel() {
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
              title: 'Business Health',
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
              title: 'Detected Risks',
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
              title: 'Insights',
              icon: Icons.lightbulb_outline,
              child: _contextRows(
                insights.take(4).map((item) => item.title).toList(),
                empty: 'No insight generated yet',
              ),
            ),
            Command360ContextModule(
              title: 'Recommended Next Actions',
              icon: Icons.task_alt_outlined,
              child: _contextRows(
                recommendations.take(4).map((item) => item.title).toList(),
                empty: 'Ask for analysis to generate actions',
              ),
            ),
            Command360ContextModule(
              title: 'Memory',
              icon: Icons.memory_outlined,
              child: _buildContextSummary(compact: true),
            ),
            Command360ContextModule(
              title: 'CFO Operating Timeline',
              icon: Icons.timeline_outlined,
              child: _buildOperatingTimeline(compact: true),
            ),
            Command360ContextModule(
              title: 'CFO Follow-up',
              icon: Icons.pending_actions_outlined,
              child: _buildFollowUpLoop(compact: true),
            ),
            Command360ContextModule(
              title: 'Active Proposal / Workflow',
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
              'Welcome to AI Accountant',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Start with profitability, cash flow, stock risk, customer balances, or a transaction proposal. Add invoices, customers, products, expenses, and shipment costs to unlock evidence-backed CFO analysis.',
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
                  label: 'Analyze Profitability',
                  icon: Icons.analytics_outlined,
                  onPressed: () => _processAiCommand(
                    customText: 'Analyze Profitability',
                  ),
                ),
                Command360QuickActionChip(
                  label: 'Price a shipment',
                  icon: Icons.price_check_outlined,
                  onPressed: () => _processAiCommand(
                    customText: 'Price a shipment',
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
                hintText: 'Ask for advice or describe a clear transaction...',
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
      return const [
        'Explain this pricing',
        'Convert to quote',
        'Compare margins',
      ];
    }
    return const [
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
