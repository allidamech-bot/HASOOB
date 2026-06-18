import 'package:flutter/material.dart';

import '../../../../../core/app_theme.dart';
import '../../../domain/services/ai_data_collection_state.dart';
import '../../../domain/services/ai_workflow_session.dart';

class Command360WorkflowCard extends StatelessWidget {
  const Command360WorkflowCard({
    super.key,
    required this.session,
  });

  final AiWorkflowSession session;

  static const Color _goldAccent = AppTheme.aiGold;
  static const Color _tealSuccess = AppTheme.aiGreen;
  static const Color _textSecondary = AppTheme.aiTextSecondary;

  @override
  Widget build(BuildContext context) {
    final collected = session.collectedData.keys
        .map(AiWorkflowField.label)
        .toList(growable: false);
    final waiting = session.waitingField == null
        ? 'Review'
        : AiWorkflowField.label(session.waitingField!);
    final step = session.currentStep.clamp(1, session.totalSteps);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _goldAccent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _goldAccent.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.route_outlined, color: _goldAccent, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${_workflowTitle(session.workflowType)} Workflow',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _statusPill('Step $step of ${session.totalSteps}', _goldAccent),
            ],
          ),
          const SizedBox(height: 10),
          if (collected.isNotEmpty)
            _workflowLine(
              Icons.check_circle_outline_rounded,
              'Collected',
              collected.join(', '),
              _tealSuccess,
            ),
          _workflowLine(
            Icons.hourglass_empty_rounded,
            'Waiting',
            waiting,
            _goldAccent,
          ),
        ],
      ),
    );
  }

  Widget _workflowLine(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 7),
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(color: _textSecondary, fontSize: 11),
            ),
          ),
          Expanded(
            child: Text(
              value,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusPill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Text(
        label,
        style:
            TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }

  String _workflowTitle(AiWorkflowType type) {
    switch (type) {
      case AiWorkflowType.purchase:
        return 'Purchase';
      case AiWorkflowType.sale:
        return 'Sale';
      case AiWorkflowType.pricing:
        return 'Pricing';
      case AiWorkflowType.inventoryAdjustment:
        return 'Inventory Adjustment';
      case AiWorkflowType.customerBalanceInquiry:
        return 'Customer Balance';
      case AiWorkflowType.supplierInquiry:
        return 'Supplier';
    }
  }
}
