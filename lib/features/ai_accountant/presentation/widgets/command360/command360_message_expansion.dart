import 'package:flutter/material.dart';

class Command360MessageExpansion extends StatelessWidget {
  const Command360MessageExpansion({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  static const Color _textSecondary = Color(0xFF6B8AAD);
  static const Color _premiumPanelSoft = Color(0xFF142033);
  static const Color _premiumStroke = Color(0xFF243044);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 7),
      decoration: BoxDecoration(
        color: _premiumPanelSoft.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _premiumStroke),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 10),
        childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        iconColor: _textSecondary,
        collapsedIconColor: _textSecondary,
        leading: Icon(icon, color: _textSecondary, size: 15),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
        children: [child],
      ),
    );
  }
}
