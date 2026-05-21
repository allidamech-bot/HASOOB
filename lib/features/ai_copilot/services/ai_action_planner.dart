import '../models/ai_action_draft.dart';

class AiActionPlanner {
  // Uses simple keyword matching for foundation phase without external AI calls
  Future<AiActionDraft?> parseActionFromText({
    required String text,
    required String threadId,
    required String businessId,
    required String userId,
  }) async {
    final lowerText = text.toLowerCase();
    String? actionType;
    String? title;

    if (lowerText.contains('add product') || lowerText.contains('اضافة منتج') || lowerText.contains('إضافة منتج')) {
      actionType = 'add_product';
      title = 'Add Product Draft';
    } else if (lowerText.contains('sale') || lowerText.contains('بيع') || lowerText.contains('فاتورة')) {
      actionType = 'record_sale';
      title = 'Record Sale Draft';
    } else if (lowerText.contains('customer') || lowerText.contains('عميل')) {
      actionType = 'add_customer';
      title = 'Add Customer Draft';
    } else if (lowerText.contains('payment') || lowerText.contains('دفعة')) {
      actionType = 'record_payment';
      title = 'Record Payment Draft';
    } else if (lowerText.contains('invoice')) {
      actionType = 'create_invoice';
      title = 'Create Invoice Draft';
    } else {
      // Generic draft fallback if intent is somewhat detected
      if (text.length > 10) {
        actionType = 'generic';
        title = 'Business Request Draft';
      } else {
        return null;
      }
    }

    final now = DateTime.now();
    final uniqueId = 'draft_${now.microsecondsSinceEpoch}';
    return AiActionDraft(
      id: uniqueId,
      threadId: threadId,
      businessId: businessId,
      userId: userId,
      actionType: actionType,
      title: title,
      summary: 'I understood this as a business request. Please review before any action.',
      status: 'draft',
      createdAt: now,
      updatedAt: now,
    );
  }
}
