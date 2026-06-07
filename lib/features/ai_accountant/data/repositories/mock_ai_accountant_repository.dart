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
        explanation: 'مقترح إضافة مخزون وتوثيق توريد بضاعة بناءً على مدخلاتك.',
        confidenceScore: 0.95,
        inventoryPayload: {
          'name': 'شوكولاتة فاخرة - كرتون التوريد',
          'quantity': 50,
          'costPrice': 180.0,
          'currency': 'SAR',
          'sku': 'MOCK-AI-SKU'
        },
        customerPayload: {
          'name': 'شركة التوريد العالمية',
          'city': 'جدة'
        },
        financialPayload: {
          'totalAmount': 9000.0,
          'amountPaid': 9000.0,
          'isFullyPaid': true,
        }
      );
    }

    return AiProposalModel(
      actionType: 'unknown',
      explanation: 'لم يتمكن المحرك الذكي من تحديد طبيعة العملية المحاسبية بدقة، يرجى المحاولة بصياغة أخرى.',
      confidenceScore: 0.30,
    );
  }

  @override
  Future<bool> executeProposal(AiProposalModel proposal) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return true;
  }
}
