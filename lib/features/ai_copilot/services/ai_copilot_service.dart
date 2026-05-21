import '../models/ai_thread.dart';
import '../models/ai_message.dart';
import '../models/ai_action_draft.dart';
import '../repositories/ai_copilot_repository.dart';
import 'ai_action_planner.dart';

class AiCopilotService {
  final AiCopilotRepository _repository;
  final AiActionPlanner _planner;

  AiCopilotService(this._repository, this._planner);

  Future<AiThread> startOrLoadThread(String businessId, String userId) async {
    final threads = await _repository.getThreads(businessId);
    if (threads.isNotEmpty) {
      return threads.first;
    }

    final now = DateTime.now();
    final newThread = AiThread(
      id: 'thread_${now.microsecondsSinceEpoch}',
      businessId: businessId,
      userId: userId,
      title: 'New Conversation',
      status: 'active',
      createdAt: now,
      updatedAt: now,
    );
    await _repository.createThread(newThread);
    return newThread;
  }

  Future<void> sendUserMessage(String content, AiThread thread) async {
    final now = DateTime.now();
    
    // Save User Message
    final userMessage = AiMessage(
      id: 'msg_${now.microsecondsSinceEpoch}',
      threadId: thread.id,
      businessId: thread.businessId,
      role: 'user',
      content: content,
      createdAt: now,
    );
    await _repository.saveMessage(userMessage);

    // Parse Intent for Draft (Foundation Phase Only)
    final draft = await _planner.parseActionFromText(
      text: content,
      threadId: thread.id,
      businessId: thread.businessId,
      userId: thread.userId,
    );

    if (draft != null) {
      await _repository.saveActionDraft(draft);
    }

    // Save Assistant Placeholder Response
    final assistantMessage = AiMessage(
      id: 'msg_${now.microsecondsSinceEpoch + 1}',
      threadId: thread.id,
      businessId: thread.businessId,
      role: 'assistant',
      content: draft != null 
          ? 'I have prepared an action draft based on your request. Please review it carefully.'
          : 'This is a placeholder response. Real AI is not connected in the foundation phase.',
      createdAt: now.add(const Duration(milliseconds: 500)),
    );
    await _repository.saveMessage(assistantMessage);
  }

  Future<List<AiMessage>> getThreadMessages(String threadId) async {
    return await _repository.getMessages(threadId);
  }

  Future<AiActionDraft?> getLatestDraft(String businessId) async {
    final drafts = await _repository.getActionDrafts(businessId);
    if (drafts.isNotEmpty && drafts.first.status == 'draft') {
      return drafts.first;
    }
    return null;
  }

  Future<void> confirmDraft(String draftId) async {
    // In foundation phase, we only change the status. We DO NOT execute anything.
    await _repository.updateActionDraftStatus(draftId, 'execution_skipped');
  }
}
