import 'package:flutter/material.dart';
import '../core/app_copy.dart';
import '../core/app_theme.dart';
import '../data/services/sync_manager.dart';

class SyncStatusIndicator extends StatelessWidget {
  const SyncStatusIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final copy = AppCopy.of(context);
    
    return ListenableBuilder(
      listenable: SyncManager.instance,
      builder: (context, _) {
        final manager = SyncManager.instance;
        final isRunning = manager.isRunning;
        final isRequested = manager.syncRequested;

        if (!isRunning && !isRequested) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: IconButton(
            tooltip: isRunning ? copy.t('syncRunning') : copy.t('syncNow'),
            onPressed: isRunning ? null : () => manager.runSync(),
            icon: isRunning
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accent),
                    ),
                  )
                : const Badge(
                    label: Text('!'),
                    child: Icon(Icons.sync_rounded, color: AppTheme.accent),
                  ),
          ),
        );
      },
    );
  }
}
