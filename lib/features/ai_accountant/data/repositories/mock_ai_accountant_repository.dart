import 'dart:async';
import '../../domain/repositories/ai_accountant_repository.dart';
import '../models/ai_proposal_model.dart';

class MockAiAccountantRepository implements AiAccountantRepository {
  @override
  Future<AiProposalModel> parseNaturalLanguage(String text) async {
    await Future.delayed(const Duration(milliseconds: 600));
    
    if (text.contains('شراء') || text.contains('اشتريت')) {
      return AiProposalModel(
        actionType: 'purchase',
        explanation: 'تم تحليل النص: عملية شراء وتوريد بضاعة للمستودع المالي من مورد جهة اتصال.',
        confidenceScore: 0.98,
        inventoryPayload: {
          'name': 'حاسوب محمول عالي الأداء Pro',
          'quantity': 15,
          'costPrice': 3200.0,
          'currency': 'SAR',
          'sku': 'AI-LAP-PRO'
        },
        customerPayload: {
          'name': 'مؤسسة ميم للاستيراد والتوريد',
          'city': 'الرياض'
        },
        financialPayload: {
          'totalAmount': 48000.0,
          'amountPaid': 48000.0,
          'isFullyPaid': true,
        }
      );
    } else if (text.contains('بيع') || text.contains('بعت')) {
      return AiProposalModel(
        actionType: 'sale',
        explanation: 'تم تحليل النص: إصدار فاتورة مبيعات جديدة لعميل مع ترحيل قيم التخفيض المخزني.',
        confidenceScore: 0.96,
        inventoryPayload: {
          'name': 'حاسوب محمول عالي الأداء Pro',
          'quantity': -2, // Decrement stock on sale
          'costPrice': 4000.0,
          'currency': 'SAR',
          'sku': 'AI-LAP-PRO'
        },
        customerPayload: {
          'name': 'مؤسسة أحمد التجارية',
          'city': 'الرياض'
        },
        financialPayload: {
          'totalAmount': 8000.0,
          'amountPaid': 4000.0,
          'isFullyPaid': false,
        }
      );
    }

    return AiProposalModel(
      actionType: 'unknown',
      explanation: 'لم يتمكن المحرك الذكي من استخراج قيود محاسبية مهيكلة متوازنة، يرجى إعادة صياغة النص بوضوح أكثر (مثال: اشتريت/بعت مادة كذا بقيمة كذا).',
      confidenceScore: 0.35,
    );
  }

  @override
  Future<bool> executeProposal(AiProposalModel proposal) async {
    await Future.delayed(const Duration(milliseconds: 500));
    // Simulate global success across mock data state boundaries
    return true;
  }
}
