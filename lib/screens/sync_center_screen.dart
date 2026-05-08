import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/services/sync_manager.dart';
import '../data/services/sync_queue_service.dart';
import '../data/services/smart_sync_trigger_service.dart';
import '../data/services/sync_log_service.dart';
import '../data/models/sync_operation.dart';
import '../data/repositories/sync_queue_repository.dart';
import '../core/app_formatters.dart';
import '../core/app_copy.dart';
import '../core/app_theme.dart';
import '../core/services/connectivity_service.dart';

class SyncCenterScreen extends StatefulWidget {
  const SyncCenterScreen({super.key});

  @override
  State<SyncCenterScreen> createState() => _SyncCenterScreenState();
}

class _SyncCenterScreenState extends State<SyncCenterScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final SyncQueueRepository _repository = SyncQueueRepository();

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
    final copy = AppCopy.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(copy.t('syncCenter')),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: copy.t('syncQueueTitle'), icon: const Icon(Icons.queue_rounded)),
            Tab(text: copy.t('syncTimelineTitle'), icon: const Icon(Icons.history_rounded)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => setState(() {}),
            tooltip: 'Refresh',
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              final service = SyncQueueService.instance;
              if (value == 'clear_synced') {
                await service.clearSynced();
                setState(() {});
              } else if (value == 'retry_all') {
                await service.retryAllFailed();
                setState(() {});
              } else if (value == 'clear_logs') {
                SyncLogService.instance.clear();
                setState(() {});
              }
            },
            itemBuilder: (context) => [
            PopupMenuItem(value: 'retry_all', child: Text(copy.t('syncRetryAll'))),
            PopupMenuItem(value: 'clear_synced', child: Text(copy.t('syncClearSynced'))),
            const PopupMenuItem(value: 'clear_logs', child: Text('Clear Logs')),
          ],
        ),
      ],
    ),
    body: ListenableBuilder(
      listenable: SyncManager.instance,
      builder: (context, _) {
        return FutureBuilder<Map<String, dynamic>>(
          future: _repository.getSyncStats(),
          builder: (context, snapshot) {
            final stats = snapshot.data ?? {
              'pending': 0,
              'failed': 0,
              'conflicts': 0,
              'syncedToday': 0,
              'lastSyncTime': null,
            };

            return Column(
              children: [
                _buildHeaderStats(context, copy, stats),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildQueueTab(context, copy),
                      _buildTimelineTab(context, copy),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    ),
    bottomNavigationBar: _buildBottomActions(context, copy),
  );
}

Widget _buildHeaderStats(BuildContext context, AppCopy copy, Map<String, dynamic> stats) {
  return Container(
    padding: const EdgeInsets.all(16),
    color: AppTheme.surfaceAltFor(context),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _statCard(context, copy.t('syncStatsPending'), stats['pending'].toString(), Colors.blue),
            const SizedBox(width: 8),
            _statCard(context, copy.t('syncStatsFailed'), stats['failed'].toString(), AppTheme.danger),
            const SizedBox(width: 8),
            _statCard(context, copy.t('syncStatsSyncedToday'), stats['syncedToday'].toString(), AppTheme.success),
            const SizedBox(width: 8),
            _statCard(context, copy.t('syncStatsConflicts'), stats['conflicts'].toString(), Colors.orange),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              stats['lastSyncTime'] != null
                  ? copy.t('syncLastSync').replaceFirst('{time}', AppFormatters.dateTimeString(stats['lastSyncTime']))
                  : copy.t('syncNeverSynced'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            _ConnectivityIndicator(copy: copy),
          ],
        ),
      ],
    ),
  );
}

  Widget _statCard(BuildContext context, String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: color.withValues(alpha: 0.8),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQueueTab(BuildContext context, AppCopy copy) {
    return FutureBuilder<List<SyncOperation>>(
      future: SyncQueueService.instance.getAll(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final operations = snapshot.data!;
        if (operations.isEmpty) return _buildEmptyState(context, copy);

        // Group by entity type
        final grouped = <String, List<SyncOperation>>{};
        for (final op in operations) {
          grouped.putIfAbsent(op.entityName, () => []).add(op);
        }

        final sortedGroups = grouped.keys.toList()..sort();

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: sortedGroups.length,
          itemBuilder: (context, index) {
            final entityName = sortedGroups[index];
            final ops = grouped[entityName]!;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                  child: Text(
                    entityName.toUpperCase(),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textSecondaryFor(context),
                          letterSpacing: 1.2,
                        ),
                  ),
                ),
                ...ops.map((op) => _OperationItem(operation: op, onRefresh: () => setState(() {}))),
                const SizedBox(height: 16),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildTimelineTab(BuildContext context, AppCopy copy) {
    return ListenableBuilder(
      listenable: SyncLogService.instance,
      builder: (context, _) {
        final logs = SyncLogService.instance.logs;
        if (logs.isEmpty) return _buildEmptyState(context, copy);

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: logs.length,
          itemBuilder: (context, index) {
            final log = logs[index];
            final isLast = index == logs.length - 1;

            return IntrinsicHeight(
              child: Row(
                children: [
                  Column(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: _getLogLevelColor(log.level),
                          shape: BoxShape.circle,
                        ),
                      ),
                      if (!isLast)
                        Expanded(
                          child: Container(
                            width: 2,
                            color: AppTheme.borderFor(context),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                DateFormat('HH:mm:ss').format(log.timestamp),
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: _getLogLevelColor(log.level),
                                    ),
                              ),
                              if (log.level == SyncLogLevel.error)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: const BoxDecoration(
                                    color: Color(0x1AD32F2F), // Manual fallback for AppTheme.danger.withValues(alpha: 0.1)
                                    borderRadius: BorderRadius.all(Radius.circular(4)),
                                  ),
                                  child: const Text(
                                    'ERROR',
                                    style: TextStyle(
                                      color: Color(0xFFD32F2F), // Manual fallback for AppTheme.danger
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            log.message,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          if (log.details != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              log.details!,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Color _getLogLevelColor(SyncLogLevel level) {
    switch (level) {
      case SyncLogLevel.error:
        return AppTheme.danger;
      case SyncLogLevel.warning:
        return Colors.orange;
      case SyncLogLevel.info:
        return Colors.blue;
    }
  }

  Widget _buildEmptyState(BuildContext context, AppCopy copy) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_done_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'Everything in sync',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions(BuildContext context, AppCopy copy) {
    return SafeArea(
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
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.sync_rounded),
              label: Text(isRunning ? copy.t('syncRunning') : copy.t('syncNow')),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ConnectivityIndicator extends StatelessWidget {
  final AppCopy copy;
  const _ConnectivityIndicator({required this.copy});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ConnectivityService.instance,
      builder: (context, _) {
        final isOnline = ConnectivityService.instance.isOnline;
        return Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: isOnline ? AppTheme.success : AppTheme.danger,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              isOnline ? copy.t('syncOnline') : copy.t('syncOffline'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isOnline ? AppTheme.success : AppTheme.danger,
                  ),
            ),
          ],
        );
      },
    );
  }
}

class _OperationItem extends StatelessWidget {
  final SyncOperation operation;
  final VoidCallback onRefresh;

  const _OperationItem({required this.operation, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final copy = AppCopy.of(context);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.borderFor(context)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: _getStatusIcon(operation.status),
        title: Text(
          '${operation.type.name.toUpperCase()} ${operation.entityId}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              copy.t('syncRetryCount').replaceFirst('{count}', operation.attemptCount.toString()),
              style: theme.textTheme.bodySmall,
            ),
            if (operation.lastError != null)
              Text(
                operation.lastError!,
                style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.danger),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.more_vert_rounded),
          onPressed: () => _showDetails(context),
        ),
      ),
    );
  }

  Widget _getStatusIcon(SyncStatus status) {
    switch (status) {
      case SyncStatus.pending:
        return const Icon(Icons.schedule_rounded, color: Colors.blue);
      case SyncStatus.processing:
        return const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2));
      case SyncStatus.synced:
        return const Icon(Icons.check_circle_outline_rounded, color: AppTheme.success);
      case SyncStatus.failed:
        return const Icon(Icons.error_outline_rounded, color: AppTheme.danger);
      case SyncStatus.rejected:
        return const Icon(Icons.block_rounded, color: Colors.grey);
      case SyncStatus.conflict:
        return const Icon(Icons.compare_arrows_rounded, color: Colors.orange);
    }
  }

  void _showDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => _OperationDetailsSheet(operation: operation, onActionCompleted: onRefresh),
    );
  }
}

class _OperationDetailsSheet extends StatelessWidget {
  final SyncOperation operation;
  final VoidCallback onActionCompleted;

  const _OperationDetailsSheet({required this.operation, required this.onActionCompleted});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final copy = AppCopy.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).padding.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(copy.t('syncOperationDetails'), style: theme.textTheme.headlineSmall),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const Divider(),
          _detailRow(copy.t('syncEntityType'), operation.entityName),
          _detailRow(copy.t('syncOpType'), operation.type.name.toUpperCase()),
          _detailRow(copy.t('status'), operation.status.name.toUpperCase()),
          _detailRow(copy.t('syncCreated'), AppFormatters.dateTimeString(operation.createdAt.toIso8601String())),
          _detailRow(copy.t('syncLastAttempt'), AppFormatters.dateTimeString(operation.updatedAt.toIso8601String())),
          _detailRow(copy.t('syncRetryCount').split(':')[0], operation.attemptCount.toString()),
          if (operation.lastError != null) ...[
            const SizedBox(height: 16),
            Text('Error', style: theme.textTheme.titleSmall?.copyWith(color: AppTheme.danger)),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Color(0x1AD32F2F), // Manual fallback for AppTheme.danger.withValues(alpha: 0.1)
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
              child: Text(operation.lastError!, style: const TextStyle(color: Color(0xFFD32F2F))),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              if (operation.status == SyncStatus.failed || operation.status == SyncStatus.conflict)
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () async {
                      final navigator = Navigator.of(context);
                      await SyncQueueService.instance.retryOperation(operation.id);
                      onActionCompleted();
                      navigator.pop();
                    },
                    icon: const Icon(Icons.refresh),
                    label: Text(copy.t('syncOperationRetry')),
                  ),
                ),
              if (operation.status != SyncStatus.processing) ...[
                if (operation.status == SyncStatus.failed || operation.status == SyncStatus.conflict)
                  const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final navigator = Navigator.of(context);
                      await SyncQueueService.instance.delete(operation.id);
                      onActionCompleted();
                      navigator.pop();
                    },
                    icon: const Icon(Icons.delete_outline),
                    label: Text(copy.t('syncOperationRemove')),
                    style: OutlinedButton.styleFrom(foregroundColor: AppTheme.danger),
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
}
