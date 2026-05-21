import '../models/ai_memory_item.dart';
import '../repositories/ai_copilot_repository.dart';

class AiMemoryService {
  final AiCopilotRepository _repository;

  AiMemoryService(this._repository);

  Future<void> saveMemory(AiMemoryItem item) async {
    // No sensitive data, secrets, or passwords should be passed here.
    // Only local persistence in this phase.
    await _repository.saveMemoryItem(item);
  }

  Future<List<AiMemoryItem>> getMemories(String businessId) async {
    return await _repository.getMemoryItems(businessId);
  }
}
