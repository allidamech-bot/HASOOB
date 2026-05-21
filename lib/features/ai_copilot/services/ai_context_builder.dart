class AiContextBuilder {
  Future<Map<String, dynamic>> buildContext(String businessId, String userId) async {
    // In foundation phase, return only safe local placeholder context.
    // Must not expose secrets, API keys, or upload data externally.
    return {
      'businessId': businessId,
      'userId': userId,
      'currentTimestamp': DateTime.now().toIso8601String(),
      'summary': 'Local AI placeholder context. No external services connected.',
    };
  }
}
