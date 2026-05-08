import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../models/sync_operation.dart';

class SyncQueueRepository {
  static const String tableName = 'sync_operations';

  Future<void> enqueue(SyncOperation operation) async {
    final db = await DBHelper.database();
    await db.insert(
      tableName,
      _toDbMap(operation),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<SyncOperation>> getPendingOperations() async {
    return getOperationsByStatus([SyncStatus.pending]);
  }

  Future<List<SyncOperation>> getOperationsByStatus(List<SyncStatus> statuses) async {
    final db = await DBHelper.database();
    final statusNames = statuses.map((s) => s.name).toList();
    final placeholders = List.filled(statusNames.length, '?').join(', ');
    
    final List<Map<String, dynamic>> maps = await db.query(
      tableName,
      where: 'status IN ($placeholders)',
      whereArgs: statusNames,
      orderBy: 'priority ASC, createdAt ASC',
    );

    return maps.map((map) => _fromDbMap(map)).toList();
  }

  Future<SyncOperation?> getPendingOperationByEntity(String entityName, String entityId) async {
    final db = await DBHelper.database();
    final List<Map<String, dynamic>> maps = await db.query(
      tableName,
      where: 'entityName = ? AND entityId = ? AND (status = ? OR status = ?)',
      whereArgs: [entityName, entityId, SyncStatus.pending.name, SyncStatus.failed.name],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return _fromDbMap(maps.first);
  }

  Future<SyncOperation?> getOperationByFingerprint(String fingerprint) async {
    final db = await DBHelper.database();
    final List<Map<String, dynamic>> maps = await db.query(
      tableName,
      where: 'fingerprint = ?',
      whereArgs: [fingerprint],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return _fromDbMap(maps.first);
  }

  Future<List<SyncOperation>> getAllOperations() async {
    final db = await DBHelper.database();
    final List<Map<String, dynamic>> maps = await db.query(
      tableName,
      orderBy: 'priority ASC, createdAt ASC',
    );

    return maps.map((map) => _fromDbMap(map)).toList();
  }

  Future<void> updateOperation(SyncOperation operation) async {
    final db = await DBHelper.database();
    await db.update(
      tableName,
      _toDbMap(operation),
      where: 'id = ?',
      whereArgs: [operation.id],
    );
  }

  Future<void> deleteOperation(String id) async {
    final db = await DBHelper.database();
    await db.delete(
      tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> clearAll() async {
    final db = await DBHelper.database();
    await db.delete(tableName);
  }

  Future<void> clearSynced() async {
    final db = await DBHelper.database();
    await db.delete(
      tableName,
      where: 'status = ?',
      whereArgs: [SyncStatus.synced.name],
    );
  }

  Future<Map<String, dynamic>> getSyncStats() async {
    final db = await DBHelper.database();
    
    final List<Map<String, dynamic>> pendingCount = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $tableName WHERE status = ?',
      [SyncStatus.pending.name],
    );
    
    final List<Map<String, dynamic>> failedCount = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $tableName WHERE status = ? OR status = ?',
      [SyncStatus.failed.name, SyncStatus.conflict.name],
    );
    
    final List<Map<String, dynamic>> conflictCount = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $tableName WHERE status = ?',
      [SyncStatus.conflict.name],
    );

    final today = DateTime.now().toIso8601String().substring(0, 10);
    final List<Map<String, dynamic>> syncedTodayCount = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $tableName WHERE status = ? AND updatedAt LIKE ?',
      [SyncStatus.synced.name, '$today%'],
    );

    final List<Map<String, dynamic>> lastSync = await db.rawQuery(
      'SELECT updatedAt FROM $tableName WHERE status = ? ORDER BY updatedAt DESC LIMIT 1',
      [SyncStatus.synced.name],
    );

    return {
      'pending': pendingCount.first['count'] as int? ?? 0,
      'failed': failedCount.first['count'] as int? ?? 0,
      'conflicts': conflictCount.first['count'] as int? ?? 0,
      'syncedToday': syncedTodayCount.first['count'] as int? ?? 0,
      'lastSyncTime': lastSync.isNotEmpty ? lastSync.first['updatedAt'] as String : null,
    };
  }

  Map<String, dynamic> _toDbMap(SyncOperation operation) {
    final map = operation.toMap();
    // Encode payload as JSON string for SQLite
    map['payload'] = jsonEncode(map['payload']);
    return map;
  }

  SyncOperation _fromDbMap(Map<String, dynamic> map) {
    final mutableMap = Map<String, dynamic>.from(map);
    // Decode payload from JSON string
    mutableMap['payload'] = jsonDecode(mutableMap['payload'] as String);
    return SyncOperation.fromMap(mutableMap);
  }
}
