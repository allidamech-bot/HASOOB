import '../models/sync_operation.dart';

/// Abstract interface for backend communication.
/// This acts as the boundary between the sync engine and the actual cloud provider.
abstract class BackendAdapter {
  /// Sends a sync operation to the backend.
  /// Returns a [BackendResult] indicating success or failure.
  Future<BackendResult> send(SyncOperation operation);

  /// Fetches the latest version of an entity from the backend.
  Future<Map<String, dynamic>?> fetchRemoteData(String entityName, String entityId);
}

/// A no-op implementation for testing or default initialization.
class NoOpBackendAdapter implements BackendAdapter {
  @override
  Future<BackendResult> send(SyncOperation operation) async => BackendResult.success();
  @override
  Future<Map<String, dynamic>?> fetchRemoteData(String entityName, String entityId) async => null;
}

class BackendResult {
  final bool success;
  final String? error;
  final int? remoteVersion;
  final Map<String, dynamic>? data;

  BackendResult({
    required this.success,
    this.error,
    this.remoteVersion,
    this.data,
  });

  factory BackendResult.success({int? remoteVersion, Map<String, dynamic>? data}) {
    return BackendResult(success: true, remoteVersion: remoteVersion, data: data);
  }

  factory BackendResult.failure(String error) {
    return BackendResult(success: false, error: error);
  }
}
