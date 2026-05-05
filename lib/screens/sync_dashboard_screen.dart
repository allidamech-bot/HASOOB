import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
  SyncStatus? _selectedFilter;

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
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => setState(() {}),
            tooltip: 'Refresh List',
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              final service = SyncQueueService.instance;
              final messenger = ScaffoldMessenger.of(context);
              if (value == 'clear_synced') {
                await service.clearSynced();
                messenger.showSnackBar(const SnackBar(content: Text('Cleared synced operations')));
              } else if (value == 'clear_rejected') {
                await service.clearRejected();
                messenger.showSnackBar(const SnackBar(content: Text('Cleared rejected operations')));
              } else if (value == 'retry_all') {
                await service.retryAllFailed();
                messenger.showSnackBar(const SnackBar(content: Text('Retrying all failed operations')));
              } else if (value == 'clear_logs') {
                SyncLogService.instance.clear();
                messenger.showSnackBar(const SnackBar(content: Text('Logs cleared')));
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'retry_all', child: Text('Retry All Failed')),
              const PopupMenuItem(value: 'clear_synced', child: Text('Clear Synced')),
              const PopupMenuItem(value: 'clear_rejected', child: Text('Clear Rejected')),
              const PopupMenuItem(value: 'clear_logs', child: Text('Clear Logs')),
            ],
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
      bottomNavigationBar: SafeArea(
        child: Padding(
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
                label: Text(isRunning ? 'Syncing...' : 'Run Sync Now'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
              );
            },
          ),
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

            var operations = snapshot.data!;
            
            // Sort by status priority: failed, pending, conflict, processing, synced, rejected
            operations.sort((a, b) {
              final priorityMap = {
                SyncStatus.failed: 0,
                SyncStatus.pending: 1,
                SyncStatus.conflict: 2,
                SyncStatus.processing: 3,
                SyncStatus.synced: 4,
                SyncStatus.rejected: 5,
              };
              return (priorityMap[a.status] ?? 99).compareTo(priorityMap[b.status] ?? 99);
            });

            if (_selectedFilter != null) {
              operations = operations.where((op) => op.status == _selectedFilter).toList();
            }

            return Column(
              children: [
                _buildFilterBar(),
                _buildBulkActions(),
                Expanded(
                  child: operations.isEmpty
                      ? _buildEmptyState()
                      : ListView.separated(
                          padding: const EdgeInsets.all(8),
                          itemCount: operations.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final op = operations[index];
                            return _OperationCard(operation: op);
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildFilterBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: const Text('All'),
              selected: _selectedFilter == null,
              onSelected: (selected) {
                if (selected) setState(() => _selectedFilter = null);
              },
            ),
          ),
          ...SyncStatus.values.map((status) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(status.name[0].toUpperCase() + status.name.substring(1)),
                selected: _selectedFilter == status,
                onSelected: (selected) {
                  setState(() => _selectedFilter = selected ? status : null);
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildBulkActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () async {
                await SyncQueueService.instance.retryAllFailed();
                setState(() {});
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Retrying all failed operations')),
                  );
                }
              },
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry Failed'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () async {
                await SmartSyncTriggerService.instance.onUserRequestedSync();
                setState(() {});
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Manual sync triggered')),
                  );
                }
              },
              icon: const Icon(Icons.sync_rounded, size: 18),
              label: const Text('Sync Now'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_done_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _selectedFilter == null ? 'No sync activity yet' : 'No ${_selectedFilter!.name} operations',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            if (_selectedFilter == null) ...[
              const SizedBox(height: 8),
              Text(
                'Start using the app to generate sync operations',
                style: TextStyle(color: Colors.grey[500]),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLogsTab() {
    return ListenableBuilder(
      listenable: SyncLogService.instance,
      builder: (context, _) {
        final logs = SyncLogService.instance.logs;
        if (logs.isEmpty) {
          return const Center(child: Text('No logs available'));
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
                DateFormat('HH:mm:ss').format(log.timestamp),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            );
          },
        );
      },
    );
  }
}

class _OperationCard extends StatelessWidget {
  final SyncOperation operation;

  const _OperationCard({required this.operation});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: _getBorderColor(operation.status, colorScheme),
          width: operation.status == SyncStatus.failed || operation.status == SyncStatus.conflict ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showDetails(context),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _getStatusIcon(operation.status),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${operation.entityName} ${operation.type.name.toUpperCase()}',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'ID: ${operation.entityId}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  _getPriorityBadge(context, operation.priority),
                ],
              ),
              if (operation.lastError != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, size: 16, color: colorScheme.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          operation.lastError!,
                          style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onErrorContainer),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Attempts: ${operation.attemptCount}',
                    style: theme.textTheme.bodySmall,
                  ),
                  Text(
                    AppFormatters.dateTimeString(operation.updatedAt.toIso8601String()),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _getStatusIcon(SyncStatus status) {
    switch (status) {
      case SyncStatus.pending:
        return const Icon(Icons.schedule_rounded, color: Colors.orange);
      case SyncStatus.processing:
        return const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case SyncStatus.synced:
        return const Icon(Icons.check_circle_outline_rounded, color: Colors.green);
      case SyncStatus.failed:
        return const Icon(Icons.error_outline_rounded, color: Colors.red);
      case SyncStatus.rejected:
        return const Icon(Icons.block_rounded, color: Colors.grey);
      case SyncStatus.conflict:
        return const Icon(Icons.compare_arrows_rounded, color: Colors.deepOrange);
    }
  }

  Color _getBorderColor(SyncStatus status, ColorScheme scheme) {
    switch (status) {
      case SyncStatus.failed:
        return scheme.error;
      case SyncStatus.conflict:
        return Colors.orange;
      case SyncStatus.pending:
        return Colors.blue;
      case SyncStatus.processing:
        return scheme.primary;
      case SyncStatus.synced:
        return Colors.green.withValues(alpha: 0.5);
      case SyncStatus.rejected:
        return scheme.outlineVariant;
    }
  }

  Widget _getPriorityBadge(BuildContext context, int priority) {
    Color color;
    String label;
    if (priority <= 1) {
      color = Colors.red;
      label = 'High';
    } else if (priority == 2) {
      color = Colors.blue;
      label = 'Normal';
    } else {
      color = Colors.grey;
      label = 'Low';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  void _showDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _OperationDetailsSheet(operation: operation),
    );
  }
}

class _OperationDetailsSheet extends StatelessWidget {
  final SyncOperation operation;

  const _OperationDetailsSheet({required this.operation});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).padding.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Operation Details', style: theme.textTheme.headlineSmall),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(),
          _detailRow('Entity', '${operation.entityName} (${operation.entityId})'),
          _detailRow('Action', operation.type.name.toUpperCase()),
          _detailRow('Status', operation.status.name.toUpperCase()),
          _detailRow('Priority', _getPriorityLabel(operation.priority)),
          _detailRow('Created', AppFormatters.dateTimeString(operation.createdAt.toIso8601String())),
          _detailRow('Last Update', AppFormatters.dateTimeString(operation.updatedAt.toIso8601String())),
          _detailRow('Attempts', operation.attemptCount.toString()),
          if (operation.retryDelaySeconds > 0)
            _detailRow('Retry Delay', '${operation.retryDelaySeconds} seconds'),
          if (operation.conflictStrategy != SyncConflictStrategy.lastWriteWins)
            _detailRow('Conflict Strategy', operation.conflictStrategy.name),
          if (operation.remoteVersion != null)
            _detailRow('Remote Version', operation.remoteVersion.toString()),
          if (operation.lastError != null) ...[
            const SizedBox(height: 16),
            Text('Error Message', style: theme.textTheme.titleSmall?.copyWith(color: colorScheme.error)),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(operation.lastError!, style: TextStyle(color: colorScheme.onErrorContainer)),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              if (operation.status == SyncStatus.failed || operation.status == SyncStatus.conflict)
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () async {
                      await SyncQueueService.instance.retryOperation(operation.id);
                      if (context.mounted) Navigator.pop(context);
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry Now'),
                  ),
                ),
              if (operation.status != SyncStatus.processing) ...[
                if (operation.status == SyncStatus.failed || operation.status == SyncStatus.conflict)
                  const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Delete Operation?'),
                          content: const Text('This will remove the operation from the queue permanently.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        await SyncQueueService.instance.delete(operation.id);
                        if (context.mounted) Navigator.pop(context);
                      }
                    },
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Remove'),
                    style: OutlinedButton.styleFrom(foregroundColor: colorScheme.error),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  String _getPriorityLabel(int priority) {
    if (priority <= 1) return 'High';
    if (priority == 2) return 'Normal';
    return 'Low';
  }
}

