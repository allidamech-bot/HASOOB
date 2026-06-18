import 'package:flutter/material.dart';

import '../../../../../core/app_theme.dart';

class Command360ContextRow extends StatelessWidget {
  const Command360ContextRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  static const Color _textSecondary = AppTheme.aiTextSecondary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: _textSecondary, size: 16),
          const SizedBox(width: 9),
          SizedBox(
            width: 94,
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
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
