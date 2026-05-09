import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class ConnectivityService extends ChangeNotifier {
  static final ConnectivityService instance = ConnectivityService._();
  ConnectivityService._();

  final Connectivity _connectivity = Connectivity();
  bool _isOnline = true;
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  bool get isOnline => _isOnline;

  Future<void> initialize() async {
    try {
      final result = await _connectivity.checkConnectivity();
      debugPrint('[Connectivity] Initial check type: ${result.runtimeType}');
      _updateStatus(result);

      _subscription = _connectivity.onConnectivityChanged.listen((dynamic data) {
        debugPrint('[Connectivity] Stream emitted type: ${data.runtimeType}');
        _updateStatus(data);
      });
    } catch (e) {
      debugPrint('[Connectivity] Initialization error: $e');
    }
  }

  void _updateStatus(dynamic data) {
    List<ConnectivityResult> results = [];
    
    if (data is List<ConnectivityResult>) {
      results = data;
    } else if (data is List) {
      // Handle generic list if generic type is lost
      results = data.whereType<ConnectivityResult>().toList();
    } else if (data is ConnectivityResult) {
      results = [data];
    }

    // Basic logic: if any result is NOT none, we consider it "online"
    final isOnline = results.any((r) => r != ConnectivityResult.none) && results.isNotEmpty;
    
    debugPrint('[Connectivity] Normalized results: $results -> isOnline: $isOnline');

    if (_isOnline != isOnline) {
      _isOnline = isOnline;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
