import 'package:flutter/foundation.dart';
import '../../../ai_accountant/data/repositories/ai_accountant_repository_factory.dart';
import '../../../shipping_logistics/data/repositories/logistics_repository_factory.dart';
import '../../data/repositories/audit_repository_factory.dart';

class SystemIntegrationTester {
  final _aiRepository = AiAccountantRepositoryFactory.make();
  final _logisticsRepository = LogisticsRepositoryFactory.make();
  final _auditRepository = AuditRepositoryFactory.make();

  /// 1. فحص صلابة مفسر النصوص والـ JSON لـ Gemini
  Future<bool> testAiParserResilience() async {
    try {
      // ضخ عبارة معقدة ومزيج من العامية والفصحى والأرقام لمعاينة جودة التفكيك
      const sampleText = "اشترينا بضاعة مكسرة نكهات علك متنوعة للحاوية بقيمة 4500.75 دولار وشحنها بـ 1200 من مؤسسة ميم";
      final proposal = await _aiRepository.parseNaturalLanguage(sampleText);
      
      // التحقق من المطابقة الصارمة للأنواع وعدم الانهيار
      if (proposal.actionType != 'purchase') return false;
      if (proposal.confidenceScore <= 0.0) return false;
      return true;
    } catch (e) {
      debugPrint('❌ QA TEST FAILED: AI Parser Resilience: $e');
      return false;
    }
  }

  /// 2. فحص محاكي الحاويات والحدود الحجمية (Boundary Limit Testing)
  Future<bool> testLogisticsVolumeBoundaries() async {
    try {
      // ضخ أرقام متطرفة (صفر أو قيم سالبة أو شحنات ضخمة) للتحقق من عدم انهيار المحرك الرياضي
      final zeroVolumeResult = await _logisticsRepository.calculateLandedCostPerUnit(
        itemBasePrice: 10.0,
        itemVolumeCbm: 0.1,
        totalShippingCost: 3500.0,
        totalCustomsDuties: 1200.0,
        totalBatchVolumeCbm: 0.0, // حد حرج: حجم الدفعة صفر
      );
      
      // يجب أن يعود السعر الأساسي للمنتج دون انهيار بالقسمة على صفر
      if (zeroVolumeResult != 10.0) return false;

      // محاكاة سعة حاوية 20 قدم العادية ببيانات مدخلة
      final simulation = await _logisticsRepository.simulateContainerLoad(
        productQuantities: {'TEST-SKU': 50},
        containerType: '20ft',
        shippingCost: 3000,
        customsDuties: 1500,
      );
      
      if (simulation.totalVolumeCbm != 33.2) return false;
      return true;
    } catch (e) {
      debugPrint('❌ QA TEST FAILED: Logistics Volumetric Boundaries: $e');
      return false;
    }
  }

  /// 3. فحص المعاملات الذرية وحلقة الموازنة التلقائية (Self-Healing Loop verification)
  Future<bool> testSelfHealingAuditLoop() async {
    try {
      // فحص جلب واجهة تقارير الاختلالات الحية
      await _auditRepository.triggerFullSystemAudit();
      
      // محاكاة إصلاح ذاتي لمعاملة وهمية للتأكد من سلامة كتل الـ Batch والتسوية
      final success = await _auditRepository.resolveAnomalySelfHealing('ANOMALY-001');
      return success;
    } catch (e) {
      debugPrint('❌ QA TEST FAILED: Self Healing Loop Logic: $e');
      return false;
    }
  }
}
