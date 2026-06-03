import 'package:flutter/widgets.dart';

/// Internal helper to compute how much bottom space we should reserve
/// in [DashboardScreen] so it doesn't get covered by the mobile [CommandDock].
class DashboardDockSpacer {
  static const double commandDockHeight = 84;
  static const double commandDockSafeAreaBottom = 16;

  /// Returns the bottom spacer height to avoid overlap with the mobile dock.
  static double bottomReservedSpace(BuildContext context) {
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom;
    final safeInsetBottom = MediaQuery.of(context).padding.bottom;

    // Safe area on web/Chrome can differ depending on how the browser
    // provides insets; use both to be safe.
    final extraInsets = bottomPadding + safeInsetBottom;

    return commandDockHeight + commandDockSafeAreaBottom + extraInsets + 8;
  }
}

