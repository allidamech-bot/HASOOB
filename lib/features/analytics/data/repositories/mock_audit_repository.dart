import 'dart:async';
import '../../domain/repositories/audit_repository.dart';
import '../models/audit_anomaly_model.dart';

class MockAuditRepository implements AuditRepository {
  final _controller = StreamController<List<AuditAnomalyModel>>.broadcast();
  final List<AuditAnomalyModel> _mockAnomalies = [
    AuditAnomalyModel(
      id: 'ANOMALY-001',
      title: 'عدم تطابق في تسوية فاتورة المبيعات',
      description: 'تم إصدار الفاتورة رقم INV-AI-992 بقيمة 8,000 ر.س ولكن مجموع المبالغ المحصلة والآجلة المسجلة لا يتطابق مع القيد المزدوج المعتمد.',
      severity: 'high',
      affectedModule: 'invoices',
      detectedAt: DateTime.now().subtract(const Duration(hours: 2)),
      suggestedFix: 'إعادة موازنة القيد وترحيل مبلغ 4,000 ر.س كقيمة مستحقة غير مدفوعة في حساب العميل بشكل تلقائي.',
    ),
    AuditAnomalyModel(
      id: 'ANOMALY-002',
      title: 'شذوذ في تكلفة هوامش ربح المخزون',
      description: 'تم رصد انخفاض مفاجئ في هامش ربح المنتج "شوكولاتة فاخرة" بنسبة 35% نتيجة إدخال تكلفة شحن جمركية غير متناسبة خطياً.',
      severity: 'medium',
      affectedModule: 'inventory',
      detectedAt: DateTime.now().subtract(const Duration(days: 1)),
      suggestedFix: 'تفعيل محرك الـ Landed Cost لإعادة توزيع مصاريف الحاوية بناءً على الأوزان والحجم الفعلي التلقائي.',
    )
  ];

  @override
  Stream<List<AuditAnomalyModel>> getDetectedAnomalies() {
    Timer(const Duration(milliseconds: 200), () => _controller.add(_mockAnomalies));
    return _controller.stream;
  }

  @override
  Future<bool> resolveAnomalySelfHealing(String anomalyId) async {
    await Future.delayed(const Duration(milliseconds: 400));
    _mockAnomalies.removeWhere((item) => item.id == anomalyId);
    _controller.add(_mockAnomalies);
    return true;
  }

  @override
  Future<int> triggerFullSystemAudit() async {
    await Future.delayed(const Duration(milliseconds: 600));
    return _mockAnomalies.length;
  }
}
