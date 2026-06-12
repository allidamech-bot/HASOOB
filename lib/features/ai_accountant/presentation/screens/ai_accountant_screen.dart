import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/app_theme.dart';
import '../../../../core/business/business_context.dart';
import '../../../../data/repositories/product_repository.dart';
import '../../../../screens/invoice_details_screen.dart';
import '../../../../screens/product_details_screen.dart';
import '../../../../screens/settings_screen.dart';
import '../../data/models/ai_proposal_model.dart';
import '../../data/repositories/ai_accountant_repository_factory.dart';
import '../../domain/services/ai_conversation_orchestrator.dart';
import '../../domain/services/ai_evidence_bundle.dart';
import '../../domain/services/ai_insight_generator.dart';
import '../../domain/services/ai_response_metadata.dart';
import '../../domain/services/ai_risk_detector.dart';
import '../../domain/services/ai_data_collection_state.dart';
import '../../domain/services/ai_workflow_session.dart';
import '../../domain/services/proposal_execution_engine.dart';

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

class AiAccountantScreen extends StatefulWidget {
  const AiAccountantScreen({super.key});

  @override
  State<AiAccountantScreen> createState() => _AiAccountantScreenState();
}

class _AiAccountantScreenState extends State<AiAccountantScreen> {
  final _textController = TextEditingController();
  final _chatScrollController = ScrollController();
  final _repository = AiAccountantRepositoryFactory.make();
  final _orchestrator = AiConversationOrchestrator();

  bool _isAnalyzing = false;
  bool _isCommitting = false;
  AiProposalModel? _activeProposal;
  AiProposalModel? _confirmationProposal;

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
          'Welcome. I can help with pricing, exports, inventory, customer balances, profitability, and preparing accounting operations for review. What would you like to work on?',
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

  Future<void> _processAiCommand({String? customText}) async {
    final text = customText ?? _textController.text.trim();
    if (text.isEmpty) return;
    if (customText == null) _textController.clear();

    _appendMessage(
      role: AiChatRole.user,
      type: AiChatMessageType.normal,
      text: text,
    );

    final advisorResponse = await _orchestrator.generateResponse(
      userText: text,
      activeProposal: _activeProposal ?? _confirmationProposal,
    );

    if (_isExecutionIntent(text)) {
      final proposal = _activeProposal ?? _confirmationProposal;
      if (proposal != null && _isExecutableProposal(proposal)) {
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
      if (!mounted) return;
      _appendMessage(
        role: AiChatRole.assistant,
        type: AiChatMessageType.error,
        text: 'I could not analyze that request safely: $e',
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

  Future<void> _handleExecutionIntent(String text) async {
    final wantsQuotation = _containsAny(_normalized(text), [
      'convert',
      'quotation',
      'quote',
      'حول',
      'حولها',
    ]);
    final proposal = _activeProposal ?? _confirmationProposal;

    if (proposal == null || !_isExecutableProposal(proposal)) {
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
    if (proposal == null) return;
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
    if (proposal == null) return;
    await _executeProposal(proposal, clearActive: true);
  }

  Future<void> _confirmProductAndExecute(String productId) async {
    final proposal = _confirmationProposal ?? _activeProposal;
    if (proposal == null || productId.isEmpty) return;
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
    setState(() => _isCommitting = true);
    try {
      final result = await _repository.executeProposalDetailed(proposal);
      if (!mounted) return;
      setState(() {
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
      if (!mounted) return;
      final result = ProposalExecutionResult(
        success: false,
        error: 'Could not execute safely: $e',
      );
      setState(() {
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
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: darkBg,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 1000;
            return SafeArea(
              child: Column(
                children: [
                  _buildPremiumHeader(isDesktop: isDesktop),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        isDesktop ? 20 : 12,
                        12,
                        isDesktop ? 20 : 12,
                        isDesktop ? 20 : 12,
                      ),
                      child: isDesktop
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(flex: 7, child: _buildAiPanel()),
                                const SizedBox(width: 16),
                                SizedBox(
                                  width: 390,
                                  child: _buildContextPanel(),
                                ),
                              ],
                            )
                          : _buildMobileWorkspace(constraints.maxHeight),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMobileWorkspace(double maxHeight) {
    return Column(
      children: [
        Expanded(child: _buildAiPanel(isMobile: true)),
        const SizedBox(height: 10),
        _buildMobileContextPanel(maxHeight),
      ],
    );
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
                  ],
                ),
              ],
            ),
          ),
          if (isDesktop) ...[
            _headerMetric('Confidence', '--'),
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
          _contextRow(
            Icons.business_outlined,
            'Business',
            BusinessContext.businessId.isEmpty
                ? 'Current business'
                : BusinessContext.businessId,
          ),
          _contextRow(
            Icons.person_outline,
            'Customer',
            memory.latestCustomer ?? '-',
          ),
          _contextRow(
            Icons.inventory_2_outlined,
            'Product',
            memory.currentProduct ?? '-',
          ),
          _contextRow(
            Icons.fact_check_outlined,
            'Active proposal',
            _activeProposal?.actionType ??
                _confirmationProposal?.actionType ??
                'None',
          ),
        ],
      ),
    );
  }

  Widget _contextRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: textSecondary, size: 16),
          const SizedBox(width: 9),
          SizedBox(
            width: 94,
            child: Text(
              label,
              style: const TextStyle(color: textSecondary, fontSize: 11),
            ),
          ),
          Expanded(
            child: Text(
              value,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
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
                                    : '-',
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
                                    : '-',
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
                'Ask, compare, prepare proposals, then approve through the guarded accounting flow.',
                style:
                    TextStyle(color: textSecondary, fontSize: 12, height: 1.35),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        if (_activeProposal != null)
          _statusPill('Proposal ready', goldAccent)
        else
          _statusPill('Advisory only', tealSuccess),
      ],
    );
  }

  Widget _buildQuickInsights({required bool isMobile}) {
    final insights = [
      const _InsightData(
          'Revenue', '\$--', Icons.trending_up_rounded, tealSuccess),
      const _InsightData(
          'Expenses', '\$--', Icons.trending_down_rounded, AppTheme.aiRed),
      const _InsightData(
          'Profit', '\$--', Icons.account_balance_wallet_outlined, goldAccent),
      const _InsightData('Pending Invoices', '--', Icons.receipt_long_outlined,
          AppTheme.warning),
      const _InsightData(
          'Low Stock', '--', Icons.inventory_2_outlined, tealSuccess),
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
          return _QuickActionChip(
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
      padding: const EdgeInsets.all(14),
      itemCount: _messages.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
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
              'Start with profitability, cash flow, stock risk, customer balances, or a transaction proposal.',
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
                _QuickActionChip(
                  label: 'Analyze Profitability',
                  icon: Icons.analytics_outlined,
                  onPressed: () => _processAiCommand(
                    customText: 'Analyze Profitability',
                  ),
                ),
                _QuickActionChip(
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
        isUser ? goldAccent.withValues(alpha: 0.14) : premiumPanel;
    final borderColor =
        isUser ? goldAccent.withValues(alpha: 0.34) : premiumStroke;
    final maxWidth = MediaQuery.sizeOf(context).width >= 1000 ? 680.0 : 560.0;

    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(14),
                  topRight: const Radius.circular(14),
                  bottomLeft: Radius.circular(isUser ? 14 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 14),
                ),
                border: Border.all(color: borderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        isUser
                            ? Icons.person_outline
                            : _messageIcon(message.type),
                        color:
                            isUser ? goldAccent : _messageColor(message.type),
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                isUser ? 'You' : 'AI Accountant',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isUser
                                      ? goldAccent
                                      : _messageColor(message.type),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _timeLabel(message.timestamp),
                              style: const TextStyle(
                                color: AppTheme.aiTextMuted,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message.text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      height: 1.5,
                    ),
                  ),
                  if (message.workflowSession != null &&
                      !message.workflowSession!.isComplete) ...[
                    const SizedBox(height: 12),
                    _buildWorkflowCard(message.workflowSession!),
                  ],
                  if (message.memory?.hasVisibleContext == true) ...[
                    const SizedBox(height: 12),
                    _buildMemoryCard(message.memory!),
                  ],
                  if (message.decisionOptions.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildDecisionOptions(message.decisionOptions),
                  ],
                  if (message.proposal != null) ...[
                    const SizedBox(height: 12),
                    _buildProposalCard(message.proposal!),
                  ],
                  if (message.executionResult != null) ...[
                    const SizedBox(height: 12),
                    _buildExecutionResultCard(message.executionResult!),
                  ],
                  if (!isUser && message.metadata != null) ...[
                    const SizedBox(height: 12),
                    _buildResponseMetadata(message.metadata!),
                  ],
                  if (!isUser &&
                      (message.insights.isNotEmpty ||
                          message.risks.isNotEmpty ||
                          message.recommendations.isNotEmpty)) ...[
                    const SizedBox(height: 12),
                    _buildAiInsightsPanel(
                      insights: message.insights,
                      risks: message.risks,
                      recommendations: message.recommendations,
                    ),
                  ],
                ],
              ),
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

  Widget _buildWorkflowCard(AiWorkflowSession session) {
    final collected = session.collectedData.keys
        .map(AiWorkflowField.label)
        .toList(growable: false);
    final waiting = session.waitingField == null
        ? 'Review'
        : AiWorkflowField.label(session.waitingField!);
    final step = session.currentStep.clamp(1, session.totalSteps);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: goldAccent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: goldAccent.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.route_outlined, color: goldAccent, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${_workflowTitle(session.workflowType)} Workflow',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _statusPill('Step $step of ${session.totalSteps}', goldAccent),
            ],
          ),
          const SizedBox(height: 10),
          if (collected.isNotEmpty)
            _workflowLine(
              Icons.check_circle_outline_rounded,
              'Collected',
              collected.join(', '),
              tealSuccess,
            ),
          _workflowLine(
            Icons.hourglass_empty_rounded,
            'Waiting',
            waiting,
            goldAccent,
          ),
        ],
      ),
    );
  }

  Widget _workflowLine(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 7),
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(color: textSecondary, fontSize: 11),
            ),
          ),
          Expanded(
            child: Text(
              value,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemoryCard(AiConversationMemory memory) {
    final rows = [
      if (memory.currentProduct != null) ('Product', memory.currentProduct!),
      if (memory.currentDestination != null)
        ('Destination', memory.currentDestination!),
      if (memory.currentCost != null)
        ('Cost', memory.currentCost!.toStringAsFixed(2)),
      if (memory.currentMargin != null)
        ('Margin', '${memory.currentMargin!.toStringAsFixed(0)}%'),
      if (memory.latestCustomer != null) ('Customer', memory.latestCustomer!),
      if (memory.missingData.isNotEmpty)
        ('Missing', memory.missingData.join(', ')),
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: goldAccent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: goldAccent.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.memory_outlined, color: goldAccent, size: 16),
              SizedBox(width: 8),
              Text(
                'Conversation context',
                style: TextStyle(
                  color: goldAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...rows.map((row) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 92,
                    child: Text(
                      row.$1,
                      style:
                          const TextStyle(color: textSecondary, fontSize: 11),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      row.$2,
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                      overflow: TextOverflow.ellipsis,
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

  Widget _buildDecisionOptions(List<AiDecisionOption> options) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: options.map((option) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.aiCardElevated,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: tealSuccess.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.route_outlined,
                    color: tealSuccess,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      option.title,
                      style: const TextStyle(
                        color: tealSuccess,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _decisionLine('Recommendation', option.recommendation),
              _decisionLine('Advantage', option.advantage),
              _decisionLine('Risk', option.risk),
              _decisionLine('When', option.whenToUse),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _decisionLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(
                color: textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
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

  Widget _buildProposalCard(AiProposalModel proposal) {
    final isPricing = proposal.actionType == 'pricing_simulation';
    final pricing = proposal.pricingPayload ?? const <String, dynamic>{};
    final inventory = proposal.inventoryPayload ?? const <String, dynamic>{};
    final financial = proposal.financialPayload ?? const <String, dynamic>{};
    final impactArea = isPricing ? 'Pricing strategy' : 'Ledger and inventory';
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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: premiumPanelSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPricing
              ? tealSuccess.withValues(alpha: 0.42)
              : goldAccent.withValues(alpha: 0.42),
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
                  color: (isPricing ? tealSuccess : goldAccent)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isPricing
                      ? Icons.price_check_outlined
                      : Icons.fact_check_outlined,
                  color: isPricing ? tealSuccess : goldAccent,
                  size: 19,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isPricing ? 'Pricing proposal' : 'Accounting proposal',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Review required before execution',
                      style: TextStyle(color: textSecondary, fontSize: 11),
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
            style: const TextStyle(
                color: Colors.white, fontSize: 12.5, height: 1.5),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _proposalMetaChip(
                  Icons.domain_verification_outlined, impactArea, tealSuccess),
              _proposalMetaChip(
                  Icons.shield_outlined, 'Risk: $riskLevel', riskColor),
            ],
          ),
          const SizedBox(height: 14),
          if (isPricing) ...[
            _detailLine(
              Icons.location_on_outlined,
              'Destination',
              '${pricing['destination'] ?? '-'}',
            ),
            _detailLine(
              Icons.inventory_2_outlined,
              'Estimated units',
              '${pricing['estimatedTotalBoxes'] ?? '-'}',
            ),
            _detailLine(
              Icons.price_change_outlined,
              'Landed cost',
              '${pricing['landedCostPerUnit'] ?? '-'}',
            ),
            _detailLine(
              Icons.trending_up_rounded,
              'Suggested price',
              '${pricing['suggestedPricePerUnit'] ?? '-'}',
            ),
          ] else ...[
            _detailLine(
              Icons.inventory_2_outlined,
              'Item',
              '${inventory['name'] ?? inventory['productId'] ?? '-'}',
            ),
            _detailLine(
              Icons.format_list_numbered_rtl,
              'Quantity',
              '${inventory['quantity'] ?? '-'}',
            ),
            _detailLine(
              Icons.payments_outlined,
              'Amount',
              '${financial['totalAmount'] ?? '-'}',
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              if (isPricing)
                FilledButton.icon(
                  onPressed: _isCommitting ? null : _savePricingSimulation,
                  icon: _isCommitting
                      ? _miniProgress()
                      : const Icon(Icons.save_outlined, size: 16),
                  label: const Text('Save simulation'),
                )
              else
                FilledButton.icon(
                  onPressed: _isCommitting ? null : _commitProposalToLedger,
                  icon: _isCommitting
                      ? _miniProgress()
                      : const Icon(Icons.check_circle_outline, size: 16),
                  label: const Text('Approve after review'),
                ),
              if (isPricing)
                OutlinedButton.icon(
                  onPressed: _isCommitting ? null : _convertPricingToQuotation,
                  icon: const Icon(Icons.request_quote_outlined, size: 16),
                  label: const Text('Convert to quote'),
                ),
              OutlinedButton.icon(
                onPressed: _isCommitting
                    ? null
                    : () => setState(() {
                          if (identical(_activeProposal, proposal)) {
                            _activeProposal = null;
                          }
                          _ledgerRows.removeWhere(
                            (row) => row.code == 'PENDING-AI',
                          );
                        }),
                icon: const Icon(Icons.close_rounded, size: 16),
                label: const Text('Dismiss'),
              ),
            ],
          ),
        ],
      ),
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
      padding: const EdgeInsets.all(14),
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
            _detailLine(
              Icons.inventory_2_outlined,
              'Product',
              '${product['id'] ?? '-'} | ${product['name'] ?? '-'}',
            ),
          if (invoice.isNotEmpty)
            _detailLine(
              Icons.receipt_long_outlined,
              'Invoice',
              '${invoice['id'] ?? '-'} | ${invoice['number'] ?? '-'}',
            ),
          if (journal.isNotEmpty)
            _detailLine(
              Icons.account_balance_outlined,
              'Journal',
              '${journal['id'] ?? '-'} | ${journal['code'] ?? '-'}',
            ),
          if (pricing.isNotEmpty)
            _detailLine(
              Icons.price_check_outlined,
              'Pricing simulation',
              '${pricing['id'] ?? '-'} | ${pricing['suggestedPrice'] ?? pricing['suggestedPricePerUnit'] ?? '-'}',
            ),
          _detailLine(
            Icons.sync_rounded,
            'Sync',
            sync['status']?.toString() ?? (result.success ? 'queued' : '-'),
          ),
          _detailLine(
            Icons.fact_check_outlined,
            'Audit',
            audit['status']?.toString() ?? (result.success ? 'stored' : '-'),
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

  Widget _detailLine(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: textSecondary, size: 15),
          const SizedBox(width: 8),
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: const TextStyle(color: textSecondary, fontSize: 11),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
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

class _QuickActionChip extends StatelessWidget {
  const _QuickActionChip({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 15),
      label: Text(
        label,
        overflow: TextOverflow.ellipsis,
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        disabledForegroundColor: _AiAccountantScreenState.textSecondary,
        side: const BorderSide(color: _AiAccountantScreenState.premiumStroke),
        backgroundColor:
            _AiAccountantScreenState.premiumPanelSoft.withValues(alpha: 0.82),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
      ),
    );
  }
}
