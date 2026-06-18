import 'package:flutter/material.dart';

import '../../../../../core/app_theme.dart';
import '../../../domain/services/ai_conversation_orchestrator.dart';

class Command360DecisionOptions extends StatelessWidget {
  const Command360DecisionOptions({
    super.key,
    required this.options,
  });

  final List<AiDecisionOption> options;

  static const Color _tealSuccess = AppTheme.aiGreen;
  static const Color _textSecondary = AppTheme.aiTextSecondary;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: options.map((option) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.aiCardElevated,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _tealSuccess.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.route_outlined,
                    color: _tealSuccess,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      option.title,
                      style: const TextStyle(
                        color: _tealSuccess,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _decisionLine('Recommendation', option.recommendation),
              _decisionLine('Advantage', option.advantage),
              _decisionLine('Risk', option.risk),
              _decisionLine('When', option.whenToUse),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _decisionLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(
                color: _textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
