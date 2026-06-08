import 'package:cloud_firestore/cloud_firestore.dart';

class AuditAnomalyModel {
  final String id;
  final String title;
  final String description;
  final String severity; // 'high' (حرجة) | 'medium' (متوسطة) | 'low' (منخفضة)
  final String affectedModule; // 'inventory' | 'invoices' | 'customers'
  final DateTime detectedAt;
  final String suggestedFix;
  bool isResolved;

  AuditAnomalyModel({
    required this.id,
    required this.title,
    required this.description,
    required this.severity,
    required this.affectedModule,
    required this.detectedAt,
    required this.suggestedFix,
    this.isResolved = false,
  });

  factory AuditAnomalyModel.fromMap(Map<String, dynamic> map, String docId) {
    return AuditAnomalyModel(
      id: docId,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      severity: map['severity'] ?? 'low',
      affectedModule: map['affectedModule'] ?? 'inventory',
      detectedAt: (map['detectedAt'] as Timestamp).toDate(),
      suggestedFix: map['suggestedFix'] ?? '',
      isResolved: map['isResolved'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'severity': severity,
      'affectedModule': affectedModule,
      'detectedAt': Timestamp.fromDate(detectedAt),
      'suggestedFix': suggestedFix,
      'isResolved': isResolved,
    };
  }
}
