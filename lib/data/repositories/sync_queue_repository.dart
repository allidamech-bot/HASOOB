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
      orderBy: 'createdAt ASC',
    );

    return maps.map((map) => _fromDbMap(map)).toList();
  }

  Future<List<SyncOperation>> getAllOperations() async {
    final db = await DBHelper.database();
    final List<Map<String, dynamic>> maps = await db.query(
      tableName,
      orderBy: 'createdAt ASC',
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
