import 'ai_financial_snapshot.dart';

enum AiFinancialRiskLevel {
  high,
  medium,
  low,
}

class AiFinancialRisk {
  final AiFinancialRiskLevel level;
  final String title;
  final String description;

  const AiFinancialRisk({
    required this.level,
    required this.title,
    required this.description,
  });

  String get levelLabel => level.name.toUpperCase();
}

class AiRiskDetector {
  List<AiFinancialRisk> detect(AiFinancialSnapshot snapshot) {
    final risks = <AiFinancialRisk>[];

    final overdue = snapshot.overdueInvoices;
    if (overdue != null && overdue > 0) {
      risks.add(AiFinancialRisk(
        level: AiFinancialRiskLevel.high,
        title: 'Overdue invoices',
        description:
            '$overdue overdue invoice${overdue == 1 ? '' : 's'} may pressure cash flow.',
      ));
    }

    final lowStock = snapshot.lowStockProducts;
    if (lowStock != null && lowStock > 0) {
      risks.add(AiFinancialRisk(
        level: AiFinancialRiskLevel.medium,
        title: 'Low stock',
        description:
            '$lowStock product${lowStock == 1 ? '' : 's'} are at or below their low-stock threshold.',
      ));
    }

    if (snapshot.customerRisk == 'open_balances') {
      risks.add(const AiFinancialRisk(
        level: AiFinancialRiskLevel.medium,
        title: 'Customer balances',
        description:
            'Open customer balances can slow collections and weaken liquidity.',
      ));
    }

    if (snapshot.missingData.isNotEmpty) {
      risks.add(AiFinancialRisk(
        level: AiFinancialRiskLevel.low,
        title: 'Missing evidence',
        description:
            'Some analysis inputs are unavailable: ${snapshot.missingData.join(', ')}.',
      ));
    }

    if (risks.isEmpty && snapshot.hasEvidence) {
      risks.add(const AiFinancialRisk(
        level: AiFinancialRiskLevel.low,
        title: 'No major risk detected',
        description: 'The available evidence does not show an urgent issue.',
      ));
    }

    return risks;
  }
}
