import '../../data/models/audit_anomaly_model.dart';

abstract class AuditRepository {
  /// جلب قائمة بجميع الشذوذ والأخطاء المالية المكتشفة في الدفاتر الحالية
  Stream<List<AuditAnomalyModel>> getDetectedAnomalies();
  
  /// تنفيذ أمر الإصلاح التلقائي الذكي المقترح لتسوية الخلل المحاسبي
  Future<bool> resolveAnomalySelfHealing(String anomalyId);
  
  /// تشغيل فحص يدوي مكثف عابر لجميع المستودعات والمطابقات الحية
  Future<int> triggerFullSystemAudit();
}
