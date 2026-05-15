import 'package:flutter/material.dart';

import '../core/app_formatters.dart';
import '../core/app_theme.dart';
import '../core/business/business_context.dart';
import '../data/models/smart_assistant_models.dart';
import '../data/services/smart_calculator_service.dart';
import '../widgets/premium/premium_card.dart';

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
      _showMessage(_text('Complete missing fields before confirming.',
          'أكمل الحقول الناقصة قبل التأكيد.'));
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
      _showMessage(error.toString());
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
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(_label(key),
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              TextField(controller: controller, autofocus: true),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  final raw = controller.text.trim();
                  final parsed = double.tryParse(raw);
                  final next = _service
                      .previewWithFields(_preview!, {key: parsed ?? raw});
                  setState(() => _preview = next);
                  Navigator.pop(context);
                },
                child: Text(_text('Apply', 'تطبيق')),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 900;
    final body = CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverToBoxAdapter(child: _Header(isEnglish: _isEnglish)),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
          sliver: SliverToBoxAdapter(
            child: isWide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 7, child: _mainColumn()),
                      const SizedBox(width: 18),
                      Expanded(flex: 4, child: _historyCard()),
                    ],
                  )
                : Column(
                    children: [
                      _mainColumn(),
                      const SizedBox(height: 18),
                      _historyCard(),
                    ],
                  ),
          ),
        ),
      ],
    );

    return Scaffold(
      body: Stack(
        children: [
          body,
          if (_preview != null) _stickyActions(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _runPreview(),
        icon: _busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.auto_awesome),
        label: Text(_text('Analyze locally', 'تحليل محلي')),
      ),
    );
  }

  Widget _mainColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _inputCard(),
        const SizedBox(height: 18),
        if (_preview != null) _previewCard(_preview!) else _emptyState(),
      ],
    );
  }

  Widget _inputCard() {
    final suggestions = _isEnglish
        ? [
            'Bought 20 detergent cartons for 50 and want to sell for 75',
            'Customer Ahmad paid 500 remaining 200',
            'Calculate VAT 15% on 1200',
          ]
        : [
            'اشتريت 20 كرتونة منظف بسعر 50 وبدي بيعها 75',
            'زبون أحمد دفع 500 وباقي عليه 200',
            'احسب ضريبة 15% على 1200',
          ];
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            minLines: 4,
            maxLines: 8,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(
              hintText: _text(
                  'Write a business instruction in Arabic or English...',
                  'اكتب تعليمات تجارية بالعربية أو الإنجليزية...'),
              prefixIcon: const Icon(Icons.edit_note),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: suggestions
                .map((s) => ActionChip(
                      avatar: const Icon(Icons.bolt, size: 18),
                      label: Text(s, overflow: TextOverflow.ellipsis),
                      onPressed: () {
                        _controller.text = s;
                        _runPreview(s);
                      },
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _previewCard(SmartAssistantPreview preview) {
    const warningStyle =
        TextStyle(color: AppTheme.warning, fontWeight: FontWeight.w700);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: PremiumCard(
        key: ValueKey(preview.parse.userInput + preview.parse.intent.name),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _text('Confirmation preview', 'معاينة قبل التأكيد'),
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                ),
                _ConfidencePill(value: preview.parse.confidence),
              ],
            ),
            const SizedBox(height: 14),
            _MetricStrip(preview: preview, isEnglish: _isEnglish),
            const SizedBox(height: 18),
            Text(preview.calculation.summary,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: preview.fields
                  .map((field) => _FieldChip(
                        label: field.label,
                        value: _formatValue(field.value),
                        onTap: field.editable
                            ? () => _editField(field.key, field.value)
                            : null,
                      ))
                  .toList(),
            ),
            if (preview.parse.missingFields.isNotEmpty ||
                preview.calculation.warnings.isNotEmpty) ...[
              const SizedBox(height: 16),
              ...preview.parse.missingFields.map((f) => Text(
                  '${_text('Missing', 'ناقص')}: ${_label(f)}',
                  style: warningStyle)),
              ...preview.calculation.warnings
                  .map((w) => Text(w, style: warningStyle)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _historyCard() {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.history),
              const SizedBox(width: 8),
              Expanded(
                child: Text(_text('Recent activity', 'النشاط الأخير'),
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: _text('Search history', 'بحث في السجل'),
              prefixIcon: const Icon(Icons.search),
            ),
            onChanged: (query) async {
              final results = await _service.searchHistory(query);
              if (mounted) setState(() => _history = results);
            },
          ),
          const SizedBox(height: 12),
          if (_history.isEmpty)
            Text(_text('No local history yet.', 'لا يوجد سجل محلي بعد.'))
          else
            ..._history.take(8).map((item) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(item.userInput,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                      '${item.detectedIntent.name} · ${item.actionStatus.name}'),
                  leading: const Icon(Icons.receipt_long),
                )),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return PremiumCard(
      child: Column(
        children: [
          const Icon(Icons.lock_outline, size: 42),
          const SizedBox(height: 12),
          Text(_text('100% local assistant', 'مساعد محلي بالكامل'),
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(
            _text(
                'Deterministic rules, regex extraction, and business calculations. No cloud AI, no API keys.',
                'قواعد حتمية واستخراج منظم وحسابات تجارية فقط. بدون ذكاء اصطناعي سحابي أو مفاتيح API.'),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _stickyActions() {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 16,
      child: SafeArea(
        child: PremiumCard(
          padding: const EdgeInsets.all(12),
          radius: 18,
          child: Row(
            children: [
              Expanded(
                  child: OutlinedButton(
                      onPressed: () => setState(() => _preview = null),
                      child: Text(_text('Cancel', 'إلغاء')))),
              const SizedBox(width: 8),
              Expanded(
                  child: OutlinedButton(
                      onPressed: _saveDraft,
                      child: Text(_text('Save draft', 'حفظ مسودة')))),
              const SizedBox(width: 8),
              Expanded(
                  child: FilledButton(
                      onPressed: _busy ? null : _confirm,
                      child: Text(_text('Confirm', 'تأكيد')))),
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

class _Header extends StatelessWidget {
  const _Header({required this.isEnglish});
  final bool isEnglish;

  @override
  Widget build(BuildContext context) {
    final text = isEnglish
        ? ('Smart Calculator', 'Offline local business assistant', 'Local only')
        : ('الحاسبة الذكية', 'مساعد أعمال محلي بدون خدمات سحابية', 'محلي فقط');
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 54, 20, 20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceFor(context),
        border: Border(bottom: BorderSide(color: AppTheme.borderFor(context))),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
                color: AppTheme.accent.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(16)),
            child: const Icon(Icons.functions, color: AppTheme.accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text.$1,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w900)),
                Text(text.$2,
                    style:
                        TextStyle(color: AppTheme.textSecondaryFor(context))),
              ],
            ),
          ),
          Chip(
              label: Text(text.$3),
              avatar: const Icon(Icons.wifi_off, size: 18)),
        ],
      ),
    );
  }
}

class _MetricStrip extends StatelessWidget {
  const _MetricStrip({required this.preview, required this.isEnglish});
  final SmartAssistantPreview preview;
  final bool isEnglish;

  @override
  Widget build(BuildContext context) {
    final values = preview.calculation.values;
    final tiles = [
      ('Total cost', 'التكلفة', values['totalCost']),
      ('Revenue', 'الإيراد', values['expectedRevenue'] ?? values['saleTotal']),
      ('Profit', 'الربح', values['expectedProfit'] ?? values['profit']),
      ('Margin', 'الهامش', values['profitMargin']),
    ].where((item) => item.$3 != null).toList();
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: tiles
          .map((item) => Container(
                width: 150,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(14),
                  border:
                      Border.all(color: AppTheme.accent.withValues(alpha: .14)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(isEnglish ? item.$1 : item.$2,
                        style: TextStyle(
                            color: AppTheme.textSecondaryFor(context),
                            fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(
                        item.$3 is num
                            ? AppFormatters.number((item.$3 as num).toDouble())
                            : item.$3.toString(),
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900)),
                  ],
                ),
              ))
          .toList(),
    );
  }
}

class _ConfidencePill extends StatelessWidget {
  const _ConfidencePill({required this.value});
  final double value;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: const Icon(Icons.speed, size: 18),
      label: Text('${(value * 100).round()}%'),
    );
  }
}

class _FieldChip extends StatelessWidget {
  const _FieldChip({required this.label, required this.value, this.onTap});
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.borderFor(context)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$label: ',
                style: TextStyle(color: AppTheme.textSecondaryFor(context))),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
            if (onTap != null)
              const Padding(
                  padding: EdgeInsetsDirectional.only(start: 6),
                  child: Icon(Icons.edit, size: 15)),
          ],
        ),
      ),
    );
  }
}
