import 'package:flutter/material.dart';

import '../../../../../core/app_theme.dart';
import '../../../domain/services/ai_conversation_orchestrator.dart';

class Command360MemoryCard extends StatelessWidget {
  const Command360MemoryCard({
    super.key,
    required this.memory,
  });

  final AiConversationMemory memory;

  static const Color _goldAccent = AppTheme.aiGold;
  static const Color _textSecondary = AppTheme.aiTextSecondary;

  @override
  Widget build(BuildContext context) {
    final rows = [
      if (memory.currentProduct != null) ('Product', memory.currentProduct!),
      if (memory.currentDestination != null)
        ('Destination', memory.currentDestination!),
      if (memory.currentCost != null)
        ('Cost', memory.currentCost!.toStringAsFixed(2)),
      if (memory.currentMargin != null)
        ('Margin', '${memory.currentMargin!.toStringAsFixed(0)}%'),
      if (memory.latestCustomer != null) ('Customer', memory.latestCustomer!),
      if (memory.missingData.isNotEmpty)
        ('Missing', memory.missingData.join(', ')),
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _goldAccent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _goldAccent.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.memory_outlined, color: _goldAccent, size: 16),
              SizedBox(width: 8),
              Text(
                'Conversation context',
                style: TextStyle(
                  color: _goldAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...rows.map((row) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 92,
                    child: Text(
                      row.$1,
                      style:
                          const TextStyle(color: _textSecondary, fontSize: 11),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      row.$2,
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
