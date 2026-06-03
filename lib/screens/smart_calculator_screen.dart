import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/app_copy.dart';
import '../core/app_formatters.dart';
import '../core/app_theme.dart';
import '../core/business/business_context.dart';
import '../data/models/smart_assistant_models.dart';
import '../data/services/smart_calculator_service.dart';
import '../widgets/premium/premium_card.dart';
import '../widgets/ai_design_system.dart';

class SmartCalculatorScreen extends StatefulWidget {
  const SmartCalculatorScreen({super.key, this.service});

  final SmartCalculatorService? service;

  @override
  State<SmartCalculatorScreen> createState() => _SmartCalculatorScreenState();
}

class _SmartCalculatorScreenState extends State<SmartCalculatorScreen> {
  final _controller = TextEditingController();
  final _searchController = TextEditingController();
  late final SmartCalculatorService _service;
  SmartAssistantPreview? _preview;
  List<SmartAssistantHistoryEntry> _history = [];
  bool _busy = false;

  bool get _isEnglish => Localizations.localeOf(context).languageCode == 'en';

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? SmartCalculatorService();
    _loadHistory();
  }

  @override
  void dispose() {
    _controller.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final history = await _service.recentHistory();
    if (mounted) setState(() => _history = history);
  }

  Future<void> _runPreview([String? value]) async {
    final input = (value ?? _controller.text).trim();
    if (input.isEmpty) return;
    setState(() => _busy = true);
    try {
      final preview = await _service.preview(input);
      if (mounted) {
        setState(() => _preview = preview);
        await _loadHistory();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirm() async {
    final preview = _preview;
    if (preview == null) return;
    if (preview.parse.missingFields.isNotEmpty) {
      final missing = preview.parse.missingFields.map(_label).join(', ');
      _showMessage(_text('Missing fields: $missing', 'حقول ناقصة: $missing'));
      return;
    }
    setState(() => _busy = true);
    try {
      final message = await _service.confirm(
        businessId: BusinessContext.resolveBusinessId(),
        preview: preview,
      );
      _showMessage(message);
      setState(() => _preview = null);
      await _loadHistory();
    } catch (error) {
      final msg = error is StateError ? error.message : error.toString();
      _showMessage(msg);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveDraft() async {
    final preview = _preview;
    if (preview == null) return;
    await _service.saveDraft(preview);
    _showMessage(_text('Draft saved locally.', 'تم حفظ المسودة محلياً.'));
    await _loadHistory();
  }

  void _editField(String key, Object? value) {
    final controller = TextEditingController(text: value?.toString() ?? '');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceSecondary,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXLarge)),
            border: Border.all(color: AppTheme.border),
          ),
          padding: EdgeInsets.fromLTRB(
              24, 32, 24, 32 + MediaQuery.viewInsetsOf(context).bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(_label(key),
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 20),
              TextField(
                controller: controller, 
                autofocus: true,
                decoration: InputDecoration(
                  hintText: _text('Enter new value', 'أدخل القيمة الجديدة'),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  final raw = controller.text.trim();
                  final parsed = double.tryParse(raw);
                  final next = _service
                      .previewWithFields(_preview!, {key: parsed ?? raw});
                  setState(() => _preview = next);
                  Navigator.pop(context);
                },
                child: Text(_text('Update Field', 'تحديث الحقل')),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.surfaceElevated,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMedium)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 800;
    
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          // Background Glow
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 400,
              height: 400,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.glowBlue,
              ),
            ),
          ),
          
          if (!isDesktop)
            AiMobilePageShell(
              child: Column(
                children: [
                  AiPageHeader(
                    title: _isEnglish ? 'Smart Financial Advisor' : 'المستشار المالي الذكي',
                    subtitle: _isEnglish
                        ? 'AI-powered local financial assistant'
                        : 'مركز التحكم الذكي في أعمالك التجارية.',
                  ),
                  const SizedBox(height: AiMobileConfig.sectionGap),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AiMobileConfig.horizontalPadding),
                    child: _mainColumn(),
                  ),
                  const SizedBox(height: AiMobileConfig.sectionGap),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AiMobileConfig.horizontalPadding),
                    child: _historyColumn(),
                  ),
                ],
              ),
            )
          else
            CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: AiPageHeader(
                    title: _isEnglish ? 'Smart Financial Advisor' : 'المستشار المالي الذكي',
                    subtitle: _isEnglish
                        ? 'AI-powered local financial assistant'
                        : 'مركز التحكم الذكي في أعمالك التجارية.',
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 140),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 2, child: _mainColumn()),
                        const SizedBox(width: 32),
                        Expanded(flex: 1, child: _historyColumn()),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          
          if (_preview != null) _floatingActionBar(isDesktop: isDesktop),
        ],
      ),
    );
  }

  Widget _mainColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _aiInputArea(),
        const SizedBox(height: 32),
        if (_preview != null) _previewDetails(_preview!) else _emptyState(),
      ],
    );
  }

  Widget _aiInputArea() {
    final suggestions = _isEnglish
        ? [
            'Bought 20 detergent cartons for 50 each',
            'Customer Ahmad paid 500 remaining 200',
            'Calculate 15% VAT on 1200',
          ]
        : [
            'اشتريت 20 كرتونة منظف بسعر 50 للواحدة',
            'زبون أحمد دفع 500 وباقي عليه 200',
            'احسب ضريبة 15% على 1200',
          ];

    final isDark = AppTheme.isDark(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.surfaceSecondary : Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            border: Border.all(
              color: AppTheme.accentBlue.withValues(alpha: 0.25),
              width: 1.5,
            ),
            boxShadow: AppTheme.softShadow(context),
          ),
          child: Column(
            children: [
              TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 3,
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  hintText: _text('What would you like to record?', 'ماذا تريد أن تسجل؟'),
                  fillColor: Colors.transparent,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: AppTheme.accentBlue, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      _text('AI Copilot active', 'المساعد الذكي نشط'),
                      style: GoogleFonts.inter(
                        fontSize: 12, 
                        fontWeight: FontWeight.w600,
                        color: AppTheme.accentBlue,
                      ),
                    ),
                    const Spacer(),
                    _busy 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : IconButton.filled(
                          onPressed: () => _runPreview(),
                          icon: const Icon(Icons.arrow_upward),
                          style: IconButton.styleFrom(
                            backgroundColor: AppTheme.accentBlue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: suggestions.map((s) => ActionChip(
                label: Text(s),
                onPressed: () {
                  _controller.text = s;
                  _runPreview(s);
                },
                side: BorderSide(
                  color: AppTheme.accentBlue.withValues(alpha: 0.3),
                  width: 1.2,
                ),
                backgroundColor: AppTheme.accentBlue.withValues(alpha: 0.08),
                labelStyle: const TextStyle(
                  color: AppTheme.accentBlue,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              )).toList(),
        ),
      ],
    );
  }

  Widget _previewDetails(SmartAssistantPreview preview) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                _text('Assistant Analysis', 'تحليل المساعد'),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 16),
            _ConfidenceBadge(value: preview.parse.confidence),
          ],
        ),
        const SizedBox(height: 24),
        _MetricGrid(preview: preview, isEnglish: _isEnglish),
        const SizedBox(height: 32),
        PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _text('Detailed Data Points', 'نقاط البيانات التفصيلية'),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: preview.fields
                    .map((field) => _PremiumFieldTile(
                          label: field.label,
                          value: _formatValue(field.value),
                          onTap: field.editable
                              ? () => _editField(field.key, field.value)
                              : null,
                        ))
                    .toList(),
              ),
              if (preview.parse.missingFields.isNotEmpty || preview.calculation.warnings.isNotEmpty) ...[
                const SizedBox(height: 24),
                _WarningList(
                  missing: preview.parse.missingFields.map((f) => _label(f)).toList(),
                  warnings: preview.calculation.warnings,
                  isEnglish: _isEnglish,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _historyColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _text('Recent Activity', 'النشاط الأخير'),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 20),
        PremiumCard(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: _text('Search history...', 'ابحث في السجل...'),
                  prefixIcon: const Icon(Icons.search, size: 20),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onChanged: (query) async {
                  final results = await _service.searchHistory(query);
                  if (mounted) setState(() => _history = results);
                },
              ),
              const SizedBox(height: 12),
              if (_history.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(_text('No history found', 'لا يوجد سجل')),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _history.length.clamp(0, 5),
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = _history[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      title: Text(item.userInput, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('${item.detectedIntent.name} • ${item.actionStatus.name}', style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryFor(context))),
                      trailing: const Icon(Icons.chevron_right, size: 16),
                    );
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _emptyState() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.aiGold.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.aiGold.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.psychology_rounded, color: AppTheme.aiGold, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _text('Financial AI Advisor Ready', 'المستشار الذكي جاهز'),
                  style: const TextStyle(color: AppTheme.aiGold, fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _text('Describe any business transaction in Arabic. The AI will parse metrics and calculate cash flows instantly.', 'اكتب عمليتك التجارية باللغة العربية (مثال: بعت 5 قطع بسعر 100). سيقوم المستشار بتحليلها وحساب الأرباح فوراً.'),
            style: const TextStyle(color: AppTheme.aiTextSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _floatingActionBar({required bool isDesktop}) {
    return Positioned(
      left: isDesktop ? 24 : AiMobileConfig.horizontalPadding,
      right: isDesktop ? 24 : AiMobileConfig.horizontalPadding,
      bottom: isDesktop ? 24 : AiMobileConfig.bottomClearance + 24,
      child: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceElevated.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.accentBlue.withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              IconButton(
                onPressed: () => setState(() => _preview = null),
                icon: const Icon(Icons.close),
                tooltip: _text('Dismiss', 'تجاهل'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: _saveDraft,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.surfaceSecondary,
                    side: const BorderSide(color: AppTheme.border),
                  ),
                  child: Text(_text('Save Draft', 'حفظ كمسودة')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _busy ? null : _confirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentBlue,
                    foregroundColor: Colors.white,
                  ),
                  child: _busy 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(_text('Confirm Entry', 'تأكيد العملية')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _text(String en, String ar) => _isEnglish ? en : ar;

  String _label(String key) => key
      .replaceAllMapped(RegExp(r'([A-Z])'), (m) => ' ${m.group(1)}')
      .replaceAll('_', ' ')
      .trim();

  String _formatValue(Object? value) {
    if (value is num) return AppFormatters.number(value.toDouble());
    return value?.toString() ?? '-';
  }
}

class _Header extends StatefulWidget {
  const _Header({required this.isEnglish});
  final bool isEnglish;

  @override
  State<_Header> createState() => _HeaderState();
}

class _HeaderState extends State<_Header> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.35, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final copy = AppCopy.of(context);
    final isDark = AppTheme.isDark(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.backgroundDeep : AppTheme.lightBackgroundDeep,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(AppTheme.radiusXLarge),
          bottomRight: Radius.circular(AppTheme.radiusXLarge),
        ),
        boxShadow: AppTheme.softShadow(context),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.accentBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                    border: Border.all(color: AppTheme.accentBlue.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Pulsing AI active indicator dot
                      FadeTransition(
                        opacity: _pulse,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppTheme.accentCyan,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.isEnglish ? 'LOCAL AI ENGINE ACTIVE' : 'محرك المساعد الذكي نشط',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                          color: AppTheme.accentBlue,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              copy.t('smartCopilot'),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : AppTheme.lightTextPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              copy.t('smartCopilotSubtitle'),
              style: TextStyle(
                color: AppTheme.textSecondaryFor(context),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.preview, required this.isEnglish});
  final SmartAssistantPreview preview;
  final bool isEnglish;

  @override
  Widget build(BuildContext context) {
    final values = preview.calculation.values;
    final tiles = [
      ('Total Cost', 'إجمالي التكلفة', values['totalCost'], Icons.shopping_cart_outlined),
      ('Revenue', 'الإيرادات', values['expectedRevenue'] ?? values['saleTotal'], Icons.payments_outlined),
      ('Net Profit', 'صافي الربح', values['expectedProfit'] ?? values['profit'], Icons.trending_up),
      ('Margin', 'الهامش', values['profitMargin'], Icons.pie_chart_outline),
    ].where((item) => item.$3 != null).toList();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.sizeOf(context).width > 600 ? 4 : 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.5,
      ),
      itemCount: tiles.length,
      itemBuilder: (context, index) {
        final item = tiles[index];
        return PremiumCard(
          padding: const EdgeInsets.all(16),
          radius: AppTheme.radiusMedium,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(item.$4, size: 20, color: AppTheme.accentBlue),
              const Spacer(),
              Text(
                isEnglish ? item.$1 : item.$2,
                style: TextStyle(color: AppTheme.textSecondaryFor(context), fontSize: 12),
              ),
              const SizedBox(height: 4),
              FittedBox(
                child: Text(
                  item.$3 is num ? AppFormatters.number((item.$3 as num).toDouble()) : item.$3.toString(),
                  style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 18),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ConfidenceBadge extends StatelessWidget {
  const _ConfidenceBadge({required this.value});
  final double value;

  @override
  Widget build(BuildContext context) {
    final color = value > 0.8 ? AppTheme.success : (value > 0.5 ? Colors.orange : Colors.red);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            '${(value * 100).round()}% Match',
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}

class _PremiumFieldTile extends StatelessWidget {
  const _PremiumFieldTile({required this.label, required this.value, this.onTap});
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceElevated.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: AppTheme.textSecondaryFor(context), fontSize: 11, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
              ],
            ),
            if (onTap != null)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 12),
                child: Icon(Icons.edit_outlined, size: 14, color: AppTheme.accentBlue.withValues(alpha: 0.6)),
              ),
          ],
        ),
      ),
    );
  }
}

class _WarningList extends StatelessWidget {
  const _WarningList({required this.missing, required this.warnings, required this.isEnglish});
  final List<String> missing;
  final List<String> warnings;
  final bool isEnglish;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.danger.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.danger.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...missing.map((m) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                const Icon(Icons.error_outline, size: 16, color: AppTheme.danger),
                const SizedBox(width: 8),
                Text('${isEnglish ? 'Missing' : 'ناقص'}: $m', style: const TextStyle(color: AppTheme.danger, fontWeight: FontWeight.w600)),
              ],
            ),
          )),
          ...warnings.map((w) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.orange),
                const SizedBox(width: 8),
                Text(w, style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w600)),
              ],
            ),
          )),
        ],
      ),
    );
  }
}

