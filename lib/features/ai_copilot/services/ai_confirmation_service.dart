import '../models/ai_action_draft.dart';

class AiConfirmationService {
  bool isExecutionAllowed(AiActionDraft draft) {
    // Destructive actions are absolutely not supported
    // Execution is entirely disabled in the foundation phase
    return false;
  }
}
