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

enum _AdvisorIntent {
  generalHelp,
  greeting,
  exportAdvice,
  pricingAdvice,
  marginDiscussion,
  scenarioComparison,
  profitabilityDiscussion,
  inventoryDiscussion,
  customerDiscussion,
  cashflowDiscussion,
  transactionPreparation,
  executionFollowUp,
  unknown,
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

class AiAccountantScreen extends StatefulWidget {
  const AiAccountantScreen({super.key});

  @override
  State<AiAccountantScreen> createState() => _AiAccountantScreenState();
}

class _AiAccountantScreenState extends State<AiAccountantScreen> {
  final _textController = TextEditingController();
  final _chatScrollController = ScrollController();
  final _repository = AiAccountantRepositoryFactory.make();
  final _advisorContext = _AdvisorSessionContext();

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

    if (_isExecutionIntent(text)) {
      await _handleExecutionIntent(text);
      return;
    }

    final advisory = _buildAdvisoryResponse(text);
    if (advisory != null) {
      _appendMessage(
        role: AiChatRole.assistant,
        type: advisory.type,
        text: advisory.text,
        suggestedReplies: advisory.suggestedReplies,
      );
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _confirmationProposal = null;
    });

    try {
      final proposal = await _repository.parseNaturalLanguage(text);
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
        _advisorContext.latestProposal = proposal;
        _rememberProposalContext(proposal);
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
    List<String> suggestedReplies = const [],
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
          suggestedReplies: suggestedReplies,
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
        _advisorContext.latestTopic = _AdvisorIntent.executionFollowUp;
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
            return Column(
              children: [
                _buildTopFinancialRibbon(),
                Expanded(
                  child: isDesktop
                      ? Row(
                          children: [
                            Expanded(flex: 3, child: _buildAiPanel()),
                            Expanded(flex: 2, child: _buildLedgerPanel()),
                          ],
                        )
                      : Column(
                          children: [
                            Expanded(
                              flex: 3,
                              child: _buildAiPanel(isMobile: true),
                            ),
                            SizedBox(
                              height: constraints.maxHeight < 700 ? 220 : 280,
                              child: _buildLedgerPanel(isCompact: true),
                            ),
                          ],
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

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

  Widget _buildLedgerPanel({bool isCompact = false}) {
    return Container(
      padding: EdgeInsets.all(isCompact ? 12 : 16),
      decoration: BoxDecoration(
        color: darkBg,
        border: Border(
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
      color: AppTheme.aiNavy,
      padding: EdgeInsets.all(isMobile ? 14 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Advisor chat',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (_activeProposal != null)
                _statusPill('Proposal ready', goldAccent)
              else
                _statusPill('Conversation safe', tealSuccess),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Discuss decisions freely. Clear purchase, sale, and pricing commands become reviewable proposal cards.',
            style: TextStyle(color: textSecondary, fontSize: 12, height: 1.4),
          ),
          const Divider(color: borderTerminal, height: 22),
          Expanded(child: _buildChatTimeline()),
          if (_isAnalyzing) _buildTypingIndicator(),
          const SizedBox(height: 10),
          _buildQuickPromptsStrip(),
          const SizedBox(height: 10),
          _buildInputField(),
        ],
      ),
    );
  }

  Widget _buildChatTimeline() {
    return ListView.separated(
      controller: _chatScrollController,
      padding: const EdgeInsets.only(bottom: 8),
      itemCount: _messages.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _buildChatMessage(_messages[index]),
    );
  }

  Widget _buildChatMessage(AiChatMessage message) {
    final isUser = message.role == AiChatRole.user;
    final alignment = isUser ? Alignment.centerRight : Alignment.centerLeft;
    final bubbleColor =
        isUser ? goldAccent.withValues(alpha: 0.16) : darkSurface;
    final borderColor =
        isUser ? goldAccent.withValues(alpha: 0.34) : borderTerminal;
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
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: borderColor),
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
                        child: Text(
                          isUser ? 'You' : 'AI Accountant',
                          style: TextStyle(
                            color: isUser
                                ? goldAccent
                                : _messageColor(message.type),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message.text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                  if (message.proposal != null) ...[
                    const SizedBox(height: 12),
                    _buildProposalCard(message.proposal!),
                  ],
                  if (message.executionResult != null) ...[
                    const SizedBox(height: 12),
                    _buildExecutionResultCard(message.executionResult!),
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
    return const Padding(
      padding: EdgeInsets.only(top: 8),
      child: Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(color: goldAccent, strokeWidth: 2),
          ),
          SizedBox(width: 8),
          Text(
            'Preparing a safe response...',
            style: TextStyle(color: textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildProposalCard(AiProposalModel proposal) {
    final isPricing = proposal.actionType == 'pricing_simulation';
    final pricing = proposal.pricingPayload ?? const <String, dynamic>{};
    final inventory = proposal.inventoryPayload ?? const <String, dynamic>{};
    final financial = proposal.financialPayload ?? const <String, dynamic>{};

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.aiCardElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isPricing
              ? tealSuccess.withValues(alpha: 0.6)
              : goldAccent.withValues(alpha: 0.55),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                isPricing
                    ? Icons.price_check_outlined
                    : Icons.fact_check_outlined,
                color: isPricing ? tealSuccess : goldAccent,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isPricing ? 'Pricing proposal' : 'Accounting proposal',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _statusPill(
                '${(proposal.confidenceScore * 100).clamp(0, 100).toStringAsFixed(0)}%',
                goldAccent,
              ),
            ],
          ),
          const Divider(color: borderTerminal, height: 22),
          Text(
            proposal.explanation,
            style:
                const TextStyle(color: Colors.white, fontSize: 12, height: 1.5),
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

  _AdvisorResponse? _buildAdvisoryResponse(String text) {
    final normalized = _normalized(text);
    if (_isClearTransactionCommand(normalized) &&
        !_isPreparationRequest(normalized)) {
      return null;
    }

    final numericFollowUp = _buildNumericFollowUpResponse(text);
    if (numericFollowUp != null) return numericFollowUp;

    final intent = _classifyAdvisorIntent(normalized);
    _rememberContextFromText(text, intent);

    switch (intent) {
      case _AdvisorIntent.greeting:
        _advisorContext.latestTopic = intent;
        return const _AdvisorResponse(
          type: AiChatMessageType.normal,
          text:
              'Welcome. I can help you with pricing, exports, inventory, customer balances, profitability, and preparing accounting operations for review. What would you like to work on?',
          suggestedReplies: [
            'Price a shipment',
            'Review profitability',
            'Analyze inventory risk',
          ],
        );
      case _AdvisorIntent.generalHelp:
        _advisorContext.latestTopic = intent;
        return const _AdvisorResponse(
          type: AiChatMessageType.recommendation,
          text:
              'I can help in five practical areas: pricing shipments, reviewing profitability, preparing purchases or sales for approval, checking inventory risks, and discussing customer balances. Choose one and I will guide you step by step.',
          suggestedReplies: [
            'Price a shipment',
            'Compare three scenarios',
            'Prepare a purchase',
          ],
        );
      case _AdvisorIntent.exportAdvice:
        _advisorContext.latestTopic = intent;
        return _exportAdviceResponse();
      case _AdvisorIntent.pricingAdvice:
        _advisorContext.latestTopic = intent;
        return _pricingAdviceResponse();
      case _AdvisorIntent.marginDiscussion:
        _advisorContext.latestTopic = intent;
        return _marginDiscussionResponse();
      case _AdvisorIntent.scenarioComparison:
        _advisorContext.latestTopic = intent;
        return _scenarioComparisonResponse();
      case _AdvisorIntent.profitabilityDiscussion:
        _advisorContext.latestTopic = intent;
        return _profitabilityResponse();
      case _AdvisorIntent.inventoryDiscussion:
        _advisorContext.latestTopic = intent;
        return _inventoryResponse();
      case _AdvisorIntent.customerDiscussion:
        _advisorContext.latestTopic = intent;
        return _customerResponse();
      case _AdvisorIntent.cashflowDiscussion:
        _advisorContext.latestTopic = intent;
        return _cashflowResponse();
      case _AdvisorIntent.transactionPreparation:
        _advisorContext.latestTopic = intent;
        return _transactionPreparationResponse(normalized);
      case _AdvisorIntent.executionFollowUp:
        _advisorContext.latestTopic = intent;
        return _executionFollowUpResponse();
      case _AdvisorIntent.unknown:
        if (_looksLikeAdvisorDiscussion(normalized)) {
          _advisorContext.latestTopic = intent;
          return _unknownAdvisorResponse();
        }
        return _buildLegacyAdvisoryResponse(text);
    }
  }

  _AdvisorResponse? _buildLegacyAdvisoryResponse(String text) {
    final normalized = _normalized(text);
    if (_isClearTransactionCommand(normalized)) return null;

    if (_containsAny(normalized, [
      'export',
      'saudi',
      'market entry',
      'تصدير',
      'السعودية',
      'دخول السوق',
    ])) {
      return const _AdvisorResponse(
        type: AiChatMessageType.question,
        text:
            'Let us build the export decision step by step. I need carton cost, expected selling price or target margin, shipping cost, customs cost, payment terms, and whether your priority is fast market entry or higher margin. Until those are clear, I will keep this as advice only.',
        suggestedReplies: [
          'My goal is fast market entry',
          'My goal is higher margin',
          'Compare pricing scenarios',
        ],
      );
    }

    if (_containsAny(normalized, [
      '25%',
      '25 percent',
      'margin',
      'هامش',
      'ربح',
      'مناسب',
    ])) {
      return const _AdvisorResponse(
        type: AiChatMessageType.scenarioComparison,
        text:
            'A 25% margin can be suitable when demand is stable, returns are low, and competitors are not forcing discounts. For first entry, compare three scenarios: conservative at 15-18% to win accounts, balanced at 22-25% to protect profit, and aggressive at 30%+ only if the product has clear differentiation or limited supply.',
        suggestedReplies: [
          'Run conservative scenario',
          'Run balanced scenario',
          'Run aggressive scenario',
        ],
      );
    }

    if (_containsAny(normalized, [
      'recommend',
      'advice',
      'advise',
      'compare',
      'explain',
      'what do you think',
      'suitable',
      'better',
      'strategy',
      'discussion',
      'تنصح',
      'نصيحة',
      'توصي',
      'قارن',
      'اشرح',
      'أفضل',
      'استراتيجية',
      'مناقشة',
    ])) {
      return const _AdvisorResponse(
        type: AiChatMessageType.recommendation,
        text:
            'I can help reason through that without touching the database. To make the recommendation useful, tell me the product, cost base, expected volume, payment terms, and your goal: cash speed, margin, market entry, or risk reduction.',
        suggestedReplies: [
          'Focus on cash speed',
          'Focus on higher margin',
          'Help me compare options',
        ],
      );
    }

    return null;
  }

  _AdvisorIntent _classifyAdvisorIntent(String normalized) {
    if (_containsAny(normalized, [
      'hello',
      'hi',
      'hey',
      'good morning',
      'good evening',
      'مرحبا',
      'أهلا',
      'اهلا',
      'السلام عليكم',
    ])) {
      return _AdvisorIntent.greeting;
    }
    if (_containsAny(normalized, [
      'how can you help',
      'what can you do',
      'help me',
      'ساعدني',
      'ماذا تستطيع',
      'شو بتقدر',
    ])) {
      return _AdvisorIntent.generalHelp;
    }
    if (_containsAny(normalized, [
      'scenario',
      'scenarios',
      'compare three',
      'compare margins',
      'conservative',
      'balanced',
      'aggressive',
      'سيناريو',
      'سيناريوهات',
      'قارن',
      'محافظ',
      'متوازن',
      'هجومي',
    ])) {
      return _AdvisorIntent.scenarioComparison;
    }
    if (_containsAny(normalized, [
      'export',
      'saudi',
      'market entry',
      'shipping',
      'customs',
      'تصدير',
      'السعودية',
      'دخول السوق',
      'شحن',
      'جمارك',
    ])) {
      return _AdvisorIntent.exportAdvice;
    }
    if (_containsAny(normalized, [
      'margin',
      '25%',
      '25 percent',
      'markup',
      'هامش',
      'ربح',
      'مناسب',
    ])) {
      return _AdvisorIntent.marginDiscussion;
    }
    if (_containsAny(normalized, [
      'price',
      'pricing',
      'landed cost',
      'quote price',
      'سعر',
      'تسعير',
      'تكلفة واصلة',
    ])) {
      return _AdvisorIntent.pricingAdvice;
    }
    if (_containsAny(normalized, [
      'profit',
      'profitability',
      'gross profit',
      'net profit',
      'ربحية',
      'صافي الربح',
      'مجمل الربح',
    ])) {
      return _AdvisorIntent.profitabilityDiscussion;
    }
    if (_containsAny(normalized, [
      'inventory',
      'stock',
      'slow moving',
      'out of stock',
      'مخزون',
      'كمية',
      'بضاعة',
      'نفاد',
    ])) {
      return _AdvisorIntent.inventoryDiscussion;
    }
    if (_containsAny(normalized, [
      'customer',
      'balance',
      'payment history',
      'receivable',
      'عميل',
      'زبون',
      'رصيد',
      'تحصيل',
      'مديونية',
    ])) {
      return _AdvisorIntent.customerDiscussion;
    }
    if (_containsAny(normalized, [
      'cash flow',
      'cashflow',
      'cash',
      'liquidity',
      'due invoices',
      'تدفق نقدي',
      'سيولة',
      'كاش',
      'نقد',
      'فواتير مستحقة',
    ])) {
      return _AdvisorIntent.cashflowDiscussion;
    }
    if (_containsAny(normalized, [
      'prepare',
      'create proposal',
      'purchase proposal',
      'sale proposal',
      'pricing simulation',
      'جهز',
      'حضّر',
      'حضر',
      'مقترح',
      'عملية شراء',
      'عملية بيع',
    ])) {
      return _AdvisorIntent.transactionPreparation;
    }
    if (_containsAny(normalized, [
      'what happened',
      'what is missing',
      'explain the impact',
      'impact',
      'ماذا حدث',
      'ما الناقص',
      'اشرح الأثر',
    ])) {
      return _AdvisorIntent.executionFollowUp;
    }
    return _AdvisorIntent.unknown;
  }

  _AdvisorResponse? _buildNumericFollowUpResponse(String text) {
    final amount = _firstNumber(text);
    if (amount == null) return null;
    final topic = _advisorContext.latestTopic;
    if (topic != _AdvisorIntent.exportAdvice &&
        topic != _AdvisorIntent.pricingAdvice &&
        topic != _AdvisorIntent.marginDiscussion &&
        topic != _AdvisorIntent.scenarioComparison) {
      return null;
    }

    final normalized = _normalized(text);
    if (_containsAny(normalized, ['%', 'percent', 'هامش', 'ربح'])) {
      _advisorContext.currentMargin = amount;
      return _marginDiscussionResponse();
    }
    return _rememberedCostResponse(amount);
  }

  _AdvisorResponse _exportAdviceResponse() {
    final product = _advisorContext.currentProduct ?? 'the product';
    final destination =
        _advisorContext.currentDestination ?? 'the target market';
    return _AdvisorResponse(
      type: AiChatMessageType.question,
      text:
          'Good. Let us build the export decision for $product to $destination step by step. I need the carton cost, estimated shipping cost, customs or import fees, and your goal: fast market entry or higher margin.',
      suggestedReplies: const [
        'Carton cost is 45 dollars',
        'My goal is fast market entry',
        'Compare three scenarios',
      ],
    );
  }

  _AdvisorResponse _pricingAdviceResponse() {
    final product = _advisorContext.currentProduct ?? 'this product';
    return _AdvisorResponse(
      type: AiChatMessageType.question,
      text:
          'For pricing $product, I need four inputs: landed cost or purchase cost, target margin, competitor price range, and currency. Then I can suggest conservative, balanced, and aggressive options without recording anything.',
      suggestedReplies: const [
        'Cost is 45 dollars',
        'Target margin is 25%',
        'Compare three scenarios',
      ],
    );
  }

  _AdvisorResponse _marginDiscussionResponse() {
    final margin = _advisorContext.currentMargin?.toStringAsFixed(0) ?? '25';
    return _AdvisorResponse(
      type: AiChatMessageType.scenarioComparison,
      text:
          '$margin% can be suitable if demand is stable and competition is not aggressive. For a new market, I recommend comparing three scenarios: conservative, balanced, and aggressive. Conservative protects entry speed, balanced protects both sales and profit, and aggressive only works when the product has clear differentiation.',
      suggestedReplies: const [
        'Compare three scenarios',
        'Use fast market entry',
        'Use higher margin',
      ],
    );
  }

  _AdvisorResponse _scenarioComparisonResponse() {
    final product = _advisorContext.currentProduct ?? 'the product';
    final destination = _advisorContext.currentDestination;
    final destinationPart = destination == null ? '' : ' for $destination';
    _advisorContext.latestScenarioType = 'three_scenarios';
    return _AdvisorResponse(
      type: AiChatMessageType.scenarioComparison,
      text:
          'Here is a practical scenario comparison for $product$destinationPart:\n\nConservative: margin direction 15-18%. Advantage: easier market entry and faster customer testing. Risk: weak profit buffer if shipping or returns rise. Use it when you need first orders or distributor adoption.\n\nBalanced: margin direction 22-25%. Advantage: protects profit while keeping the offer realistic. Risk: may be average if competitors are discounting hard. Use it when demand is stable and you want repeatable sales.\n\nAggressive: margin direction 30%+. Advantage: stronger profit per carton. Risk: slower sales and higher rejection from price-sensitive buyers. Use it only when supply is limited, quality is differentiated, or the customer has urgency.',
      suggestedReplies: const [
        'Use balanced scenario',
        'Prepare pricing simulation',
        'Review profitability',
      ],
    );
  }

  _AdvisorResponse _profitabilityResponse() {
    return const _AdvisorResponse(
      type: AiChatMessageType.question,
      text:
          'To review profitability, separate gross profit from cash timing. I need selling price, purchase or landed cost, expected quantity, discounts, and any shipping or customs costs not already included.',
      suggestedReplies: [
        'Compare three scenarios',
        'Cost is 45 dollars',
        'Target margin is 25%',
      ],
    );
  }

  _AdvisorResponse _inventoryResponse() {
    return const _AdvisorResponse(
      type: AiChatMessageType.question,
      text:
          'For inventory risk, I need the product name, current stock quantity, average sales speed, and next replenishment date. The key question is whether the risk is stockout, slow movement, or cash tied up in stock.',
      suggestedReplies: [
        'Analyze inventory risk',
        'Review slow-moving stock',
        'Prepare a purchase',
      ],
    );
  }

  _AdvisorResponse _customerResponse() {
    return const _AdvisorResponse(
      type: AiChatMessageType.question,
      text:
          'For customer balance discussion, I need the customer name, current balance, oldest unpaid invoice, and recent payment behavior. Then we can decide whether to offer credit, request payment first, or continue normally.',
      suggestedReplies: [
        'Review customer balance',
        'Discuss payment terms',
        'Prepare a sale',
      ],
    );
  }

  _AdvisorResponse _cashflowResponse() {
    return const _AdvisorResponse(
      type: AiChatMessageType.question,
      text:
          'For cash flow, focus on timing. I need available cash, due customer invoices, upcoming supplier payments, and planned purchases. Then we can decide what can be paid now and what should wait.',
      suggestedReplies: [
        'Review due invoices',
        'Plan upcoming purchases',
        'Discuss cash risk',
      ],
    );
  }

  _AdvisorResponse _transactionPreparationResponse(String normalized) {
    if (_containsAny(normalized, ['sale', 'بيع', 'عملية بيع'])) {
      return const _AdvisorResponse(
        type: AiChatMessageType.question,
        text:
            'I can prepare a sale proposal for review. Please provide product, quantity, selling price, customer name, and whether payment is cash or credit. I will not execute it until you approve the proposal card.',
        suggestedReplies: [
          'Prepare a sale',
          'Discuss customer balance',
          'Analyze inventory risk',
        ],
      );
    }
    if (_containsAny(normalized, ['pricing', 'تسعير', 'price'])) {
      return _pricingAdviceResponse();
    }
    return const _AdvisorResponse(
      type: AiChatMessageType.question,
      text:
          'I can prepare a purchase proposal for review. Please provide product, quantity, unit cost or total amount, supplier if available, and whether it was paid cash or remains payable.',
      suggestedReplies: [
        'Prepare a purchase',
        'Price a shipment',
        'Compare three scenarios',
      ],
    );
  }

  _AdvisorResponse _executionFollowUpResponse() {
    final proposal = _advisorContext.latestProposal;
    if (proposal == null) {
      return const _AdvisorResponse(
        type: AiChatMessageType.confirmation,
        text:
            'There is no completed proposal in this conversation yet. We can prepare a purchase, sale, or pricing simulation first, then you can approve it after review.',
        suggestedReplies: [
          'Prepare a purchase',
          'Prepare a sale',
          'Run pricing simulation',
        ],
      );
    }
    return _AdvisorResponse(
      type: AiChatMessageType.recommendation,
      text:
          'The latest proposal is a ${proposal.actionType}. Review the proposal card details first: product, quantity, amount, and any required confirmation. If it looks correct, use approve or save and it will continue through the guarded execution flow.',
      suggestedReplies: const [
        'Approve',
        'Change details',
        'Explain accounting impact',
      ],
    );
  }

  _AdvisorResponse _rememberedCostResponse(double amount) {
    _advisorContext.currentCost = amount;
    final product = _advisorContext.currentProduct ?? 'the product';
    final destination = _advisorContext.currentDestination;
    final route = destination == null ? '' : ' for $destination';
    return _AdvisorResponse(
      type: AiChatMessageType.question,
      text:
          'Got it. I will treat ${amount.toStringAsFixed(2)} as the carton cost for $product$route. To continue pricing safely, I still need estimated shipping cost, customs or import fees, currency, and whether your goal is fast entry or higher margin.',
      suggestedReplies: const [
        'Shipping is 1200 dollars',
        'Customs are 300 dollars',
        'Compare three scenarios',
      ],
    );
  }

  _AdvisorResponse _unknownAdvisorResponse() {
    return const _AdvisorResponse(
      type: AiChatMessageType.question,
      text:
          'I can help, but I need to know the business area first. Are we discussing pricing, export, profitability, inventory, customer balances, cash flow, or preparing a purchase or sale for review?',
      suggestedReplies: [
        'Price a shipment',
        'Review profitability',
        'Analyze inventory risk',
      ],
    );
  }

  void _rememberContextFromText(String text, _AdvisorIntent intent) {
    final normalized = _normalized(text);
    final product = _extractProduct(normalized);
    if (product != null) _advisorContext.currentProduct = product;
    final destination = _extractDestination(normalized);
    if (destination != null) _advisorContext.currentDestination = destination;
    final margin = _extractMargin(normalized);
    if (margin != null) _advisorContext.currentMargin = margin;
    final customer = _extractCustomer(text);
    if (customer != null) _advisorContext.latestCustomer = customer;
    if (intent == _AdvisorIntent.scenarioComparison) {
      _advisorContext.latestScenarioType = 'three_scenarios';
    }
  }

  void _rememberProposalContext(AiProposalModel proposal) {
    final inventory = proposal.inventoryPayload;
    final customer = proposal.customerPayload;
    final pricing = proposal.pricingPayload;
    if (inventory != null) {
      final name = inventory['name']?.toString();
      if (name != null && name.trim().isNotEmpty) {
        _advisorContext.currentProduct = name.trim();
      }
    }
    if (customer != null) {
      final name = customer['name']?.toString();
      if (name != null && name.trim().isNotEmpty) {
        _advisorContext.latestCustomer = name.trim();
      }
    }
    if (pricing != null) {
      final destination = pricing['destination']?.toString();
      if (destination != null && destination.trim().isNotEmpty) {
        _advisorContext.currentDestination = destination.trim();
      }
      final margin = (pricing['targetMarginPercentage'] as num?)?.toDouble();
      if (margin != null) _advisorContext.currentMargin = margin;
    }
  }

  String? _extractProduct(String normalized) {
    final products = <String, String>{
      'chocolate': 'chocolate',
      'شوكولاتة': 'chocolate',
      'شوكولاته': 'chocolate',
      'carton': 'cartons',
      'كرتون': 'cartons',
    };
    for (final entry in products.entries) {
      if (normalized.contains(entry.key)) return entry.value;
    }
    return null;
  }

  String? _extractDestination(String normalized) {
    if (normalized.contains('saudi') || normalized.contains('السعودية')) {
      return 'Saudi Arabia';
    }
    if (normalized.contains('afghanistan') ||
        normalized.contains('أفغانستان') ||
        normalized.contains('افغانستان')) {
      return 'Afghanistan';
    }
    if (normalized.contains('turkey') || normalized.contains('تركيا')) {
      return 'Turkey';
    }
    return null;
  }

  double? _extractMargin(String normalized) {
    if (!normalized.contains('%') &&
        !normalized.contains('percent') &&
        !normalized.contains('margin') &&
        !normalized.contains('هامش')) {
      return null;
    }
    return _firstNumber(normalized);
  }

  String? _extractCustomer(String text) {
    final match = RegExp(
      r'(?:customer|client|عميل|زبون)\s+([A-Za-z\u0600-\u06FF ]{2,32})',
      caseSensitive: false,
    ).firstMatch(text);
    return match?.group(1)?.trim();
  }

  double? _firstNumber(String text) {
    final match = RegExp(r'(\d+(?:[.,]\d+)?)').firstMatch(text);
    if (match == null) return null;
    return double.tryParse(match.group(1)!.replaceAll(',', '.'));
  }

  bool _looksLikeAdvisorDiscussion(String normalized) {
    if (normalized.length < 3) return false;
    if (_containsAny(normalized, [
      '?',
      'what',
      'why',
      'how',
      'should',
      'can i',
      'هل',
      'كيف',
      'ماذا',
      'ليش',
      'ممكن',
    ])) {
      return true;
    }
    return !_isClearTransactionCommand(normalized);
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
}

class _AdvisorResponse {
  final AiChatMessageType type;
  final String text;
  final List<String> suggestedReplies;

  const _AdvisorResponse({
    required this.type,
    required this.text,
    this.suggestedReplies = const [],
  });
}

class _AdvisorSessionContext {
  String? currentProduct;
  String? currentDestination;
  double? currentMargin;
  double? currentCost;
  String? latestScenarioType;
  AiProposalModel? latestProposal;
  String? latestCustomer;
  _AdvisorIntent? latestTopic;
}
