import '../../data/database/database_helper.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'branch_context.dart';

class AuditService {
  static final AuditService _instance = AuditService._internal();
  factory AuditService() => _instance;
  AuditService._internal();

  Future<void> log({
    required String businessId,
    required String entityType,
    required String entityId,
    required String action,
    String? oldValue,
    String? newValue,
  }) async {
    try {
      final db = await DBHelper.database();
      final user = FirebaseAuth.instance.currentUser;
      final branchId = BranchContext().currentBranchId;

      await db.insert('audit_logs', {
        'id': 'AUD-${DateTime.now().microsecondsSinceEpoch}',
        'businessId': businessId,
        'branch_id': branchId,
        'actorUserId': user?.uid ?? 'unknown',
        'entityType': entityType,
        'entityId': entityId,
        'action': action,
        'oldValue': oldValue,
        'newValue': newValue,
        'timestamp': DateTime.now().toIso8601String(),
      });
      
      // Note: In Phase 21C, we should also queue this for sync.
      // For now, we focus on local persistence.
    } catch (e) {
      debugPrint('Audit logging failed: $e');
    }
  }
}
