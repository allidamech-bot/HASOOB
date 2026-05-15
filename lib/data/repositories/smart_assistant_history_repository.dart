import 'dart:convert';

import '../database/database_helper.dart';
import '../models/smart_assistant_models.dart';

class SmartAssistantHistoryRepository {
  Future<void> savePreview(SmartAssistantPreview preview) async {
    await DBHelper.saveSmartAssistantHistory(_entryFromPreview(
      preview,
      SmartAssistantActionStatus.preview,
    ).toMap());
  }

  Future<void> saveDraft(SmartAssistantPreview preview) async {
    await DBHelper.saveSmartAssistantHistory(_entryFromPreview(
      preview,
      SmartAssistantActionStatus.draftSaved,
    ).toMap());
  }

  Future<void> markSaved(SmartAssistantPreview preview) async {
    await DBHelper.saveSmartAssistantHistory(_entryFromPreview(
      preview,
      SmartAssistantActionStatus.saved,
    ).toMap());
  }

  Future<List<SmartAssistantHistoryEntry>> recent({int limit = 25}) async {
    final rows = await DBHelper.getSmartAssistantHistory(limit: limit);
    return rows.map(SmartAssistantHistoryEntry.fromMap).toList();
  }

  Future<List<SmartAssistantHistoryEntry>> search(String query) async {
    final rows = await DBHelper.searchSmartAssistantHistory(query);
    return rows.map(SmartAssistantHistoryEntry.fromMap).toList();
  }

  SmartAssistantHistoryEntry _entryFromPreview(
    SmartAssistantPreview preview,
    SmartAssistantActionStatus status,
  ) {
    final now = DateTime.now();
    return SmartAssistantHistoryEntry(
      id: 'SAH_${now.microsecondsSinceEpoch}',
      userInput: preview.parse.userInput,
      detectedIntent: preview.parse.intent,
      extractedPayloadJson: jsonEncode(preview.parse.extracted),
      calculationResultJson: jsonEncode(preview.calculation.toJson()),
      suggestedActionJson:
          jsonEncode(preview.parse.suggestedAction ?? const {}),
      actionStatus: status,
      createdAt: now,
    );
  }
}
