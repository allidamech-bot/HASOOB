import 'package:flutter/material.dart';
import '../../data/models/ai_proposal_model.dart';
import '../../data/repositories/ai_accountant_repository_factory.dart';

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
  
  // Dense Real-World Accounting Mock Database
  final List<LedgerEntry> _ledgerRows = [
    LedgerEntry(code: "JV-2026-089", account: "مخزون السلع (بسكويت وشوكولاتة)", debit: 56000.0, credit: 0.0, description: "توريد شحنة Altınmarka جمارك الميناء", date: "2026-06-08"),
    LedgerEntry(code: "JV-2026-089", account: "حساب الموردين (مؤسسة ميم للاستيراد)", debit: 0.0, credit: 56000.0, description: "استحقاق فاتورة توريد سلع واصلة", date: "2026-06-08"),
    LedgerEntry(code: "JV-2026-090", account: "الصندوق والنقدية (كاش)", debit: 0.0, credit: 12500.0, description: "دفع مصاريف شحن بحري - حاوية 20 قدم", date: "2026-06-09"),
    LedgerEntry(code: "JV-2026-090", account: "مصاريف شحن لوجستي دولي", debit: 12500.0, credit: 0.0, description: "توزيع تكاليف Landed Cost للشحنة", date: "2026-06-09"),
  ];

  // Established Luxury System Colors
  static const Color darkBg = Color(0xFF070A0F);       // Deep Intense Black
  static const Color darkSurface = Color(0xFF0F141C);  // Tech Steel Card
  static const Color goldAccent = Color(0xFFD4AF37);   // Corporate Matte Gold
  static const Color textSecondary = Color(0xFF8A93A6);
  static const Color borderTerminal = Color(0xFF1C2430);
  static const Color tealSuccess = Color(0xFF0D9488);

  Future<void> _processAiCommand({String? customText}) async {
    final text = customText ?? _textController.text.trim();
    if (text.isEmpty) return;

    if (customText == null) _textController.clear();

    setState(() {
      _isAnalyzing = true;
      _activeProposal = null;
    });

    try {
      final proposal = await _repository.parseNaturalLanguage(text);
      if (!mounted) return;

      setState(() {
        _activeProposal = proposal;
        
        // If it's a valid financial entry, dynamically inject an uncommitted flashing spreadsheet row live
        if (proposal.actionType != 'unknown' && proposal.actionType != 'pricing_simulation') {
          final isPurchase = proposal.actionType == 'purchase';
          final total = proposal.financialPayload?['totalAmount'] ?? 15000.0;
          final itemName = proposal.inventoryPayload?['name'] ?? 'بضاعة مستخرجة آلياً';
          
          _ledgerRows.insert(0, LedgerEntry(
            code: "PENDING-AI",
            account: isPurchase ? "مخزون الأصناف ($itemName)" : "حساب المبيعات المستهدفة",
            debit: isPurchase ? total : 0.0,
            credit: isPurchase ? 0.0 : total,
            description: proposal.explanation,
            date: "معالجة لحظية",
            isUncommitted: true,
          ));
        }
      });
    } catch (_) {
      // Safeguard pipeline
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  void _commitProposalToLedger() {
    if (_activeProposal == null) return;
    
    setState(() => _isCommitting = true);
    
    // Simulate real database serialization and conversion from uncommitted draft to legal book entry
    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      setState(() {
        for (int i = 0; i < _ledgerRows.length; i++) {
          if (_ledgerRows[i].code == "PENDING-AI") {
            _ledgerRows[i] = LedgerEntry(
              code: "JV-2026-091",
              account: _ledgerRows[i].account,
              debit: _ledgerRows[i].debit,
              credit: _ledgerRows[i].credit,
              description: _ledgerRows[i].description,
              date: "2026-06-09",
              isUncommitted: false,
            );
          }
        }
        _activeProposal = null;
        _isCommitting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔒 تم توثيق الدفاتر المحاسبية الرسمية وتحديث دفتر الأستاذ بنجاح.', textDirection: TextDirection.rtl),
          backgroundColor: tealSuccess,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkBg,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWidescreen = constraints.maxWidth > 1000;
          
          return Column(
            children: [
              // 1. Enterprise Top Metric Dashboard Ribbon Strip
              _buildTopFinancialRibbon(),
              
              // 2. Main Terminal Content Layout Workspace Split Grid
              Expanded(
                child: isWidescreen 
                  ? Row(
                      textDirection: TextDirection.rtl,
                      children: [
                        // Right Pane: The Heavy-Duty Corporate Spreadsheet & General Ledger Book
                        Expanded(flex: 3, child: _buildGeneralLedgerSpreadsheet()),
                        // Left Pane: The Autonomous AI Operator Control Station
                        Expanded(flex: 2, child: _buildAiOperatorConsole()),
                      ],
                    )
                  : SingleChildScrollView(
                      child: Column(
                        children: [
                          SizedBox(height: 400, child: _buildGeneralLedgerSpreadsheet()),
                          _buildAiOperatorConsole(),
                        ],
                      ),
                    ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTopFinancialRibbon() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
      decoration: const BoxDecoration(
        color: darkSurface,
        border: Border(bottom: BorderSide(color: borderTerminal, width: 1.5)),
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Row(
            textDirection: TextDirection.rtl,
            children: [
              Icon(Icons.account_balance_wallet_outlined, color: goldAccent, size: 20),
              SizedBox(width: 10),
              Text(
                'HASOOB | محطة العمليات والتدقيق المالي المركزية',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.5),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: tealSuccess, width: 0.8),
            ),
            child: const Row(
              children: [
                CircleAvatar(radius: 3, backgroundColor: tealSuccess),
                SizedBox(width: 6),
                Text('عقل النواة الحية نشط وجاهز للترحيل', style: TextStyle(color: tealSuccess, fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildGeneralLedgerSpreadsheet() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: borderTerminal, width: 1.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        textDirection: TextDirection.rtl,
        children: [
          Row(
            textDirection: TextDirection.rtl,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('📖 دفتر الأستاذ العام ودفتر اليومية الموحد (Live Spreadsheet)', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
              Text('إجمالي العمليات الموثقة: ${_ledgerRows.length}', style: const TextStyle(color: textSecondary, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 16),
          
          // Dense Matrix Accounting Spreadsheet Table Structure
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: darkSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: borderTerminal),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(const Color(0xFF141B26)),
                    dataRowMinHeight: 46,
                    dataRowMaxHeight: 52,
                    horizontalMargin: 12,
                    columnSpacing: 14,
                    columns: const [
                      DataColumn(label: Text('كود القيد', style: TextStyle(color: goldAccent, fontSize: 12, fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('الحساب المالي للشركات', style: TextStyle(color: Colors.white70, fontSize: 12))),
                      DataColumn(label: Text('مدين (+)', style: TextStyle(color: Colors.white70, fontSize: 12))),
                      DataColumn(label: Text('دائن (-)', style: TextStyle(color: Colors.white70, fontSize: 12))),
                      DataColumn(label: Text('البيان التفصيلي للمعاملة', style: TextStyle(color: Colors.white70, fontSize: 12))),
                    ],
                    rows: _ledgerRows.map((row) {
                      return DataRow(
                        color: row.isUncommitted 
                            ? WidgetStateProperty.all(const Color(0xFF16251F)) // Distinctive flashing color for pending AI operations
                            : null,
                        cells: [
                          DataCell(Text(row.code, style: TextStyle(color: row.isUncommitted ? tealSuccess : textSecondary, fontSize: 11, fontWeight: FontWeight.bold))),
                          DataCell(Text(row.account, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500))),
                          DataCell(Text(row.debit > 0 ? '${row.debit.toStringAsFixed(2)} \$' : '-', style: const TextStyle(color: Color(0xFFEF4444), fontSize: 11, fontWeight: FontWeight.bold))),
                          DataCell(Text(row.credit > 0 ? '${row.credit.toStringAsFixed(2)} \$' : '-', style: const TextStyle(color: tealSuccess, fontSize: 11, fontWeight: FontWeight.bold))),
                          DataCell(Text(row.description, style: TextStyle(color: row.isUncommitted ? Colors.white : Colors.white70, fontSize: 11, fontStyle: row.isUncommitted ? FontStyle.italic : FontStyle.normal))),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiOperatorConsole() {
    return Container(
      color: const Color(0xFF0A0E15),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        textDirection: TextDirection.rtl,
        children: [
          const Text('🤖 مستشار العمليات المالي ومحاكي العقود الدولي', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('أدخل الأوامر المباشرة أو فواتير الاستيراد لبناء وتعديل الدفاتر الرسمية حياً.', style: TextStyle(color: textSecondary, fontSize: 11)),
          const Divider(color: borderTerminal, height: 24),
          
          // Dynamic Workspace Canvas Area: Shows instructions or interactive formal invoice vouchers
          Expanded(
            child: _activeProposal == null 
                ? _buildEmptyStateConsoleInstruction()
                : _buildFormalVoucherPreviewCard(),
          ),

          // Core Quick Commands Pipeline Bar
          if (!_isAnalyzing && _activeProposal == null) _buildQuickPromptsStrip(),
          const SizedBox(height: 8),

          // Luxury Dark SaaS Embedded Execution Input Deck
          _buildTerminalInputField(),
        ],
      ),
    );
  }

  Widget _buildEmptyStateConsoleInstruction() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.terminal_rounded, color: borderTerminal, size: 48),
          SizedBox(height: 12),
          Text(
            'محرك الذكاء المالي بانتظار إشارتك...\nاضغط على أحد الأوامر الجاهزة أو اكتب عملية لتشاهد حقن البيانات الحية في الجدول جانبياً.',
            textAlign: TextAlign.center,
            style: TextStyle(color: textSecondary, fontSize: 12, height: 1.5),
            textDirection: TextDirection.rtl,
          ),
        ],
      ),
    );
  }

  Widget _buildFormalVoucherPreviewCard() {
    final isPricing = _activeProposal!.actionType == 'pricing_simulation';
    
    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: darkSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isPricing ? tealSuccess : goldAccent, width: 1.2),
          boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 12)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          textDirection: TextDirection.rtl,
          children: [
            // Voucher Formal Corporate Seal Header
            Row(
              textDirection: TextDirection.rtl,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isPricing ? '📊 دراسة جدوى تسعير وحاوية شحن دولية' : '📝 سند قيد تعميد مالي مستخلص ومقترح آلياً',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  color: isPricing ? tealSuccess.withValues(alpha: 0.2) : goldAccent.withValues(alpha: 0.2),
                  child: Text(
                    isPricing ? 'LOGISTICS' : 'LEDGER DRAFT',
                    style: TextStyle(color: isPricing ? tealSuccess : goldAccent, fontSize: 9, fontWeight: FontWeight.bold),
                  ),
                )
              ],
            ),
            const Divider(color: borderTerminal, height: 24),
            
            Text(
              _activeProposal!.explanation,
              style: const TextStyle(color: Color(0xFFEEEEEE), fontSize: 12, height: 1.5),
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 16),

            if (isPricing && _activeProposal!.pricingPayload != null) ...[
              _buildFormRow(Icons.location_on_outlined, 'الوجهة الدولية:', _activeProposal!.pricingPayload!['destination']),
              _buildFormRow(Icons.inventory_2_outlined, 'سعة تعبئة الحاوية 20ft:', '${_activeProposal!.pricingPayload!['estimatedTotalBoxes']} كرتون عيار قياسي'),
              _buildFormRow(Icons.trending_up_rounded, 'هامش الربح المستهدف:', '${_activeProposal!.pricingPayload!['targetMarginPercentage']}% صافي من المبيعات'),
              const Divider(color: borderTerminal, height: 20),
              Row(
                textDirection: TextDirection.rtl,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildMetricBlock('التكلفة الواصلة للكرتون (Landed)', '${_activeProposal!.pricingPayload!['landedCostPerUnit']} \$', goldAccent),
                  _buildMetricBlock('السعر الأدنى لضمان الربح', '${_activeProposal!.pricingPayload!['suggestedPricePerUnit']} \$', tealSuccess),
                ],
              )
            ] else ...[
              if (_activeProposal!.inventoryPayload != null)
                _buildFormRow(Icons.storefront_outlined, 'الصنف والمستودع المستهدف:', '"${_activeProposal!.inventoryPayload!['name']}" | العدد: ${_activeProposal!.inventoryPayload!['quantity']} كرتون'),
              if (_activeProposal!.customerPayload != null)
                _buildFormRow(Icons.business_center_outlined, 'أطراف التعاقد والتوريد:', _activeProposal!.customerPayload!['name']),
              if (_activeProposal!.financialPayload != null) ...[
                const Divider(color: borderTerminal, height: 16),
                _buildFormRow(Icons.monetization_on_outlined, 'القيمة الإجمالية الصافية:', '${_activeProposal!.financialPayload!['totalAmount']} \$ أمريكي'),
                _buildFormRow(Icons.check_circle_outline, 'الضرائب المقدرة وعوائد VAT:', 'مشمولة بنسبة 15% قانونية'),
              ]
            ],
            
            const SizedBox(height: 20),
            Row(
              textDirection: TextDirection.rtl,
              children: [
                Expanded(
                  child: SizedBox(
                    height: 38,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isPricing ? tealSuccess : goldAccent,
                        foregroundColor: isPricing ? Colors.white : Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        elevation: 0,
                      ),
                      onPressed: _isCommitting ? null : (isPricing ? () => setState(() => _activeProposal = null) : _commitProposalToLedger),
                      child: _isCommitting 
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                          : Text(isPricing ? 'حفظ وإيداع دراسة الجدوى' : 'توقيع وتعميد السند رسمياً', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: borderTerminal),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                  onPressed: () {
                    setState(() {
                      // Remove uncommitted temporary visualization row if cancelled
                      _ledgerRows.removeWhere((row) => row.code == "PENDING-AI");
                      _activeProposal = null;
                    });
                  },
                  child: const Text('إلغاء وفك السند', style: TextStyle(fontSize: 12)),
                )
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildFormRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Icon(icon, color: textSecondary, size: 14),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: textSecondary, fontSize: 11)),
          const SizedBox(width: 4),
          Expanded(child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis, textDirection: TextDirection.rtl)),
        ],
      ),
    );
  }

  Widget _buildMetricBlock(String title, String val, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      textDirection: TextDirection.rtl,
      children: [
        Text(title, style: const TextStyle(color: textSecondary, fontSize: 10)),
        const SizedBox(height: 2),
        Text(val, style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildQuickPromptsStrip() {
    final prompts = [
      "أخطط لتصدير حاوية 20 قدم علك لأفغانستان شحن 3500 جمارك 1200 تكلفة الكرتون 45 كم أسعر لربح 25%؟",
      "اشتريت 150 كرتون شوكولاتة Godiva بسعر 85 دولار كاش من التوريد",
    ];
    return SizedBox(
      height: 34,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        reverse: true,
        itemCount: prompts.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ActionChip(
              backgroundColor: darkSurface,
              side: const BorderSide(color: borderTerminal),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              label: Text(
                prompts[index].length > 45 ? '${prompts[index].substring(0, 42)}...' : prompts[index],
                style: const TextStyle(color: textSecondary, fontSize: 10),
              ),
              onPressed: () => _processAiCommand(customText: prompts[index]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTerminalInputField() {
    return Container(
      decoration: BoxDecoration(
        color: darkSurface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderTerminal),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: _isAnalyzing 
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: goldAccent, strokeWidth: 2))
                : const Icon(Icons.flash_on_rounded, color: goldAccent, size: 18),
            onPressed: _isAnalyzing ? null : () => _processAiCommand(),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: _textController,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'Courier'),
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              decoration: const InputDecoration(
                hintText: 'أدخل أمر الترحيل المالي أو استعلام محاكاة تسعير الحاويات الدولي...',
                hintStyle: TextStyle(color: Color(0xFF434E5E), fontSize: 11),
                border: InputBorder.none,
              ),
              onSubmitted: (_) => _processAiCommand(),
            ),
          ),
        ],
      ),
    );
  }
}
