import 'package:flutter/material.dart';
import 'ai_workspace_controller.dart';

/// InheritedWidget to provide AiWorkspaceController down the widget tree.
/// This allows workspace state to survive screen rebuilds within the same workspace session.
class AiWorkspaceProvider extends InheritedWidget {
  const AiWorkspaceProvider({
    super.key,
    required this.controller,
    required super.child,
  });

  final AiWorkspaceController controller;

  static AiWorkspaceController of(BuildContext context) {
    final widget =
        context.getElementForInheritedWidgetOfExactType<AiWorkspaceProvider>();
    if (widget == null) {
      throw StateError('AiWorkspaceProvider not found in context. '
          'Ensure AiWorkspaceProvider is an ancestor of the calling widget.');
    }
    return (widget.widget as AiWorkspaceProvider).controller;
  }

  @override
  bool updateShouldNotify(AiWorkspaceProvider old) =>
      controller != old.controller;
}
