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

class AiAccountantScreen extends StatefulWidget {
  const AiAccountantScreen({super.key});

  @override
  State<AiAccountantScreen> createState() => _AiAccountantScreenState();
}

class _AiAccountantScreenState extends State<AiAccountantScreen> {
  final _textController = TextEditingController();
  final _repository = AiAccountantRepositoryFactory.make();

  bool _isAnalyzing = false;
  bool _isCommitting = false;
  AiProposalModel? _activeProposal;
  AiProposalModel? _confirmationProposal;
  ProposalExecutionResult? _lastExecutionResult;

  static const Color darkBg = AppTheme.aiDeep;
  static const Color darkSurface = AppTheme.aiCard;
  static const Color goldAccent = AppTheme.aiGold;
  static const Color textSecondary = AppTheme.aiTextSecondary;
  static const Color borderTerminal = AppTheme.aiCardBorder;
  static const Color tealSuccess = AppTheme.aiGreen;

  final List<LedgerEntry> _ledgerRows = [
    LedgerEntry(
      code: 'JV-2026-089',
      account: 'مخزون السلع',
      debit: 56000,
      credit: 0,
      description: 'توريد شحنة بضائع مستوردة',
      date: '2026-06-08',
    ),
    LedgerEntry(
      code: 'JV-2026-089',
      account: 'حساب الموردين',
      debit: 0,
      credit: 56000,
      description: 'استحقاق فاتورة توريد',
      date: '2026-06-08',
    ),
    LedgerEntry(
      code: 'JV-2026-090',
      account: 'مصاريف شحن',
      debit: 12500,
      credit: 0,
      description: 'تكلفة شحن مرتبطة بالمخزون',
      date: '2026-06-09',
    ),
  ];

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _processAiCommand({String? customText}) async {
    final text = customText ?? _textController.text.trim();
    if (text.isEmpty) return;
    if (customText == null) _textController.clear();

    setState(() {
      _isAnalyzing = true;
      _activeProposal = null;
      _confirmationProposal = null;
      _lastExecutionResult = null;
    });

    try {
      final proposal = await _repository.parseNaturalLanguage(text);
      if (!mounted) return;
      setState(() {
        _activeProposal = proposal;
        _addPreviewLedgerRow(proposal);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _lastExecutionResult = ProposalExecutionResult(
          success: false,
          error: 'تعذر تحليل الطلب: $e',
        );
      });
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
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
        proposal.inventoryPayload?['name']?.toString() ?? 'صنف مقترح';
    _ledgerRows.insert(
      0,
      LedgerEntry(
        code: 'PENDING-AI',
        account: isPurchase ? 'مخزون الأصناف ($itemName)' : 'حساب المبيعات',
        debit: isPurchase ? total : 0,
        credit: isPurchase ? 0 : total,
        description: proposal.explanation,
        date: 'قيد قيد المراجعة',
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
    setState(() {
      _lastExecutionResult = const ProposalExecutionResult(
        success: false,
        requiresUserConfirmation: true,
        error: 'تحويل المحاكاة إلى عرض سعر يحتاج اختيار عميل وصنف مؤكدين أولا.',
      );
      _activeProposal = null;
      _confirmationProposal = null;
    });
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
        _lastExecutionResult = result;
        _confirmationProposal =
            result.requiresUserConfirmation ? proposal : null;
        if (clearActive) _activeProposal = null;
        _isCommitting = false;
        _markPreviewRow(result.success);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _lastExecutionResult = ProposalExecutionResult(
          success: false,
          error: 'تعذر تنفيذ العملية بأمان: $e',
        );
        _confirmationProposal = null;
        if (clearActive) _activeProposal = null;
        _isCommitting = false;
        _markPreviewRow(false);
      });
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
              ? '${row.description} (منفذ)'
              : '${row.description} (بحاجة مراجعة)',
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
        const SnackBar(content: Text('لم يتم العثور على الصنف.')),
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
          builder: (_) => InvoiceDetailsScreen(invoiceId: invoiceId)),
    );
  }

  Future<void> _copyExecutionSummary(ProposalExecutionResult result) async {
    await Clipboard.setData(ClipboardData(text: _resultSummary(result)));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم نسخ ملخص العملية.')),
    );
  }

  String _resultSummary(ProposalExecutionResult result) {
    final data = _asMap(result.data);
    final product = _asMap(data['product']);
    final invoice = _asMap(data['invoice']);
    final journal = _asMap(data['journalEntry']);
    return [
      'الحالة: ${_statusLabel(result, data)}',
      if ((result.message ?? '').isNotEmpty) 'الرسالة: ${result.message}',
      if ((result.error ?? '').isNotEmpty) 'الخطأ: ${result.error}',
      if (product.isNotEmpty)
        'الصنف: ${product['id'] ?? '-'} / ${product['name'] ?? '-'}',
      if (invoice.isNotEmpty)
        'الفاتورة: ${invoice['id'] ?? '-'} / ${invoice['number'] ?? '-'}',
      if (journal.isNotEmpty)
        'القيد: ${journal['id'] ?? '-'} / ${journal['code'] ?? '-'}',
    ].join('\n');
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
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
                            Expanded(flex: 3, child: _buildLedgerPanel()),
                            Expanded(flex: 2, child: _buildAiPanel()),
                          ],
                        )
                      : ListView(
                          padding: const EdgeInsets.only(bottom: 112),
                          children: [
                            SizedBox(height: 340, child: _buildLedgerPanel()),
                            _buildAiPanel(isMobile: true),
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
            const Icon(Icons.account_balance_wallet_outlined,
                color: goldAccent, size: 20),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'HASOOB | مراجعة العمليات المحاسبية',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  letterSpacing: 0,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: tealSuccess.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: tealSuccess.withValues(alpha: 0.35)),
              ),
              child: const Text(
                'جاهز للمراجعة',
                style: TextStyle(
                    color: tealSuccess,
                    fontSize: 11,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLedgerPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: borderTerminal)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'دفتر الأستاذ واليومية',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                'عدد السطور: ${_ledgerRows.length}',
                style: const TextStyle(color: textSecondary, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: darkSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderTerminal),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
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
                            label: Text('كود القيد',
                                style: TextStyle(
                                    color: goldAccent,
                                    fontWeight: FontWeight.w700))),
                        DataColumn(
                            label: Text('الحساب',
                                style: TextStyle(color: Colors.white70))),
                        DataColumn(
                            label: Text('مدين',
                                style: TextStyle(color: Colors.white70))),
                        DataColumn(
                            label: Text('دائن',
                                style: TextStyle(color: Colors.white70))),
                        DataColumn(
                            label: Text('البيان',
                                style: TextStyle(color: Colors.white70))),
                      ],
                      rows: _ledgerRows.map((row) {
                        return DataRow(
                          color: row.isUncommitted
                              ? WidgetStateProperty.all(
                                  goldAccent.withValues(alpha: 0.06))
                              : null,
                          cells: [
                            DataCell(Text(row.code,
                                style: TextStyle(
                                    color: row.isUncommitted
                                        ? goldAccent
                                        : textSecondary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11))),
                            DataCell(Text(row.account,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 12))),
                            DataCell(Text(
                                row.debit > 0
                                    ? row.debit.toStringAsFixed(2)
                                    : '-',
                                style: const TextStyle(
                                    color: AppTheme.aiRed,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700))),
                            DataCell(Text(
                                row.credit > 0
                                    ? row.credit.toStringAsFixed(2)
                                    : '-',
                                style: const TextStyle(
                                    color: tealSuccess,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700))),
                            DataCell(Text(row.description,
                                style: TextStyle(
                                    color: row.isUncommitted
                                        ? Colors.white
                                        : Colors.white70,
                                    fontSize: 11))),
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
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'المحاسب الذكي',
            style: TextStyle(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            'اكتب عملية شراء أو بيع أو طلب تسعير. سيظهر المقترح للمراجعة قبل أي تنفيذ.',
            style: TextStyle(color: textSecondary, fontSize: 12, height: 1.4),
          ),
          const Divider(color: borderTerminal, height: 24),
          Expanded(
            child: _activeProposal != null
                ? _buildProposalCard(_activeProposal!)
                : (_lastExecutionResult != null
                    ? _buildExecutionResultCard(_lastExecutionResult!)
                    : _buildEmptyState()),
          ),
          if (!_isAnalyzing && _activeProposal == null)
            _buildQuickPromptsStrip(),
          const SizedBox(height: 10),
          _buildInputField(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.account_balance_outlined, color: borderTerminal, size: 44),
          SizedBox(height: 12),
          Text(
            'أدخل طلبا ماليا واضحا.\nلن يتم تنفيذ أي عملية قبل ظهور المقترح أو نتيجة المراجعة.',
            textAlign: TextAlign.center,
            style: TextStyle(color: textSecondary, fontSize: 12, height: 1.5),
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

    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: darkSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: isPricing
                  ? tealSuccess.withValues(alpha: 0.6)
                  : goldAccent.withValues(alpha: 0.55)),
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
                    size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isPricing ? 'مقترح تسعير' : 'مقترح عملية محاسبية',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800),
                  ),
                ),
                _statusPill(
                    '${(proposal.confidenceScore * 100).clamp(0, 100).toStringAsFixed(0)}%',
                    goldAccent),
              ],
            ),
            const Divider(color: borderTerminal, height: 22),
            Text(proposal.explanation,
                style: const TextStyle(
                    color: Colors.white, fontSize: 12, height: 1.5)),
            const SizedBox(height: 14),
            if (isPricing) ...[
              _detailLine(Icons.location_on_outlined, 'الوجهة',
                  '${pricing['destination'] ?? '-'}'),
              _detailLine(Icons.inventory_2_outlined, 'الكمية المتوقعة',
                  '${pricing['estimatedTotalBoxes'] ?? '-'}'),
              _detailLine(Icons.price_change_outlined, 'التكلفة الواصلة',
                  '${pricing['landedCostPerUnit'] ?? '-'}'),
              _detailLine(Icons.trending_up_rounded, 'السعر المقترح',
                  '${pricing['suggestedPricePerUnit'] ?? '-'}'),
            ] else ...[
              _detailLine(Icons.inventory_2_outlined, 'الصنف',
                  '${inventory['name'] ?? inventory['productId'] ?? '-'}'),
              _detailLine(Icons.format_list_numbered_rtl, 'الكمية',
                  '${inventory['quantity'] ?? '-'}'),
              _detailLine(Icons.payments_outlined, 'القيمة',
                  '${financial['totalAmount'] ?? '-'}'),
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
                    label: const Text('حفظ المحاكاة'),
                  )
                else
                  FilledButton.icon(
                    onPressed: _isCommitting ? null : _commitProposalToLedger,
                    icon: _isCommitting
                        ? _miniProgress()
                        : const Icon(Icons.check_circle_outline, size: 16),
                    label: const Text('تنفيذ بعد المراجعة'),
                  ),
                if (isPricing)
                  OutlinedButton.icon(
                    onPressed:
                        _isCommitting ? null : _convertPricingToQuotation,
                    icon: const Icon(Icons.request_quote_outlined, size: 16),
                    label: const Text('تحويل إلى عرض سعر'),
                  ),
                OutlinedButton.icon(
                  onPressed: _isCommitting
                      ? null
                      : () => setState(() {
                            _activeProposal = null;
                            _ledgerRows
                                .removeWhere((row) => row.code == 'PENDING-AI');
                          }),
                  icon: const Icon(Icons.close_rounded, size: 16),
                  label: const Text('تجاهل'),
                ),
              ],
            ),
          ],
        ),
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

    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: darkSurface,
          borderRadius: BorderRadius.circular(10),
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
                        fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const Divider(color: borderTerminal, height: 22),
            Text(
              result.message ?? result.error ?? 'لا توجد تفاصيل إضافية.',
              style: const TextStyle(
                  color: Colors.white, fontSize: 12, height: 1.5),
            ),
            const SizedBox(height: 12),
            if (product.isNotEmpty)
              _detailLine(Icons.inventory_2_outlined, 'الصنف',
                  '${product['id'] ?? '-'} | ${product['name'] ?? '-'}'),
            if (invoice.isNotEmpty)
              _detailLine(Icons.receipt_long_outlined, 'الفاتورة',
                  '${invoice['id'] ?? '-'} | ${invoice['number'] ?? '-'}'),
            if (journal.isNotEmpty)
              _detailLine(Icons.account_balance_outlined, 'قيد اليومية',
                  '${journal['id'] ?? '-'} | ${journal['code'] ?? '-'}'),
            if (pricing.isNotEmpty)
              _detailLine(Icons.price_check_outlined, 'محاكاة التسعير',
                  '${pricing['id'] ?? '-'} | ${pricing['suggestedPrice'] ?? pricing['suggestedPricePerUnit'] ?? '-'}'),
            _detailLine(
                Icons.sync_rounded,
                'حالة المزامنة',
                sync['status']?.toString() ??
                    (result.success ? 'queued' : '-')),
            _detailLine(
                Icons.fact_check_outlined,
                'سجل التدقيق',
                audit['status']?.toString() ??
                    (result.success ? 'stored' : '-')),
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
                    label: const Text('عرض الصنف'),
                  ),
                if ((invoice['id'] ?? '').toString().isNotEmpty)
                  TextButton.icon(
                    onPressed: () => _openInvoice(invoice['id'].toString()),
                    icon: const Icon(Icons.receipt_long_outlined, size: 16),
                    label: const Text('عرض الفاتورة'),
                  ),
                if ((journal['id'] ?? '').toString().isNotEmpty)
                  TextButton.icon(
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content:
                              Text('يمكن مراجعة قيد اليومية من دفتر الأستاذ.')),
                    ),
                    icon: const Icon(Icons.account_balance_outlined, size: 16),
                    label: const Text('عرض القيد'),
                  ),
                TextButton.icon(
                  onPressed: () => _copyExecutionSummary(result),
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('نسخ الملخص'),
                ),
                TextButton.icon(
                  onPressed: () => setState(() {
                    _lastExecutionResult = null;
                    _confirmationProposal = null;
                  }),
                  icon: const Icon(Icons.close_rounded, size: 16),
                  label: const Text('إغلاق'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCandidateProductList(List<Map<String, dynamic>> candidates) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: goldAccent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: goldAccent.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'اختر الصنف الصحيح قبل التنفيذ',
            style: TextStyle(
                color: goldAccent, fontSize: 12, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          ...candidates.map((candidate) {
            final id =
                (candidate['id'] ?? candidate['productId'] ?? '').toString();
            final name = (candidate['name'] ??
                    candidate['productName'] ??
                    'صنف بدون اسم')
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
                    OutlinedButton.styleFrom(alignment: Alignment.centerRight),
                child: Text('$name | $id | المخزون: $stock',
                    overflow: TextOverflow.ellipsis),
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
            context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
        icon: const Icon(Icons.settings_outlined, size: 16),
        label: const Text('إكمال إعداد الحسابات'),
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
            width: 104,
            child: Text(label,
                style: const TextStyle(color: textSecondary, fontSize: 11)),
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
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w700)),
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
      'اشتريت 150 كرتون شوكولاتة بسعر 85 دولار كاش',
      'بعت 12 كرتون بسعر 120 دولار للعميل أحمد',
      'احسب سعر حاوية 20 قدم بهامش ربح 25%',
    ];
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        reverse: true,
        itemCount: prompts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          return ActionChip(
            backgroundColor: darkSurface,
            side: const BorderSide(color: borderTerminal),
            label: Text(prompts[index],
                style: const TextStyle(color: textSecondary, fontSize: 11)),
            onPressed: () => _processAiCommand(customText: prompts[index]),
          );
        },
      ),
    );
  }

  Widget _buildInputField() {
    return Container(
      decoration: BoxDecoration(
        color: darkSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderTerminal),
      ),
      child: Row(
        children: [
          IconButton(
            icon: _isAnalyzing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        color: goldAccent, strokeWidth: 2))
                : const Icon(Icons.send_rounded, color: goldAccent, size: 18),
            onPressed: _isAnalyzing ? null : () => _processAiCommand(),
          ),
          Expanded(
            child: TextField(
              controller: _textController,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              decoration: const InputDecoration(
                hintText: 'اكتب عملية مالية أو طلب تسعير...',
                hintStyle: TextStyle(color: AppTheme.aiTextMuted, fontSize: 12),
                border: InputBorder.none,
              ),
              onSubmitted: (_) => _processAiCommand(),
            ),
          ),
          const SizedBox(width: 10),
        ],
      ),
    );
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
    if (result.requiresUserConfirmation) return 'بحاجة إلى تأكيد';
    if (result.success && _asMap(data['auditLog'])['status'] == 'failed') {
      return 'تم التنفيذ مع مزامنة جزئية';
    }
    if (result.success) return 'تم التنفيذ';
    return 'تعذر التنفيذ';
  }

  IconData _statusIcon(ProposalExecutionResult result, bool partialSync) {
    if (result.requiresUserConfirmation) return Icons.rule_folder_outlined;
    if (partialSync) return Icons.sync_problem_outlined;
    if (result.success) return Icons.verified_rounded;
    return Icons.report_problem_outlined;
  }
}
