import 'package:flutter/material.dart';
import '../core/app_copy.dart';
import '../core/app_theme.dart';
import '../core/ui/ui_tokens.dart';
import '../data/services/sync_manager.dart';
import '../data/repositories/sync_queue_repository.dart';
import '../core/services/connectivity_service.dart';

class SyncHealthCard extends StatelessWidget {
  const SyncHealthCard({super.key});

  @override
  Widget build(BuildContext context) {
    final copy = AppCopy.of(context);
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: SyncManager.instance,
      builder: (context, _) {
        return ListenableBuilder(
          listenable: ConnectivityService.instance,
          builder: (context, _) {
            return FutureBuilder<Map<String, dynamic>>(
              future: SyncQueueRepository().getSyncStats(),
              builder: (context, snapshot) {
                final stats = snapshot.data ?? {
                  'pending': 0,
                  'failed': 0,
                  'conflicts': 0,
                  'syncedToday': 0,
                };
                
                final pending = stats['pending'] as int;
                final failed = stats['failed'] as int;
                final isRunning = SyncManager.instance.isRunning;
                final isOnline = ConnectivityService.instance.isOnline;

                Color healthColor;
                String healthText;
                IconData healthIcon;

                if (!isOnline) {
                  healthColor = AppTheme.danger;
                  healthText = copy.t('syncOffline');
                  healthIcon = Icons.cloud_off_rounded;
                } else if (failed > 0) {
                  healthColor = AppTheme.danger;
                  healthText = copy.t('syncHealthWarning');
                  healthIcon = Icons.sync_problem_rounded;
                } else if (isRunning || pending > 0) {
                  healthColor = Colors.orange;
                  healthText = isRunning ? copy.t('syncRunning') : copy.t('syncHealthPending');
                  healthIcon = Icons.sync_rounded;
                } else {
                  healthColor = AppTheme.success;
                  healthText = copy.t('syncHealthGood');
                  healthIcon = Icons.cloud_done_rounded;
                }

return Card(
                   margin: EdgeInsets.zero,
                   child: InkWell(
                     onTap: () => Navigator.pushNamed(context, '/sync'),
                     borderRadius: BorderRadius.circular(UITokens.radiusLg),
                     child: Padding(
                       padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              _iconBox(context, healthIcon, healthColor),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      copy.t('syncStatus'),
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      healthText,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: healthColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                            ],
                          ),
                          if (pending > 0 || failed > 0) ...[
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                if (pending > 0)
                                  _statChip(
                                    context, 
                                    copy.t('syncStatsPending'), 
                                    pending.toString(), 
                                    Colors.blue,
                                  ),
                                if (pending > 0 && failed > 0) const SizedBox(width: 8),
                                if (failed > 0)
                                  _statChip(
                                    context, 
                                    copy.t('syncStatsFailed'), 
                                    failed.toString(), 
                                    AppTheme.danger,
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _iconBox(BuildContext context, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(UITokens.radiusMd),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  Widget _statChip(BuildContext context, String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.surfaceAltFor(context),
          borderRadius: BorderRadius.circular(UITokens.radiusSm),
          border: Border.all(color: AppTheme.borderFor(context)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(UITokens.radiusXs),
              ),
              child: Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
