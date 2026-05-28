import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:hasoob_app/core/app_theme.dart';
import 'package:hasoob_app/core/business/business_context.dart';
import 'package:hasoob_app/core/utils/perf_logger.dart';
import 'package:hasoob_app/data/services/reports/report_models.dart';
import 'package:hasoob_app/data/services/reports/report_service.dart';

class CockpitDashboardScreen extends StatefulWidget {
  const CockpitDashboardScreen({super.key});

  @override
  State<CockpitDashboardScreen> createState() => _CockpitDashboardScreenState();
}

class _CockpitDashboardScreenState extends State<CockpitDashboardScreen> {
  final ReportService _reportService = const ReportService();
  ReportsSnapshot _data = ReportsSnapshot.empty();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    PerfLogger.logPageOpen('CockpitDashboard');
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    try {
      final snapshot = await _reportService
          .buildSnapshot(
            businessId: BusinessContext.businessId,
            forceRefresh: true,
          )
          .timeout(const Duration(seconds: 10));
      if (!mounted) return;
      setState(() {
        _data = snapshot;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _data = ReportsSnapshot.empty();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.aiDeep,
      body: RefreshIndicator(
        color: AppTheme.aiGold,
        backgroundColor: AppTheme.aiCard,
        onRefresh: _loadData,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 950;
            final maxWidth = math.min(constraints.maxWidth, 1480.0);

            return Stack(
              children: [
                const _CockpitBackground(),
                SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    isDesktop ? 28 : 16,
                    isDesktop ? 22 : 14,
                    isDesktop ? 28 : 16,
                    isDesktop ? 48 : 110,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxWidth),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _CockpitTopBar(isLoading: _isLoading),
                          const SizedBox(height: 18),
                          _HeroDeck(isDesktop: isDesktop),
                          const SizedBox(height: 18),
                          _StrategicBand(data: _data, isDesktop: isDesktop),
                          const SizedBox(height: 18),
                          _KpiGrid(data: _data, isDesktop: isDesktop),
                          const SizedBox(height: 18),
                          _DecisionLayer(data: _data, isDesktop: isDesktop),
                          const SizedBox(height: 18),
                          _OperationsLayer(data: _data, isDesktop: isDesktop),
                          const SizedBox(height: 18),
                          _QuickActionStrip(isDesktop: isDesktop),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CockpitBackground extends StatelessWidget {
  const _CockpitBackground();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              Color(0xFF050711),
              Color(0xFF080B14),
              Color(0xFF02040A),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.aiGold.withValues(alpha: 0.06),
              blurRadius: 80,
              spreadRadius: 18,
              offset: const Offset(80, -80),
            ),
            BoxShadow(
              color: AppTheme.aiBlue.withValues(alpha: 0.05),
              blurRadius: 90,
              spreadRadius: 20,
              offset: const Offset(-70, 80),
            ),
          ],
        ),
      ),
    );
  }
}

class _CockpitTopBar extends StatelessWidget {
  const _CockpitTopBar({required this.isLoading});

  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _MiniTool(icon: Icons.logout_rounded, color: AppTheme.aiRed.withValues(alpha: 0.85)),
        const SizedBox(width: 8),
        _MiniTool(icon: Icons.settings_rounded, color: AppTheme.aiGold),
        const SizedBox(width: 8),
        _MiniTool(icon: Icons.apartment_rounded, color: AppTheme.aiBlue),
        const Spacer(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Text(
              'لوحة القيادة والذكاء المالي',
              style: TextStyle(
                color: AppTheme.aiGold,
                fontSize: 19,
                fontWeight: FontWeight.w900,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: AppTheme.aiGreen,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  isLoading ? 'يتم تحديث القراءة المالية...' : 'جلسة ذكاء مالي نشطة',
                  style: const TextStyle(
                    color: AppTheme.aiTextSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _MiniTool extends StatelessWidget {
  const _MiniTool({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFF0F1629).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }
}

class _HeroDeck extends StatelessWidget {
  const _HeroDeck({required this.isDesktop});

  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _StatusChip(
          label: 'المستشار المالي نشط',
          color: AppTheme.aiGold,
          icon: Icons.auto_awesome_rounded,
        ),
        const SizedBox(height: 18),
        Text(
          'ما القرار المالي الأفضل اليوم؟',
          textAlign: TextAlign.right,
          style: TextStyle(
            color: AppTheme.aiTextPrimary,
            fontSize: isDesktop ? 34 : 25,
            fontWeight: FontWeight.w900,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'يحلل المستشار المالي التدفق النقدي، الفواتير، المخزون والمصروفات ليقترح أفضل خطوة الآن.',
          textAlign: TextAlign.right,
          style: TextStyle(
            color: AppTheme.aiTextSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            height: 1.65,
          ),
        ),
        const SizedBox(height: 22),
        const Align(
          alignment: Alignment.centerRight,
          child: _GoldButton(label: 'عرض ملخص اليوم', icon: Icons.summarize_rounded),
        ),
      ],
    );

    return _GlassPanel(
      padding: EdgeInsets.all(isDesktop ? 28 : 20),
      borderColor: AppTheme.aiGold.withValues(alpha: 0.38),
      glowColor: AppTheme.aiGold,
      child: isDesktop
          ? SizedBox(
              height: 245,
              child: Row(
                children: [
                  const Expanded(flex: 5, child: _PremiumRobotVisual()),
                  const SizedBox(width: 30),
                  Expanded(flex: 6, child: text),
                ],
              ),
            )
          : Column(
              children: [
                const SizedBox(height: 190, child: _PremiumRobotVisual()),
                const SizedBox(height: 18),
                text,
              ],
            ),
    );
  }
}

class _PremiumRobotVisual extends StatefulWidget {
  const _PremiumRobotVisual();

  @override
  State<_PremiumRobotVisual> createState() => _PremiumRobotVisualState();
}

class _PremiumRobotVisualState extends State<_PremiumRobotVisual>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          painter: _RobotPainter(progress: _controller.value),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _RobotPainter extends CustomPainter {
  const _RobotPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.49);
    final radius = math.min(size.width, size.height) * 0.42;

    final blue = Paint()
      ..color = AppTheme.aiBlue.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final gold = Paint()
      ..color = AppTheme.aiGold.withValues(alpha: 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;

    for (int i = 0; i < 4; i++) {
      final shift = progress * math.pi * 2 + i * 0.7;
      final rect = Rect.fromCircle(center: center, radius: radius * (0.62 + i * 0.13));
      canvas.drawArc(rect, shift, math.pi * 1.25, false, i.isEven ? gold : blue);
    }

    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          AppTheme.aiBlue.withValues(alpha: 0.24),
          AppTheme.aiGold.withValues(alpha: 0.13),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 1.25));
    canvas.drawCircle(center, radius * 1.2, glowPaint);

    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: center.translate(0, radius * 0.08),
        width: radius * 1.5,
        height: radius * 0.92,
      ),
      Radius.circular(radius * 0.22),
    );
    final bodyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF182238), Color(0xFF090C17), Color(0xFF202638)],
      ).createShader(bodyRect.outerRect);
    canvas.drawRRect(bodyRect, bodyPaint);
    canvas.drawRRect(
      bodyRect,
      Paint()
        ..color = AppTheme.aiGold.withValues(alpha: 0.48)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3,
    );

    final headRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: center.translate(0, -radius * 0.12),
        width: radius * 1.18,
        height: radius * 0.53,
      ),
      Radius.circular(radius * 0.19),
    );
    canvas.drawRRect(
      headRect,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF111B30), Color(0xFF03050B)],
        ).createShader(headRect.outerRect),
    );
    canvas.drawRRect(
      headRect,
      Paint()
        ..color = AppTheme.aiBlue.withValues(alpha: 0.72)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );

    final visorRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: center.translate(0, -radius * 0.12),
        width: radius * 0.8,
        height: radius * 0.24,
      ),
      Radius.circular(radius * 0.12),
    );
    canvas.drawRRect(
      visorRect,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF071D29), Color(0xFF000000)],
        ).createShader(visorRect.outerRect),
    );

    for (final dx in [-radius * 0.22, radius * 0.22]) {
      final eye = center.translate(dx, -radius * 0.12);
      canvas.drawCircle(
        eye,
        radius * 0.075,
        Paint()..color = AppTheme.aiBlue.withValues(alpha: 0.95),
      );
      canvas.drawCircle(
        eye,
        radius * 0.16,
        Paint()
          ..shader = RadialGradient(
            colors: [AppTheme.aiBlue.withValues(alpha: 0.35), Colors.transparent],
          ).createShader(Rect.fromCircle(center: eye, radius: radius * 0.18)),
      );
    }

    final antennaTop = center.translate(0, -radius * 0.8);
    canvas.drawLine(
      center.translate(0, -radius * 0.4),
      antennaTop,
      Paint()
        ..color = AppTheme.aiBlue.withValues(alpha: 0.68)
        ..strokeWidth = 2,
    );
    canvas.drawCircle(antennaTop, 6, Paint()..color = AppTheme.aiGold);

    final pulseAngle = progress * math.pi * 2;
    canvas.drawCircle(
      center.translate(math.cos(pulseAngle) * radius * 0.95, math.sin(pulseAngle) * radius * 0.72),
      4,
      Paint()..color = AppTheme.aiGold.withValues(alpha: 0.85),
    );
  }

  @override
  bool shouldRepaint(covariant _RobotPainter oldDelegate) => oldDelegate.progress != progress;
}

class _StrategicBand extends StatelessWidget {
  const _StrategicBand({required this.data, required this.isDesktop});

  final ReportsSnapshot data;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final health = _healthScore(data);
    final recommendation = data.totalSales <= 0
        ? 'ابدأ بتسجيل أول فاتورة أو عملية بيع حتى يظهر التحليل المالي الحقيقي.'
        : 'حافظ على التدفق النقدي الحالي وراجع المصروفات المرتفعة قبل نهاية اليوم.';

    final healthCard = _GlassPanel(
      child: Row(
        children: [
          _CircularScore(score: health),
          const SizedBox(width: 18),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('مؤشر الصحة المالية', style: _titleStyle),
                SizedBox(height: 8),
                Text(
                  'قراءة مركبة للسيولة، المخزون، الربحية وانتظام العمليات.',
                  textAlign: TextAlign.right,
                  style: _mutedStyle,
                ),
              ],
            ),
          ),
        ],
      ),
    );

    final recommendationCard = _GlassPanel(
      borderColor: AppTheme.aiBlue.withValues(alpha: 0.32),
      glowColor: AppTheme.aiBlue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Text('ماذا يجب أن أفعل اليوم؟', style: _titleStyle),
          const SizedBox(height: 12),
          _AdviceRow(icon: Icons.lightbulb_rounded, text: recommendation, color: AppTheme.aiGold),
          const SizedBox(height: 10),
          const _AdviceRow(
            icon: Icons.receipt_long_rounded,
            text: 'حوّل الفواتير غير المدفوعة إلى قائمة متابعة يومية.',
            color: AppTheme.aiBlue,
          ),
        ],
      ),
    );

    if (!isDesktop) {
      return Column(children: [healthCard, const SizedBox(height: 14), recommendationCard]);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: recommendationCard),
        const SizedBox(width: 16),
        Expanded(child: healthCard),
      ],
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.data, required this.isDesktop});

  final ReportsSnapshot data;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _KpiCard(title: 'إجمالي الأصناف', value: '${data.totalProducts}', icon: Icons.inventory_2_rounded, color: AppTheme.aiBlue),
      _KpiCard(title: 'إجمالي المبيعات', value: _money(data.totalSales), icon: Icons.receipt_long_rounded, color: AppTheme.aiGold),
      _KpiCard(title: 'الربح المتوقع', value: _money(data.netProfitEstimate), icon: Icons.trending_up_rounded, color: AppTheme.aiGreen),
      _KpiCard(title: 'مخزون منخفض', value: '${data.lowStockItems.length}', icon: Icons.warning_amber_rounded, color: AppTheme.aiRed),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final gap = isDesktop ? 14.0 : 12.0;
        final count = isDesktop ? 4 : 2;
        final width = (constraints.maxWidth - gap * (count - 1)) / count;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: cards.map((card) => SizedBox(width: width, child: card)).toList(),
        );
      },
    );
  }
}

class _DecisionLayer extends StatelessWidget {
  const _DecisionLayer({required this.data, required this.isDesktop});

  final ReportsSnapshot data;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final simulation = _GlassPanel(
      borderColor: AppTheme.aiGold.withValues(alpha: 0.25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Text('محاكاة القرار', style: _titleStyle),
          const SizedBox(height: 12),
          _DecisionTile(label: 'تحصيل دفعة عاجلة', value: '+ ${_money(8500)}', color: AppTheme.aiGreen),
          _DecisionTile(label: 'خفض مصروفات تشغيلية', value: '+ ${_money(3200)}', color: AppTheme.aiGold),
          _DecisionTile(label: 'تأجيل شراء غير ضروري', value: '+ ${_money(2100)}', color: AppTheme.aiBlue),
        ],
      ),
    );

    final pulse = _GlassPanel(
      borderColor: AppTheme.aiGreen.withValues(alpha: 0.24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Text('نبض التدفق النقدي', style: _titleStyle),
          const SizedBox(height: 14),
          _PulseLine(label: 'الداخل المتوقع', value: math.max(data.totalSales, 14200), color: AppTheme.aiGreen),
          const SizedBox(height: 12),
          _PulseLine(label: 'الخارج والمصروفات', value: math.max(data.netProfitEstimate.abs(), 5400), color: AppTheme.aiGold),
        ],
      ),
    );

    if (!isDesktop) return Column(children: [simulation, const SizedBox(height: 14), pulse]);
    return Row(children: [Expanded(child: simulation), const SizedBox(width: 16), Expanded(child: pulse)]);
  }
}

class _OperationsLayer extends StatelessWidget {
  const _OperationsLayer({required this.data, required this.isDesktop});

  final ReportsSnapshot data;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    const obligations = _GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text('الالتزامات القادمة', style: _titleStyle),
          SizedBox(height: 12),
          _TimelineRow(title: 'مراجعة فواتير الموردين', date: 'غدًا', amount: '3,400 ر.س'),
          _TimelineRow(title: 'رواتب ومصروفات تشغيل', date: 'بعد 3 أيام', amount: '12,000 ر.س'),
        ],
      ),
    );

    const alerts = _GlassPanel(
      borderColor: Color(0x66D4AF37),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text('تنبيهات ذكية', style: _titleStyle),
          SizedBox(height: 12),
          _AdviceRow(icon: Icons.warning_rounded, text: 'نسبة المخزون منخفضة في بعض الأصناف، راجع الحد الأدنى.', color: AppTheme.aiGold),
          SizedBox(height: 10),
          _AdviceRow(icon: Icons.shield_rounded, text: 'قاعدة البيانات تعمل محليًا، تأكد من اكتمال المزامنة.', color: AppTheme.aiGreen),
        ],
      ),
    );

    if (!isDesktop) return const Column(children: [obligations, SizedBox(height: 14), alerts]);
    return const Row(children: [Expanded(child: alerts), SizedBox(width: 16), Expanded(child: obligations)]);
  }
}

class _QuickActionStrip extends StatelessWidget {
  const _QuickActionStrip({required this.isDesktop});

  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    const actions = [
      _QuickAction(icon: Icons.receipt_long_rounded, label: 'إنشاء فاتورة'),
      _QuickAction(icon: Icons.person_add_alt_1_rounded, label: 'إضافة عميل'),
      _QuickAction(icon: Icons.inventory_2_rounded, label: 'إضافة صنف'),
      _QuickAction(icon: Icons.account_balance_wallet_rounded, label: 'تسجيل مصروف'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Text('إجراءات سريعة', style: _titleStyle),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final count = isDesktop ? 4 : 2;
            const gap = 12.0;
            final width = (constraints.maxWidth - gap * (count - 1)) / count;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: actions.map((a) => SizedBox(width: width, child: a)).toList(),
            );
          },
        ),
      ],
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.borderColor,
    this.glowColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;
  final Color? glowColor;

  @override
  Widget build(BuildContext context) {
    final glow = glowColor ?? AppTheme.aiBlue;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: const Color(0xFF0F1629).withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor ?? AppTheme.aiCardBorder.withValues(alpha: 0.95)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.38), blurRadius: 28, offset: const Offset(0, 16)),
          BoxShadow(color: glow.withValues(alpha: 0.08), blurRadius: 38, spreadRadius: 1),
        ],
      ),
      child: child,
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color, required this.icon});
  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 7),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 12)),
        ],
      ),
    );
  }
}

class _GoldButton extends StatelessWidget {
  const _GoldButton({required this.label, required this.icon});
  final String label;
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        gradient: AppTheme.aiGoldGradient,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: AppTheme.aiGold.withValues(alpha: 0.28), blurRadius: 18, offset: const Offset(0, 8))],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: Colors.black, size: 18),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900)),
      ]),
    );
  }
}

class _CircularScore extends StatelessWidget {
  const _CircularScore({required this.score});
  final int score;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 92,
      height: 92,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: score / 100,
            strokeWidth: 8,
            backgroundColor: AppTheme.aiCardBorder,
            valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.aiGreen),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$score', style: const TextStyle(color: AppTheme.aiGreen, fontSize: 24, fontWeight: FontWeight.w900)),
              const Text('من 100', style: TextStyle(color: AppTheme.aiTextSecondary, fontSize: 10, fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.title, required this.value, required this.icon, required this.color});
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      borderColor: color.withValues(alpha: 0.22),
      glowColor: color,
      child: SizedBox(
        height: 132,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: color, size: 20),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(value, style: const TextStyle(color: AppTheme.aiTextPrimary, fontSize: 24, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(title, textAlign: TextAlign.right, style: const TextStyle(color: AppTheme.aiTextSecondary, fontSize: 12, fontWeight: FontWeight.w700)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AdviceRow extends StatelessWidget {
  const _AdviceRow({required this.icon, required this.text, required this.color});
  final IconData icon;
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Row(
      textDirection: TextDirection.rtl,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(11)),
          child: Icon(icon, color: color, size: 17),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(text, textAlign: TextAlign.right, style: const TextStyle(color: AppTheme.aiTextPrimary, fontSize: 13, fontWeight: FontWeight.w700, height: 1.55))),
      ],
    );
  }
}

class _DecisionTile extends StatelessWidget {
  const _DecisionTile({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(children: [
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w900)),
        const Spacer(),
        Text(label, style: const TextStyle(color: AppTheme.aiTextPrimary, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

class _PulseLine extends StatelessWidget {
  const _PulseLine({required this.label, required this.value, required this.color});
  final String label;
  final double value;
  final Color color;
  @override
  Widget build(BuildContext context) {
    final ratio = (value / 20000).clamp(0.1, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(children: [
          Text(_money(value), style: TextStyle(color: color, fontWeight: FontWeight.w900)),
          const Spacer(),
          Text(label, style: const TextStyle(color: AppTheme.aiTextSecondary, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(value: ratio, minHeight: 7, color: color, backgroundColor: AppTheme.aiCardBorder),
        ),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.title, required this.date, required this.amount});
  final String title;
  final String date;
  final String amount;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Text(amount, style: const TextStyle(color: AppTheme.aiTextPrimary, fontWeight: FontWeight.w900)),
          const SizedBox(width: 12),
          Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppTheme.aiGold, shape: BoxShape.circle)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(title, style: const TextStyle(color: AppTheme.aiTextPrimary, fontWeight: FontWeight.w800)),
            Text(date, style: const TextStyle(color: AppTheme.aiGold, fontSize: 11, fontWeight: FontWeight.w800)),
          ])),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      borderColor: AppTheme.aiGold.withValues(alpha: 0.2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppTheme.aiGold, size: 20),
          const SizedBox(width: 10),
          Flexible(child: Text(label, style: const TextStyle(color: AppTheme.aiTextPrimary, fontWeight: FontWeight.w900), overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}

const _titleStyle = TextStyle(color: AppTheme.aiTextPrimary, fontSize: 17, fontWeight: FontWeight.w900);
const _mutedStyle = TextStyle(color: AppTheme.aiTextSecondary, fontSize: 12, fontWeight: FontWeight.w600, height: 1.55);

int _healthScore(ReportsSnapshot data) {
  final stock = data.totalProducts > 0 ? 28 : 12;
  final sales = data.totalSales > 0 ? 25 : 10;
  final profit = data.netProfitEstimate >= 0 ? 22 : 8;
  final balance = data.trialBalanceSummary.isBalanced ? 23 : 8;
  return (stock + sales + profit + balance).clamp(42, 94);
}

String _money(num value) {
  final rounded = value.round();
  final sign = rounded < 0 ? '-' : '';
  final digits = rounded.abs().toString();
  final buffer = StringBuffer();
  for (int i = 0; i < digits.length; i++) {
    final indexFromEnd = digits.length - i;
    buffer.write(digits[i]);
    if (indexFromEnd > 1 && indexFromEnd % 3 == 1) buffer.write(',');
  }
  return '$sign${buffer.toString()} ر.س';
}
