import 'package:flutter/material.dart';
import '../data/services/sync_manager.dart';
import '../data/services/sync_queue_service.dart';
import '../data/models/sync_operation.dart';
import '../core/app_theme.dart';

class SyncStatusIndicator extends StatelessWidget {
  const SyncStatusIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SyncManager.instance,
      builder: (context, _) {
        return FutureBuilder<List<SyncOperation>>(
          future: SyncQueueService.instance.getPending(),
          builder: (context, snapshot) {
            final pendingItems = snapshot.data ?? [];
            final hasFailed = pendingItems.any((item) => item.status == SyncStatus.failed);
            final isRunning = SyncManager.instance.isRunning;
            final hasPending = pendingItems.isNotEmpty;

            Color color;
            IconData icon;
            if (hasFailed) {
              color = AppTheme.danger;
              icon = Icons.sync_problem_rounded;
            } else if (isRunning || hasPending) {
              color = Colors.orange;
              icon = Icons.sync_rounded;
            } else {
              color = AppTheme.success;
              icon = Icons.cloud_done_rounded;
            }

            return IconButton(
              icon: Icon(icon, color: color),
              onPressed: () => Navigator.pushNamed(context, '/sync'),
              tooltip: 'Sync Status',
            );
          },
        );
      },
    );
  }
}
