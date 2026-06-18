import 'package:flutter/material.dart';

import '../../../../../core/app_theme.dart';

class Command360ExecutiveTabButton extends StatelessWidget {
  const Command360ExecutiveTabButton({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  static const Color _goldAccent = AppTheme.aiGold;
  static const Color _textSecondary = AppTheme.aiTextSecondary;
  static const Color _premiumPanelSoft = Color(0xFF142033);
  static const Color _premiumStroke = Color(0xFF243044);

  @override
  Widget build(BuildContext context) {
    final color = selected ? _goldAccent : _textSecondary;
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 15),
      label: Text(label, overflow: TextOverflow.ellipsis),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(
          color:
              selected ? _goldAccent.withValues(alpha: 0.36) : _premiumStroke,
        ),
        backgroundColor: selected
            ? _goldAccent.withValues(alpha: 0.1)
            : _premiumPanelSoft.withValues(alpha: 0.72),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
      ),
    );
  }
}
