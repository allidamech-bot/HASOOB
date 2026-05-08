import 'package:flutter/material.dart';
import '../data/services/sync_manager.dart';
import '../data/services/sync_queue_service.dart';
import '../data/models/sync_operation.dart';
import '../core/app_theme.dart';
import '../core/services/connectivity_service.dart';

class SyncStatusIndicator extends StatelessWidget {
  const SyncStatusIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ConnectivityService.instance,
      builder: (context, _) {
        final isOnline = ConnectivityService.instance.isOnline;

        if (!isOnline) {
          return IconButton(
            icon: const Icon(Icons.cloud_off_rounded, color: AppTheme.danger),
            onPressed: () => Navigator.pushNamed(context, '/sync'),
            tooltip: 'Offline',
          );
        }

        return ListenableBuilder(
          listenable: SyncManager.instance,
          builder: (context, _) {
            return FutureBuilder<List<SyncOperation>>(
              future: SyncQueueService.instance.getPending(),
              builder: (context, snapshot) {
                final pendingItems = snapshot.data ?? [];
                final hasFailed = pendingItems.any((item) => 
                  item.status == SyncStatus.failed || item.status == SyncStatus.conflict);
                final isRunning = SyncManager.instance.isRunning;
                final hasPending = pendingItems.isNotEmpty;

                Color color;
                IconData icon;
                String tooltip;

                if (hasFailed) {
                  color = AppTheme.danger;
                  icon = Icons.sync_problem_rounded;
                  tooltip = 'Sync Failed';
                } else if (isRunning) {
                  color = Colors.orange;
                  icon = Icons.sync_rounded;
                  tooltip = 'Syncing...';
                } else if (hasPending) {
                  color = Colors.blue;
                  icon = Icons.sync_rounded;
                  tooltip = 'Pending Operations';
                } else {
                  color = AppTheme.success;
                  icon = Icons.cloud_done_rounded;
                  tooltip = 'Synced';
                }

                return IconButton(
                  icon: Icon(icon, color: color),
                  onPressed: () => Navigator.pushNamed(context, '/sync'),
                  tooltip: tooltip,
                );
              },
            );
          },
        );
      },
    );
  }
}
