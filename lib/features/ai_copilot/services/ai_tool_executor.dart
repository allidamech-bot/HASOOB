import '../models/ai_action_draft.dart';

class AiToolExecutor {
  Future<String> executeDraft(AiActionDraft draft) async {
    // Execution is strictly disabled in the foundation phase.
    // Do NOT call any business repositories (ProductRepository, etc.) or write to the main DB.
    return 'Execution is disabled in foundation phase.';
  }
}
