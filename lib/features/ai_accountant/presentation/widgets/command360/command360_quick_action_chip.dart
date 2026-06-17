import 'package:flutter/material.dart';

import '../../../../../core/app_theme.dart';

class Command360QuickActionChip extends StatelessWidget {
  const Command360QuickActionChip({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  static const Color _textSecondary = AppTheme.aiTextSecondary;
  static const Color _premiumPanelSoft = Color(0xFF142033);
  static const Color _premiumStroke = Color(0xFF243044);

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 15),
      label: Text(
        label,
        overflow: TextOverflow.ellipsis,
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        disabledForegroundColor: _textSecondary,
        side: const BorderSide(color: _premiumStroke),
        backgroundColor: _premiumPanelSoft.withValues(alpha: 0.82),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
      ),
    );
  }
}
