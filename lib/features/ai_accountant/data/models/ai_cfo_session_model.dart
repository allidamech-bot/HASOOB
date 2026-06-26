import 'dart:convert';

/// Non-ledger AI CFO session archive model.
/// Stored in the isolated [ai_cfo_sessions] table.
/// Does NOT represent any official accounting record.
class AiCfoSessionModel {
  final String id;
  final String businessId;
  final String title;
  final String summary;
  final String reportBody;
  final String draftsJson;   // JSON-encoded list of draft archive maps
  final String status;       // 'draft' | 'archived'
  final DateTime createdAt;
  final DateTime updatedAt;

  const AiCfoSessionModel({
    required this.id,
    required this.businessId,
    required this.title,
    required this.summary,
    required this.reportBody,
    required this.draftsJson,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AiCfoSessionModel.create({
    required String businessId,
    required String title,
    required String summary,
    required String reportBody,
    required List<Map<String, dynamic>> drafts,
    String status = 'archived',
  }) {
    final now = DateTime.now();
    return AiCfoSessionModel(
      id: 'aicfo_${now.millisecondsSinceEpoch}',
      businessId: businessId,
      title: title,
      summary: summary,
      reportBody: reportBody,
      draftsJson: jsonEncode(drafts),
      status: status,
      createdAt: now,
      updatedAt: now,
    );
  }

  factory AiCfoSessionModel.fromMap(Map<String, dynamic> map) {
    return AiCfoSessionModel(
      id: map['id']?.toString() ?? '',
      businessId: map['businessId']?.toString() ?? '',
      title: map['title']?.toString() ?? 'Untitled Session',
      summary: map['summary']?.toString() ?? '',
      reportBody: map['reportBody']?.toString() ?? '',
      draftsJson: map['draftsJson']?.toString() ?? '[]',
      status: map['status']?.toString() ?? 'archived',
      createdAt: _parseDate(map['createdAt']),
      updatedAt: _parseDate(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'businessId': businessId,
        'title': title,
        'summary': summary,
        'reportBody': reportBody,
        'draftsJson': draftsJson,
        'status': status,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  List<Map<String, dynamic>> get drafts {
    try {
      final decoded = jsonDecode(draftsJson);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    } catch (_) {}
    return const [];
  }

  String get shortDate {
    final d = createdAt;
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  static DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    try {
      return DateTime.parse(value.toString());
    } catch (_) {
      return DateTime.now();
    }
  }
}
