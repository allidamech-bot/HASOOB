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
    final db = await DBHelper.database();
    final List<Map<String, dynamic>> maps = await db.query(
      tableName,
      where: 'status = ?',
      whereArgs: [SyncStatus.pending.name],
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
