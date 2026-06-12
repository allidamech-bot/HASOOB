import 'ai_financial_snapshot.dart';
import 'ai_risk_detector.dart';

enum AiInsightCategory {
  growth,
  profitability,
  inventory,
  cashflow,
  receivables,
  operational,
}

class AiFinancialInsight {
  final AiInsightCategory category;
  final String title;
  final String description;

  const AiFinancialInsight({
    required this.category,
    required this.title,
    required this.description,
  });
}

class AiFinancialRecommendation {
  final String title;
  final String description;

  const AiFinancialRecommendation({
    required this.title,
    required this.description,
  });
}

class AiInsightGenerator {
  List<AiFinancialInsight> generateInsights(AiFinancialSnapshot snapshot) {
    final insights = <AiFinancialInsight>[];

    if (snapshot.revenue != null) {
      insights.add(AiFinancialInsight(
        category: AiInsightCategory.growth,
        title: 'Revenue visible',
        description:
            'Confirmed revenue is ${_money(snapshot.revenue!)} in the available financial summary.',
      ));
    }

    if (snapshot.profit != null && snapshot.revenue != null) {
      final margin = snapshot.revenue == 0
          ? 0
          : (snapshot.profit! / snapshot.revenue! * 100);
      insights.add(AiFinancialInsight(
        category: AiInsightCategory.profitability,
        title: 'Profitability baseline',
        description:
            'Confirmed profit is ${_money(snapshot.profit!)} with an approximate margin of ${margin.toStringAsFixed(1)}%.',
      ));
    }

    if (snapshot.pendingInvoices != null) {
      insights.add(AiFinancialInsight(
        category: AiInsightCategory.cashflow,
        title: 'Receivables affect cash',
        description:
            'Pending invoice exposure is ${_money(snapshot.pendingInvoices!)}.',
      ));
    }

    if (snapshot.inventoryHealth != null) {
      insights.add(AiFinancialInsight(
        category: AiInsightCategory.inventory,
        title: snapshot.inventoryHealth == 'healthy'
            ? 'Inventory healthy'
            : 'Inventory needs attention',
        description: snapshot.lowStockProducts == null
            ? 'Inventory records are available for review.'
            : '${snapshot.lowStockProducts} low-stock product${snapshot.lowStockProducts == 1 ? '' : 's'} found in available records.',
      ));
    }

    if (snapshot.customerRisk != null) {
      insights.add(AiFinancialInsight(
        category: AiInsightCategory.receivables,
        title: snapshot.customerRisk == 'open_balances'
            ? 'Customer balances open'
            : 'Customer balance risk low',
        description: snapshot.customerRisk == 'open_balances'
            ? 'Customer records show open balances that should be reviewed.'
            : 'Customer balance evidence does not show a major collection issue.',
      ));
    }

    if (snapshot.missingData.isNotEmpty) {
      insights.add(AiFinancialInsight(
        category: AiInsightCategory.operational,
        title: 'Analysis has gaps',
        description:
            'Missing inputs limit the confidence of the overview: ${snapshot.missingData.join(', ')}.',
      ));
    }

    return insights;
  }

  List<AiFinancialRecommendation> generateRecommendations({
    required AiFinancialSnapshot snapshot,
    required List<AiFinancialRisk> risks,
  }) {
    final recommendations = <AiFinancialRecommendation>[];

    if (risks.any((risk) => risk.title == 'Overdue invoices')) {
      recommendations.add(const AiFinancialRecommendation(
        title: 'Follow up overdue customers',
        description:
            'Contact overdue customers within 7 days and prioritize the largest balances first.',
      ));
    }

    if (risks.any((risk) => risk.title == 'Low stock')) {
      recommendations.add(const AiFinancialRecommendation(
        title: 'Review replenishment',
        description:
            'Check sales speed before preparing any purchase proposal for low-stock products.',
      ));
    }

    if (snapshot.profit != null && snapshot.profit! < 0) {
      recommendations.add(const AiFinancialRecommendation(
        title: 'Protect margin',
        description:
            'Review expense categories and pricing before approving new commitments.',
      ));
    }

    if (snapshot.missingData.isNotEmpty) {
      recommendations.add(const AiFinancialRecommendation(
        title: 'Complete missing evidence',
        description:
            'Load or confirm missing records before making a high-confidence decision.',
      ));
    }

    if (recommendations.isEmpty && snapshot.hasEvidence) {
      recommendations.add(const AiFinancialRecommendation(
        title: 'Keep monitoring',
        description:
            'Continue tracking receivables, inventory thresholds, and profitability before major commitments.',
      ));
    }

    return recommendations;
  }

  String _money(double value) {
    return value.toStringAsFixed(value % 1 == 0 ? 0 : 2);
  }
}
