import 'package:flutter/foundation.dart';

enum SyncLogLevel { info, warning, error }

class SyncLogEntry {
  final DateTime timestamp;
  final SyncLogLevel level;
  final String message;
  final String? details;

  SyncLogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
    this.details,
  });
}

class SyncLogService extends ChangeNotifier {
  static final instance = SyncLogService._();
  SyncLogService._();

  final List<SyncLogEntry> _logs = [];
  static const int _maxLogs = 100;

  List<SyncLogEntry> get logs => List.unmodifiable(_logs);

  void log(String message, {SyncLogLevel level = SyncLogLevel.info, String? details}) {
    final entry = SyncLogEntry(
      timestamp: DateTime.now(),
      level: level,
      message: message,
      details: details,
    );
    
    _logs.insert(0, entry);
    if (_logs.length > _maxLogs) {
      _logs.removeLast();
    }
    
    debugPrint('[Sync] [${level.name.toUpperCase()}] $message');
    notifyListeners();
  }

  void clear() {
    _logs.clear();
    notifyListeners();
  }
}
