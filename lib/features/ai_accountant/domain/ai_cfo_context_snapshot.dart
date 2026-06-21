import 'ai_cfo_evidence.dart';

class AiCfoContextSnapshot {
  final List<AiCfoEvidence> cashSummary;
  final List<AiCfoEvidence> salesSummary;
  final List<AiCfoEvidence> inventorySummary;
  final List<AiCfoEvidence> receivablesSummary;
  final List<AiCfoEvidence> recentLedgerSignals;
  final List<AiCfoEvidence> recentSalesSignals;
  final List<String> dataCompletenessNotes;

  const AiCfoContextSnapshot({
    this.cashSummary = const [],
    this.salesSummary = const [],
    this.inventorySummary = const [],
    this.receivablesSummary = const [],
    this.recentLedgerSignals = const [],
    this.recentSalesSignals = const [],
    this.dataCompletenessNotes = const [],
  });

  const AiCfoContextSnapshot.empty()
      : cashSummary = const [],
        salesSummary = const [],
        inventorySummary = const [],
        receivablesSummary = const [],
        recentLedgerSignals = const [],
        recentSalesSignals = const [],
        dataCompletenessNotes = const ['No financial evidence is available.'];

  List<AiCfoEvidence> evidenceFor(AiCfoContextArea area) {
    return switch (area) {
      AiCfoContextArea.cash => cashSummary,
      AiCfoContextArea.sales => salesSummary,
      AiCfoContextArea.inventory => inventorySummary,
      AiCfoContextArea.receivables => receivablesSummary,
      AiCfoContextArea.ledger => recentLedgerSignals,
      AiCfoContextArea.recentSales => recentSalesSignals,
      AiCfoContextArea.businessHealth => [
          ...cashSummary,
          ...salesSummary,
          ...inventorySummary,
          ...receivablesSummary,
          ...recentLedgerSignals,
          ...recentSalesSignals,
        ],
    };
  }

  bool hasEvidenceFor(AiCfoContextArea area) => evidenceFor(area).isNotEmpty;
}

enum AiCfoContextArea {
  businessHealth,
  cash,
  sales,
  inventory,
  receivables,
  ledger,
  recentSales,
}
