import 'package:hasoob_app/data/services/reports/report_models.dart';
import 'package:hasoob_app/data/repositories/invoice_repository.dart';

enum DecisionPriority { critical, warning, opportunity, info }

class BusinessDecision {
  final String title;
  final String explanation;
  final DecisionPriority priority;
  final double confidenceScore;
  final String sourceDataSummary;
  final String suggestedActionLabel;
  final String? navigationTarget;

  const BusinessDecision({
    required this.title,
    required this.explanation,
    required this.priority,
    required this.confidenceScore,
    required this.sourceDataSummary,
    required this.suggestedActionLabel,
    this.navigationTarget,
  });
}

class DailyDecisionEngine {
  static final DailyDecisionEngine instance = DailyDecisionEngine._();

  final InvoiceRepository _invoiceRepository = InvoiceRepository();

  DailyDecisionEngine._();

  Future<List<BusinessDecision>> generateDecisions(String businessId, ReportsSnapshot snapshot) async {
    final decisions = <BusinessDecision>[];

    // Rule 1: Missing Business Data (Info)
    if (snapshot.totalProducts == 0 && snapshot.salesRecords.isEmpty) {
      decisions.add(const BusinessDecision(
        title: 'إعداد بيانات النشاط التجاري',
        explanation: 'الخطوة الأولى للبدء هي إضافة منتجاتك وتسجيل مبيعاتك لتمكين الذكاء المالي من العمل.',
        priority: DecisionPriority.info,
        confidenceScore: 0.99,
        sourceDataSummary: 'لا يوجد أصناف أو مبيعات مسجلة',
        suggestedActionLabel: 'إضافة منتج جديد',
        navigationTarget: 'products',
      ));
      return decisions; // No other decisions make sense without data
    }

    // Rule 2: Overdue Invoices Collection (Critical)
    try {
      final invoices = await _invoiceRepository.getInvoices(businessId);
      final now = DateTime.now();
      
      final overdueInvoices = invoices.where((inv) {
        return inv.status == 'unpaid' && 
               inv.dueDate != null && 
               inv.dueDate!.isBefore(now);
      }).toList();

      if (overdueInvoices.isNotEmpty) {
        final totalOverdue = overdueInvoices.fold<double>(
          0, (sum, inv) => sum + inv.remainingAmount
        );
        
        decisions.add(BusinessDecision(
          title: 'تحصيل فواتير متأخرة',
          explanation: 'يوجد ${overdueInvoices.length} فواتير متأخرة السداد تؤثر سلباً على التدفق النقدي.',
          priority: DecisionPriority.critical,
          confidenceScore: 0.95,
          sourceDataSummary: 'إجمالي المتأخرات: ${totalOverdue.toStringAsFixed(2)} ر.س',
          suggestedActionLabel: 'مراجعة الفواتير',
          navigationTarget: 'invoices',
        ));
      }
    } catch (e) {
      // Tolerate DB errors for engine
    }

    // Rule 3: Low Stock Reorder (Warning)
    if (snapshot.lowStockItems.isNotEmpty) {
      final itemsCount = snapshot.lowStockItems.length;
      final criticalItems = snapshot.lowStockItems.where((i) => i.isOutOfStock).length;
      
      decisions.add(BusinessDecision(
        title: 'إعادة طلب المخزون',
        explanation: 'الاستمرار في البيع دون تجديد المخزون سيفقدك مبيعات مؤكدة.',
        priority: DecisionPriority.warning,
        confidenceScore: 0.90,
        sourceDataSummary: '$itemsCount أصناف منخفضة، منها $criticalItems نافدة تماماً',
        suggestedActionLabel: 'تجديد المخزون',
        navigationTarget: 'inventory',
      ));
    }

    // Rule 4: Best-Selling Product Momentum (Opportunity)
    if (snapshot.bestSellingProducts.isNotEmpty) {
      final topProduct = snapshot.bestSellingProducts.first;
      if (topProduct.totalSales > 0) {
        decisions.add(BusinessDecision(
          title: 'استغلال زخم المبيعات',
          explanation: 'المنتج "${topProduct.name}" يحقق أعلى المبيعات، تأكد من توفره بكميات كافية وأطلق عروضاً مرتبطة به.',
          priority: DecisionPriority.opportunity,
          confidenceScore: 0.88,
          sourceDataSummary: 'حجم مبيعات المنتج: ${topProduct.totalSales.toStringAsFixed(2)} ر.س',
          suggestedActionLabel: 'تفاصيل المنتج',
          navigationTarget: 'products',
        ));
      }
    }

    // Limit to 4 maximum decisions
    decisions.sort((a, b) => a.priority.index.compareTo(b.priority.index));
    return decisions.take(4).toList();
  }
}
