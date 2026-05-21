import 'package:sqflite/sqflite.dart';
import '../../../data/database/database_helper.dart';
import '../models/ai_thread.dart';
import '../models/ai_message.dart';
import '../models/ai_memory_item.dart';
import '../models/ai_action_draft.dart';
import '../models/ai_action_log.dart';

class AiCopilotRepository {
  Future<Database> get _db async => await DBHelper.database();

  Future<void> createThread(AiThread thread) async {
    final db = await _db;
    await db.insert('ai_threads', thread.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<AiThread>> getThreads(String businessId) async {
    final db = await _db;
    final maps = await db.query(
      'ai_threads',
      where: 'businessId = ?',
      whereArgs: [businessId],
      orderBy: 'updatedAt DESC',
    );
    return maps.map((map) => AiThread.fromMap(map)).toList();
  }

  Future<AiThread?> getThreadById(String id) async {
    final db = await _db;
    final maps = await db.query(
      'ai_threads',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return AiThread.fromMap(maps.first);
    }
    return null;
  }

  Future<void> saveMessage(AiMessage message) async {
    final db = await _db;
    await db.insert('ai_messages', message.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<AiMessage>> getMessages(String threadId) async {
    final db = await _db;
    final maps = await db.query(
      'ai_messages',
      where: 'threadId = ?',
      whereArgs: [threadId],
      orderBy: 'createdAt ASC',
    );
    return maps.map((map) => AiMessage.fromMap(map)).toList();
  }

  Future<void> saveMemoryItem(AiMemoryItem item) async {
    final db = await _db;
    await db.insert('ai_memory_items', item.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<AiMemoryItem>> getMemoryItems(String businessId) async {
    final db = await _db;
    final maps = await db.query(
      'ai_memory_items',
      where: 'businessId = ?',
      whereArgs: [businessId],
    );
    return maps.map((map) => AiMemoryItem.fromMap(map)).toList();
  }

  Future<void> saveActionDraft(AiActionDraft draft) async {
    final db = await _db;
    await db.insert('ai_action_drafts', draft.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<AiActionDraft>> getActionDrafts(String businessId) async {
    final db = await _db;
    final maps = await db.query(
      'ai_action_drafts',
      where: 'businessId = ?',
      whereArgs: [businessId],
      orderBy: 'createdAt DESC',
    );
    return maps.map((map) => AiActionDraft.fromMap(map)).toList();
  }

  Future<void> updateActionDraftStatus(String id, String status) async {
    final db = await _db;
    await db.update(
      'ai_action_drafts',
      {
        'status': status,
        'updatedAt': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> saveActionLog(AiActionLog log) async {
    final db = await _db;
    await db.insert('ai_action_logs', log.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<AiActionLog>> getActionLogs(String draftId) async {
    final db = await _db;
    final maps = await db.query(
      'ai_action_logs',
      where: 'draftId = ?',
      whereArgs: [draftId],
      orderBy: 'createdAt ASC',
    );
    return maps.map((map) => AiActionLog.fromMap(map)).toList();
  }
}
