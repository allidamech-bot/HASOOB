import 'package:flutter/material.dart';
import '../data/services/sync_manager.dart';
import '../data/services/sync_queue_service.dart';
import '../data/models/sync_operation.dart';
import '../core/app_formatters.dart';

class SyncDashboardScreen extends StatefulWidget {
  const SyncDashboardScreen({super.key});

  @override
  State<SyncDashboardScreen> createState() => _SyncDashboardScreenState();
}

class _SyncDashboardScreenState extends State<SyncDashboardScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync Dashboard'),
      ),
      body: ListenableBuilder(
        listenable: SyncManager.instance,
        builder: (context, _) {
          return FutureBuilder<List<SyncOperation>>(
            future: SyncQueueService.instance.getPending(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final operations = snapshot.data!;
              if (operations.isEmpty) {
                return const Center(child: Text('All operations synced'));
              }

              return ListView.builder(
                itemCount: operations.length,
                itemBuilder: (context, index) {
                  final op = operations[index];
                  return ListTile(
                    leading: _getStatusIcon(op.status),
                    title: Text('${op.entityName} - ${op.type.name}'),
                    subtitle: Text(op.lastError ?? 'Pending sync'),
                    trailing: Text(AppFormatters.dateTimeString(op.updatedAt.toIso8601String())),
                  );
                },
              );
            },
          );
        },
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListenableBuilder(
          listenable: SyncManager.instance,
          builder: (context, _) {
            final isRunning = SyncManager.instance.isRunning;
            return FilledButton.icon(
              onPressed: isRunning ? null : () => SyncManager.instance.runSync(),
              icon: isRunning
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.sync_rounded),
              label: Text(isRunning ? 'Syncing...' : 'Run Sync'),
            );
          },
        ),
      ),
    );
  }

  Widget _getStatusIcon(SyncStatus status) {
    switch (status) {
      case SyncStatus.pending:
        return const Icon(Icons.hourglass_empty_rounded, color: Colors.orange);
      case SyncStatus.processing:
        return const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case SyncStatus.synced:
        return const Icon(Icons.check_circle_rounded, color: Colors.green);
      case SyncStatus.failed:
        return const Icon(Icons.error_rounded, color: Colors.red);
    }
  }
}
