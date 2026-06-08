import 'dart:async';
import 'dart:typed_data';
import '../../domain/repositories/ai_accountant_repository.dart';
import '../models/ai_proposal_model.dart';

class MockAiAccountantRepository implements AiAccountantRepository {
  @override
  Future<AiProposalModel> parseNaturalLanguage(String text) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return AiProposalModel(
      actionType: 'purchase',
      explanation: 'قيد تجريبي للنص: $text',
      confidenceScore: 0.95,
    );
  }

  @override
  Future<AiProposalModel> parseInvoiceImage(Uint8List imageBytes, String mimeType) async {
    await Future.delayed(const Duration(milliseconds: 1200)); // Simulate deep OCR analysis
    
    return AiProposalModel(
      actionType: 'purchase',
      explanation: 'تم فحص المستند ضوئياً: فاتورة توريد مواد خام مستخرجة آلياً من الصورة المرفوعة.',
      confidenceScore: 0.94,
      inventoryPayload: {
        'name': 'مواد ومستلزمات إنتاج مستخرجة',
        'quantity': 250,
        'costPrice': 45.0,
        'currency': 'USD',
        'sku': 'OCR-SUPPLY-MOCK'
      },
      customerPayload: {
        'name': 'مصنع المورد الإقليمي المشترك',
        'city': 'إسطنبول'
      },
      financialPayload: {
        'totalAmount': 11250.0,
        'amountPaid': 0.0,
        'isFullyPaid': false,
      }
    );
  }

  @override
  Future<bool> executeProposal(AiProposalModel proposal) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return true;
  }
}
