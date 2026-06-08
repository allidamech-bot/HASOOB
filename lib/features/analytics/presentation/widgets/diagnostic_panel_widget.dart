import 'package:flutter/material.dart';
import '../../data/repositories/system_integration_tester.dart';

class DiagnosticPanelWidget extends StatefulWidget {
  const DiagnosticPanelWidget({super.key});

  @override
  State<DiagnosticPanelWidget> createState() => _DiagnosticPanelWidgetState();
}

class _DiagnosticPanelWidgetState extends State<DiagnosticPanelWidget> {
  final _tester = SystemIntegrationTester();
  
  bool _isRunningTests = false;
  String _aiStatus = 'بانتظار الفحص';
  String _logisticsStatus = 'بانتظار الفحص';
  String _auditStatus = 'بانتظار الفحص';
  
  Color _aiColor = Colors.grey;
  Color _logisticsColor = Colors.grey;
  Color _auditColor = Colors.grey;

  Future<void> _executeComprehensiveSuite() async {
    setState(() {
      _isRunningTests = true;
      _aiStatus = 'جاري مراجعة العقل السحابي والـ JSON...';
      _logisticsStatus = 'جاري مراجعة الحدود الحجمية للـ CBM...';
      _auditStatus = 'جاري حقن واختبار التوازن الذري...';
      _aiColor = Colors.amber;
      _logisticsColor = Colors.amber;
      _auditColor = Colors.amber;
    });

    // 1. Run AI Parser Test
    final aiPassed = await _tester.testAiParserResilience();
    if (!mounted) return;
    setState(() {
      _aiStatus = aiPassed ? '✅ ناجح: عقود وتمريرات الـ JSON مهيكلة ومحمية تماماً.' : '❌ فاشل: يوجد خلل في تفسير الاستجابة.';
      _aiColor = aiPassed ? const Color(0xFF0D9488) : Colors.redAccent;
    });

    // 2. Run Volumetric Test
    final logisticsPassed = await _tester.testLogisticsVolumeBoundaries();
    setState(() {
      _logisticsStatus = logisticsPassed ? '✅ ناجح: محاكي الـ 20ft آمن ضد أخطاء القسمة على صفر.' : '❌ فاشل: الخوارزمية المحاسبية انهارت عند الحدود الحرجة.';
      _logisticsColor = logisticsPassed ? const Color(0xFF0D9488) : Colors.redAccent;
    });

    // 3. Run Self-Healing Loop Test
    final auditPassed = await _tester.testSelfHealingAuditLoop();
    setState(() {
      _auditStatus = auditPassed ? '✅ ناجح: المعاملات الذرية وحقن بروتوكول الإصلاح متزنة 100%.' : '❌ فاشل: فشل ترحيل الـ Batch السريع.';
    });

    setState(() {
      _auditColor = auditPassed ? const Color(0xFF0D9488) : Colors.redAccent;
      _isRunningTests = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    const darkBg = Color(0xFF111827);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: darkBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        textDirection: TextDirection.rtl,
        children: [
          const Row(
            textDirection: TextDirection.rtl,
            children: [
              Icon(Icons.gavel_rounded, color: Colors.redAccent, size: 22),
              SizedBox(width: 8),
              Text(
                'منصة الفحص الجذري واختبار الجاهزية (360° QA Matrix)',
                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'محاكاة إنتاجية مكثفة لاختبار صمود المنظومة ضد الاختناقات وأخطاء البيانات المتطرفة حياً.',
            style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11),
          ),
          const Divider(color: Color(0xFF374151), height: 32),

          // Diagnostic Row 1: AI
          _buildDiagnosticResult('طبقة مفسر الذكاء الاصطناعي (AI Layer):', _aiStatus, _aiColor),
          const SizedBox(height: 14),
          
          // Diagnostic Row 2: Logistics
          _buildDiagnosticResult('محرك الحاويات اللوجستي (Landed Cost):', _logisticsStatus, _logisticsColor),
          const SizedBox(height: 14),

          // Diagnostic Row 3: Audit Daemon
          _buildDiagnosticResult('درع الحماية والإصلاح الذاتي (Self-Healing):', _auditStatus, _auditColor),
          
          const Divider(color: Color(0xFF374151), height: 32),

          SizedBox(
            height: 42,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _isRunningTests ? const Color(0xFF374151) : Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _isRunningTests ? null : _executeComprehensiveSuite,
              icon: _isRunningTests 
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.play_circle_filled_rounded, size: 18),
              label: const Text('إطلاق هجوم الاختراق البرمي وفحص الأطراف الآن', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildDiagnosticResult(String title, String status, Color statusColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      textDirection: TextDirection.rtl,
      children: [
        Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Row(
          textDirection: TextDirection.rtl,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(shape: BoxShape.circle, color: statusColor),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                status,
                style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold),
                textDirection: TextDirection.rtl,
              ),
            ),
          ],
        )
      ],
    );
  }
}
