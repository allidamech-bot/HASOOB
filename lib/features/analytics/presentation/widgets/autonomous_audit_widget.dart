import 'package:flutter/material.dart';
import '../../data/models/audit_anomaly_model.dart';
import '../../data/repositories/audit_repository_factory.dart';

class AutonomousAuditWidget extends StatefulWidget {
  const AutonomousAuditWidget({super.key});

  @override
  State<AutonomousAuditWidget> createState() => _AutonomousAuditWidgetState();
}

class _AutonomousAuditWidgetState extends State<AutonomousAuditWidget> {
  final _repository = AuditRepositoryFactory.make();
  bool _isAuditing = false;
  final Map<String, bool> _healingStates = {};

  Future<void> _handleSystemAudit() async {
    setState(() => _isAuditing = true);
    try {
      final issueCount = await _repository.triggerFullSystemAudit();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            issueCount == 0 
                ? 'اكتمل الفحص الشامل: الدفاتر والمستودعات متطابقة بنسبة 100% ولا توجد أي فجوات ماليّة!'
                : 'اكتمل الفحص: تم رصد $issueCount ثغرات أو أخطاء محاسبية بحاجة لتسوية.',
            textDirection: TextDirection.rtl,
          ),
          backgroundColor: issueCount == 0 ? const Color(0xFF0D9488) : Colors.amber[800],
        ),
      );
    } catch (_) {
      // Graceful catch
    } finally {
      if (mounted) setState(() => _isAuditing = false);
    }
  }

  Future<void> _handleSelfHealing(String anomalyId) async {
    setState(() => _healingStates[anomalyId] = true);
    try {
      final success = await _repository.resolveAnomalySelfHealing(anomalyId);
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تفعيل بروتوكول الإصلاح الذاتي (Self-Healing) وإعادة موازنة القيد بنجاح!', textDirection: TextDirection.rtl),
            backgroundColor: Color(0xFF0D9488),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('فشلت عملية التسوية التلقائية للقيد.', textDirection: TextDirection.rtl),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _healingStates[anomalyId] = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const goldAccent = Color(0xFFD4AF37); // Matte Gold
    const darkCard = Color(0xFF111827);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      textDirection: TextDirection.rtl,
      children: [
        // Header Controls Box
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: darkCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: goldAccent.withValues(alpha: 0.3), width: 1.5),
            boxShadow: [
              BoxShadow(color: goldAccent.withValues(alpha: 0.03), blurRadius: 12, spreadRadius: 1)
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            textDirection: TextDirection.rtl,
            children: [
              Row(
                textDirection: TextDirection.rtl,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    textDirection: TextDirection.rtl,
                    children: [
                      Text(
                        '🛡️ المدقق المالي المستقل (Autonomous Auditor)',
                        style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'فحص مستمر عابر للمستودعات لكشف الاختلالات والتسوية الذاتية.',
                        style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11),
                      ),
                    ],
                  ),
                  _isAuditing
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: goldAccent, strokeWidth: 2))
                      : IconButton(
                          icon: const Icon(Icons.shield_outlined, color: goldAccent),
                          tooltip: 'تشغيل فحص فوري',
                          onPressed: _handleSystemAudit,
                        ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 38,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: goldAccent,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _isAuditing ? null : _handleSystemAudit,
                  icon: const Icon(Icons.analytics_outlined, size: 16),
                  label: const Text('تشغيل فحص النظام الشامل والمطابقة الحية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              )
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Live Detected Anomalies List Stream
        const Text(
          'قضايا الاختلالات المعلقة المكتشفة حلياً:',
          style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
          textDirection: TextDirection.rtl,
        ),
        const SizedBox(height: 12),

        StreamBuilder<List<AuditAnomalyModel>>(
          stream: _repository.getDetectedAnomalies(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: Padding(padding: EdgeInsets.all(20.0), child: CircularProgressIndicator(color: goldAccent)));
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF1F2937),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF374151)),
                ),
                child: const Center(
                  child: Text(
                    '🎉 دفاتر الحسابات نظيفة ومطابقة تماماً. لا توجد قضايا معلقة.',
                    style: TextStyle(color: Color(0xFF0D9488), fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
              );
            }

            final anomalies = snapshot.data!;

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: anomalies.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = anomalies[index];
                final isHealing = _healingStates[item.id] ?? false;
                
                // Establish contextual color coding matching severity levels
                Color severityColor;
                String severityLabel;
                if (item.severity == 'high') {
                  severityColor = Colors.redAccent;
                  severityLabel = 'حرجة جداً';
                } else if (item.severity == 'medium') {
                  severityColor = Colors.amber;
                  severityLabel = 'متوسطة الخطورة';
                } else {
                  severityColor = Colors.blueAccent;
                  severityLabel = 'تنبيه منخفض';
                }

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1F2937),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: severityColor.withValues(alpha: 0.3), width: 1.2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    textDirection: TextDirection.rtl,
                    children: [
                      Row(
                        textDirection: TextDirection.rtl,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                              textDirection: TextDirection.rtl,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: severityColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: severityColor, width: 0.8),
                            ),
                            child: Text(
                              severityLabel,
                              style: TextStyle(color: severityColor, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.description,
                        style: const TextStyle(color: Color(0xFFD1D5DB), fontSize: 12, height: 1.4),
                        textDirection: TextDirection.rtl,
                      ),
                      
                      // Suggested autonomous fix banner
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF111827),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF374151)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          textDirection: TextDirection.rtl,
                          children: [
                            const Text(
                              '💡 مقترح المعالجة الذاتية (Self-Healing Proposal):',
                              style: TextStyle(color: goldAccent, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.suggestedFix,
                              style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      
                      // Execute Healing Core Action Button
                      SizedBox(
                        width: double.infinity,
                        height: 38,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0D9488),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          onPressed: isHealing ? null : () => _handleSelfHealing(item.id),
                          icon: isHealing
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.build_circle_outlined, size: 16),
                          label: const Text('اعتماد التسوية وتصحيح الدفاتر تلقائياً', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      )
                    ],
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}
