import 'package:flutter/material.dart';

import '../../../../../core/app_theme.dart';

class Command360StarterQuestionChip extends StatelessWidget {
  const Command360StarterQuestionChip({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  static const Color _goldAccent = AppTheme.aiGold;
  static const Color _textSecondary = AppTheme.aiTextSecondary;
  static const Color _premiumPanelSoft = Color(0xFF142033);

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 15),
      label: Text(
        label,
        overflow: TextOverflow.ellipsis,
      ),
      style: FilledButton.styleFrom(
        foregroundColor: Colors.black,
        disabledForegroundColor: _textSecondary,
        backgroundColor: _goldAccent,
        disabledBackgroundColor: _premiumPanelSoft.withValues(alpha: 0.8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
      ),
    );
  }
}
