enum AiAccountantIntent {
  financialOverview,
  profitabilityAnalysis,
  inventoryAnalysis,
  customerBalanceAnalysis,
  cashFlowAnalysis,
  invoiceAnalysis,
  pricingDecision,
  exportDecision,
  purchasePreparation,
  salePreparation,
  generalAdvice,
  executionIntent,
  unknown,
}

enum AiToolSafetyLevel {
  readOnly,
  proposalRequired,
  executionGuard,
  advisoryOnly,
}

class AiToolStep {
  final String toolName;
  final String reason;
  final bool required;
  final Map<String, dynamic> parameters;

  const AiToolStep({
    required this.toolName,
    required this.reason,
    required this.required,
    this.parameters = const {},
  });
}

class AiToolPlan {
  final AiAccountantIntent intent;
  final bool requiresTools;
  final List<AiToolStep> steps;
  final List<String> missingInputs;
  final AiToolSafetyLevel safetyLevel;

  const AiToolPlan({
    required this.intent,
    required this.requiresTools,
    required this.steps,
    required this.missingInputs,
    required this.safetyLevel,
  });
}

class AiToolPlanner {
  AiToolPlan plan({
    required String userText,
    String? businessId,
    String? currentProduct,
    String? latestCustomer,
  }) {
    final normalized = userText.toLowerCase().trim();
    final intent = _classify(normalized);
    final steps = _stepsFor(
      intent: intent,
      businessId: businessId,
      currentProduct: currentProduct,
      latestCustomer: latestCustomer,
    );
    return AiToolPlan(
      intent: intent,
      requiresTools: steps.isNotEmpty,
      steps: steps,
      missingInputs: _missingInputsFor(intent, normalized),
      safetyLevel: _safetyFor(intent),
    );
  }

  AiAccountantIntent _classify(String normalized) {
    if (_containsAny(normalized, [
      'execute',
      'approve',
      'save',
      'commit',
      'confirm',
      'convert',
      'نفذ',
      'اعتمد',
      'احفظ',
      'حول',
    ])) {
      return AiAccountantIntent.executionIntent;
    }
    if (_containsAny(normalized, [
      'prepare purchase',
      'purchase proposal',
      'buy proposal',
      'جهز شراء',
      'مقترح شراء',
    ])) {
      return AiAccountantIntent.purchasePreparation;
    }
    if (_containsAny(normalized, [
      'prepare sale',
      'sale proposal',
      'sell proposal',
      'جهز بيع',
      'مقترح بيع',
    ])) {
      return AiAccountantIntent.salePreparation;
    }
    if (_containsAny(normalized, [
      'how is the business',
      'financial overview',
      'business doing',
      'analyze business',
      'business report',
      'overview',
      'summary',
      'كيف وضع',
      'أعطني تقرير',
      'حلل النشاط',
      'وضع الشركة',
      'ملخص مالي',
    ])) {
      return AiAccountantIntent.financialOverview;
    }
    if (_containsAny(normalized, [
      'profitability',
      'profit analysis',
      'gross profit',
      'net profit',
      'analyze profit',
      'ربحية',
      'حلل الربح',
    ])) {
      return AiAccountantIntent.profitabilityAnalysis;
    }
    if (_containsAny(normalized, [
      'cash flow',
      'cashflow',
      'liquidity',
      'cash position',
      'سيولة',
      'تدفق نقدي',
    ])) {
      return AiAccountantIntent.cashFlowAnalysis;
    }
    if (_containsAny(normalized, [
      'invoice',
      'invoices',
      'pending invoices',
      'due invoices',
      'فاتورة',
      'فواتير',
    ])) {
      return AiAccountantIntent.invoiceAnalysis;
    }
    if (_containsAny(normalized, [
      'inventory',
      'stock',
      'low stock',
      'top products',
      'مخزون',
      'بضاعة',
    ])) {
      return AiAccountantIntent.inventoryAnalysis;
    }
    if (_containsAny(normalized, [
      'customer balance',
      'customers',
      'customer risk',
      'risky customer',
      'risky customers',
      'credit risk',
      'credit analyst',
      'stop extending credit',
      'owes me the most',
      'receivable',
      'customer balances',
      'رصيد عميل',
      'أرصدة العملاء',
    ])) {
      return AiAccountantIntent.customerBalanceAnalysis;
    }
    if (_containsAny(normalized, [
      'export',
      'shipping',
      'customs',
      'saudi',
      'تصدير',
      'شحن',
      'جمارك',
    ])) {
      return AiAccountantIntent.exportDecision;
    }
    if (_containsAny(normalized, [
      'price',
      'pricing',
      'margin',
      'landed cost',
      'سعر',
      'تسعير',
      'هامش',
    ])) {
      return AiAccountantIntent.pricingDecision;
    }
    if (_containsAny(normalized, [
      'help',
      'advice',
      'recommend',
      'what can you do',
      'ساعدني',
      'نصيحة',
    ])) {
      return AiAccountantIntent.generalAdvice;
    }
    return AiAccountantIntent.unknown;
  }

  List<AiToolStep> _stepsFor({
    required AiAccountantIntent intent,
    required String? businessId,
    required String? currentProduct,
    required String? latestCustomer,
  }) {
    final base = {'businessId': businessId ?? ''};
    switch (intent) {
      case AiAccountantIntent.financialOverview:
        return [
          AiToolStep(
            toolName: 'getFinancialSummary',
            reason:
                'Understand income, expenses, profit, cash flow, and receivables.',
            required: true,
            parameters: base,
          ),
          AiToolStep(
            toolName: 'getInvoices',
            reason: 'Check pending invoice exposure.',
            required: false,
            parameters: {...base, 'limit': 20},
          ),
          AiToolStep(
            toolName: 'getProducts',
            reason: 'Check inventory exposure and stock risk.',
            required: false,
            parameters: {...base, 'lowStockOnly': true, 'limit': 20},
          ),
          AiToolStep(
            toolName: 'getCustomers',
            reason: 'Check customer balance and receivables risk.',
            required: false,
            parameters: {...base, 'limit': 20},
          ),
        ];
      case AiAccountantIntent.profitabilityAnalysis:
        return [
          AiToolStep(
            toolName: 'getIncome',
            reason: 'Review sales and gross profit records.',
            required: true,
            parameters: {...base, 'limit': 100},
          ),
          AiToolStep(
            toolName: 'getExpenses',
            reason: 'Compare expenses against income.',
            required: true,
            parameters: {...base, 'limit': 100},
          ),
        ];
      case AiAccountantIntent.inventoryAnalysis:
        return [
          AiToolStep(
            toolName: 'getProducts',
            reason: 'Review stock levels and inventory value.',
            required: true,
            parameters: {
              ...base,
              'searchQuery': currentProduct,
              'lowStockOnly': false,
              'limit': 100,
            },
          ),
        ];
      case AiAccountantIntent.customerBalanceAnalysis:
        return [
          AiToolStep(
            toolName: 'getCustomers',
            reason: 'Review customer balances and receivables exposure.',
            required: true,
            parameters: {
              ...base,
              'searchQuery': latestCustomer,
              'limit': 100,
            },
          ),
          AiToolStep(
            toolName: 'getInvoices',
            reason:
                'Review invoice history, overdue frequency, and payment delays.',
            required: true,
            parameters: {...base, 'limit': 100},
          ),
        ];
      case AiAccountantIntent.cashFlowAnalysis:
        return [
          AiToolStep(
            toolName: 'getFinancialSummary',
            reason: 'Review cash-flow indicators and receivables.',
            required: true,
            parameters: base,
          ),
          AiToolStep(
            toolName: 'getInvoices',
            reason: 'Check invoice collection timing.',
            required: true,
            parameters: {...base, 'limit': 100},
          ),
        ];
      case AiAccountantIntent.invoiceAnalysis:
        return [
          AiToolStep(
            toolName: 'getInvoices',
            reason:
                'Review invoice totals, paid amounts, and outstanding balances.',
            required: true,
            parameters: {...base, 'limit': 100},
          ),
        ];
      case AiAccountantIntent.pricingDecision:
      case AiAccountantIntent.exportDecision:
      case AiAccountantIntent.purchasePreparation:
      case AiAccountantIntent.salePreparation:
      case AiAccountantIntent.generalAdvice:
      case AiAccountantIntent.executionIntent:
      case AiAccountantIntent.unknown:
        return const [];
    }
  }

  List<String> _missingInputsFor(AiAccountantIntent intent, String normalized) {
    switch (intent) {
      case AiAccountantIntent.purchasePreparation:
        return const [
          'product',
          'quantity',
          'unit cost or total cost',
          'supplier/payment info'
        ];
      case AiAccountantIntent.salePreparation:
        return const [
          'product',
          'quantity',
          'selling price',
          'customer/payment info'
        ];
      case AiAccountantIntent.pricingDecision:
        return const [
          'cost',
          'target margin',
          'competitor price or market goal'
        ];
      case AiAccountantIntent.exportDecision:
        return const [
          'product cost',
          'shipping cost',
          'customs/import fees',
          'market goal'
        ];
      default:
        return const [];
    }
  }

  AiToolSafetyLevel _safetyFor(AiAccountantIntent intent) {
    switch (intent) {
      case AiAccountantIntent.executionIntent:
        return AiToolSafetyLevel.executionGuard;
      case AiAccountantIntent.purchasePreparation:
      case AiAccountantIntent.salePreparation:
        return AiToolSafetyLevel.proposalRequired;
      case AiAccountantIntent.financialOverview:
      case AiAccountantIntent.profitabilityAnalysis:
      case AiAccountantIntent.inventoryAnalysis:
      case AiAccountantIntent.customerBalanceAnalysis:
      case AiAccountantIntent.cashFlowAnalysis:
      case AiAccountantIntent.invoiceAnalysis:
        return AiToolSafetyLevel.readOnly;
      case AiAccountantIntent.pricingDecision:
      case AiAccountantIntent.exportDecision:
      case AiAccountantIntent.generalAdvice:
      case AiAccountantIntent.unknown:
        return AiToolSafetyLevel.advisoryOnly;
    }
  }

  bool _containsAny(String value, List<String> needles) {
    return needles.any(value.contains);
  }
}
