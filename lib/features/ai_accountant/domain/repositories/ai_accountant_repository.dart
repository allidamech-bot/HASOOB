import 'dart:typed_data';
import '../../data/models/ai_proposal_model.dart';

abstract class AiAccountantRepository {
  /// يستقبل النص الطبيعي ويقوم بتحليله وتفكيكه برمجياً إلى مقترح معاملة مهيكل
  Future<AiProposalModel> parseNaturalLanguage(String text);
  
  /// يستقبل بايتات صورة الفاتورة أو المستند ويقوم بفك شفرتها وتحليلها عبر المحرك متعدد الوسائط
  Future<AiProposalModel> parseInvoiceImage(Uint8List imageBytes, String mimeType);
  
  /// يقوم بتعميد وترحيل المقترح لتحديث مستودعات (المخزون، العملاء، والمالية) دفعة واحدة
  Future<bool> executeProposal(AiProposalModel proposal);
}
