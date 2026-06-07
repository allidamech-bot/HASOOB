import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/repositories/ai_accountant_repository.dart';
import '../models/ai_proposal_model.dart';

class FirestoreAiAccountantRepository implements AiAccountantRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Future<AiProposalModel> parseNaturalLanguage(String text) async {
    await Future.delayed(const Duration(milliseconds: 400));
    // Fallback logic representing structural routing contract
    return AiProposalModel(
      actionType: 'unknown',
      explanation: 'قناة الاتصال المباشر لـ Gemini Core بانتظار مفتاح التحقق السحابي لمعالجة النص: $text',
      confidenceScore: 0.40,
    );
  }

  @override
  Future<bool> executeProposal(AiProposalModel proposal) async {
    final batch = _firestore.batch();
    
    // 1. Audit Logging for Traceability
    final logRef = _firestore.collection('ai_ledger_logs').doc();
    batch.set(logRef, {
      'timestamp': FieldValue.serverTimestamp(),
      'proposal': proposal.toMap(),
      'status': 'committed'
    });
    
    // 2. Atomic Cross-Module Interception: Inventory Module Update
    if (proposal.inventoryPayload != null) {
      final invData = proposal.inventoryPayload!;
      final sku = invData['sku'] ?? 'AI-GEN-SKU';
      final invRef = _firestore.collection('inventory').doc(sku);
      
      batch.set(invRef, {
        'name': invData['name'],
        'sku': sku,
        'quantity': FieldValue.increment(invData['quantity'] ?? 0),
        'costPrice': invData['costPrice'],
        'currency': invData['currency'] ?? 'SAR',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    
    // 3. Atomic Cross-Module Interception: Customers Module Update
    if (proposal.customerPayload != null) {
      final custData = proposal.customerPayload!;
      final custName = custData['name'] ?? 'عميل آلي غير محدد';
      final custRef = _firestore.collection('customers').doc(custName);
      
      batch.set(custRef, {
        'name': custName,
        'city': custData['city'] ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    // 4. Atomic Cross-Module Interception: Collection Center (Invoices) Update
    if (proposal.financialPayload != null) {
      final finData = proposal.financialPayload!;
      final invRef = _firestore.collection('invoices').doc();
      
      batch.set(invRef, {
        'invoiceNumber': 'INV-AI-${DateTime.now().millisecondsSinceEpoch}',
        'totalAmount': finData['totalAmount'],
        'amountPaid': finData['amountPaid'],
        'isFullyPaid': finData['isFullyPaid'] ?? false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    
    // Commit all mutations as a single transaction ledger block
    await batch.commit();
    return true;
  }
}
