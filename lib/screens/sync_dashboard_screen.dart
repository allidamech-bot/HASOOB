import 'package:flutter/material.dart';
import '../data/services/sync_manager.dart';
import '../data/services/sync_queue_service.dart';
import '../data/services/smart_sync_trigger_service.dart';
import '../data/services/sync_log_service.dart';
import '../data/models/sync_operation.dart';
import '../core/app_formatters.dart';

class SyncDashboardScreen extends StatefulWidget {
  const SyncDashboardScreen({super.key});

  @override
  State<SyncDashboardScreen> createState() => _SyncDashboardScreenState();
}

class _SyncDashboardScreenState extends State<SyncDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync Dashboard'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Queue', icon: Icon(Icons.list_alt_rounded)),
            Tab(text: 'Logs', icon: Icon(Icons.history_rounded)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded),
            onPressed: () async {
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              if (_tabController.index == 0) {
                await SyncQueueService.instance.clearSynced();
              } else {
                SyncLogService.instance.clear();
              }
              scaffoldMessenger.showSnackBar(
                const SnackBar(content: Text('Cleared')),
              );
            },
            tooltip: 'Clear',
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildQueueTab(),
          _buildLogsTab(),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListenableBuilder(
          listenable: SyncManager.instance,
          builder: (context, _) {
            final isRunning = SyncManager.instance.isRunning;
            return FilledButton.icon(
              onPressed: isRunning
                  ? null
                  : () => SmartSyncTriggerService.instance.onUserRequestedSync(),
              icon: isRunning
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.sync_rounded),
              label: Text(isRunning ? 'Syncing...' : 'Run Sync'),
            );
          },
        ),
      ),
    );
  }

  Widget _buildQueueTab() {
    return ListenableBuilder(
      listenable: SyncManager.instance,
      builder: (context, _) {
        return FutureBuilder<List<SyncOperation>>(
          future: SyncQueueService.instance.getAll(),
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
                  subtitle: Text(
                    op.status == SyncStatus.failed
                        ? 'Error: ${op.lastError ?? "Unknown"}'
                        : 'Status: ${op.status.name}',
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(AppFormatters.dateTimeString(
                          op.updatedAt.toIso8601String())),
                      if (op.attemptCount > 0)
                        Text('Retries: ${op.attemptCount}',
                            style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildLogsTab() {
    return ListenableBuilder(
      listenable: SyncLogService.instance,
      builder: (context, _) {
        final logs = SyncLogService.instance.logs;
        if (logs.isEmpty) {
          return const Center(child: Text('No logs yet'));
        }

        return ListView.builder(
          itemCount: logs.length,
          itemBuilder: (context, index) {
            final log = logs[index];
            return ListTile(
              dense: true,
              leading: Icon(
                log.level == SyncLogLevel.error
                    ? Icons.error_outline_rounded
                    : log.level == SyncLogLevel.warning
                        ? Icons.warning_amber_rounded
                        : Icons.info_outline_rounded,
                color: log.level == SyncLogLevel.error
                    ? Colors.red
                    : log.level == SyncLogLevel.warning
                        ? Colors.orange
                        : Colors.blue,
              ),
              title: Text(log.message),
              subtitle: log.details != null ? Text(log.details!) : null,
              trailing: Text(
                '${log.timestamp.hour}:${log.timestamp.minute.toString().padLeft(2, '0')}:${log.timestamp.second.toString().padLeft(2, '0')}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            );
          },
        );
      },
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
