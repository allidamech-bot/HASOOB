import 'package:flutter/foundation.dart';
import '../../../../data/database/database_helper.dart';
import '../models/ai_cfo_session_model.dart';

/// Safe non-ledger repository for AI CFO session reports / archive.
///
/// Reads and writes ONLY to the isolated [ai_cfo_sessions] table.
/// This table does NOT affect any accounting ledger, trial balance,
/// inventory, customer balances, or financial statements.
class AiCfoSessionRepository {
  static const _table = 'ai_cfo_sessions';

  /// Save a new AI CFO session report to the local archive.
  /// Returns the saved session id.
  Future<String> saveSession(AiCfoSessionModel session) async {
    try {
      final db = await DBHelper.database();
      await db.insert(_table, session.toMap());
      return session.id;
    } catch (e) {
      debugPrint('[AiCfoSessionRepository] saveSession error: $e');
      rethrow;
    }
  }

  /// Load all saved AI CFO sessions for a business, newest first.
  Future<List<AiCfoSessionModel>> getSessions(String businessId) async {
    try {
      final db = await DBHelper.database();
      final rows = await db.query(
        _table,
        where: 'businessId = ?',
        whereArgs: [businessId],
        orderBy: 'createdAt DESC',
      );
      return rows.map(AiCfoSessionModel.fromMap).toList();
    } catch (e) {
      debugPrint('[AiCfoSessionRepository] getSessions error: $e');
      return const [];
    }
  }

  /// Load a single session by id.
  Future<AiCfoSessionModel?> getSession(String id) async {
    try {
      final db = await DBHelper.database();
      final rows = await db.query(
        _table,
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return AiCfoSessionModel.fromMap(rows.first);
    } catch (e) {
      debugPrint('[AiCfoSessionRepository] getSession error: $e');
      return null;
    }
  }

  /// Delete a saved session by id.
  Future<void> deleteSession(String id) async {
    try {
      final db = await DBHelper.database();
      await db.delete(_table, where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      debugPrint('[AiCfoSessionRepository] deleteSession error: $e');
    }
  }
}
