import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

import '../../../../core/business/business_context.dart';
import '../../data/models/ai_proposal_model.dart';
import '../../data/tools/financial_tools.dart';
import 'ai_business_memory.dart';
import 'ai_business_memory_manager.dart';
import 'ai_cfo_policy.dart';
import 'ai_decision_questionnaire.dart';
import 'ai_decision_scenario.dart';
import 'ai_data_collection_state.dart';
import 'ai_evidence_bundle.dart';
import 'ai_financial_decision_engine.dart';
import 'ai_financial_snapshot.dart';
import 'ai_import_export_cfo_advisor.dart';
import 'ai_insight_generator.dart';
import 'ai_response_metadata.dart';
import 'ai_risk_detector.dart';
import 'ai_tool_executor.dart';
import 'ai_tool_planner.dart';
import 'ai_workflow_manager.dart';
import 'ai_workflow_session.dart';
import 'financial_reasoning_engine.dart';

enum AiAdvisorMode {
  chat,
  advice,
  pricing,
  export,
  analysis,
  proposalReview,
  executionGuard,
}

class AiConversationTurn {
  final String role;
  final String text;
  final DateTime timestamp;

  const AiConversationTurn({
    required this.role,
    required this.text,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'role': role,
        'text': text,
        'timestamp': timestamp.toIso8601String(),
      };
}

class AiDecisionOption {
  final String title;
  final String recommendation;
  final String advantage;
  final String risk;
  final String whenToUse;

  const AiDecisionOption({
    required this.title,
    required this.recommendation,
    required this.advantage,
    required this.risk,
    required this.whenToUse,
  });

  factory AiDecisionOption.fromMap(Map<String, dynamic> map) {
    return AiDecisionOption(
      title: map['title']?.toString() ?? '',
      recommendation: map['recommendation']?.toString() ?? '',
      advantage: map['advantage']?.toString() ?? '',
      risk: map['risk']?.toString() ?? '',
      whenToUse: map['whenToUse']?.toString() ?? '',
    );
  }
}

class AiConversationMemory {
  final String? currentProduct;
  final String? currentDestination;
  final double? currentCost;
  final double? currentMargin;
  final String? latestCustomer;
  final String? latestTopic;
  final List<String> missingData;

  const AiConversationMemory({
    this.currentProduct,
    this.currentDestination,
    this.currentCost,
    this.currentMargin,
    this.latestCustomer,
    this.latestTopic,
    this.missingData = const [],
  });

  AiConversationMemory copyWith({
    String? currentProduct,
    String? currentDestination,
    double? currentCost,
    double? currentMargin,
    String? latestCustomer,
    String? latestTopic,
    List<String>? missingData,
  }) {
    return AiConversationMemory(
      currentProduct: currentProduct ?? this.currentProduct,
      currentDestination: currentDestination ?? this.currentDestination,
      currentCost: currentCost ?? this.currentCost,
      currentMargin: currentMargin ?? this.currentMargin,
      latestCustomer: latestCustomer ?? this.latestCustomer,
      latestTopic: latestTopic ?? this.latestTopic,
      missingData: missingData ?? this.missingData,
    );
  }

  Map<String, dynamic> toJson() => {
        'currentProduct': currentProduct,
        'currentDestination': currentDestination,
        'currentCost': currentCost,
        'currentMargin': currentMargin,
        'latestCustomer': latestCustomer,
        'latestTopic': latestTopic,
        'missingData': missingData,
      };

  bool get hasVisibleContext {
    return currentProduct != null ||
        currentDestination != null ||
        currentCost != null ||
        currentMargin != null ||
        latestCustomer != null ||
        missingData.isNotEmpty;
  }
}

class AiAdvisorResponse {
  final AiAdvisorMode mode;
  final String text;
  final List<String> suggestedReplies;
  final List<AiDecisionOption> decisionOptions;
  final AiConversationMemory memory;
  final bool shouldPrepareProposal;
  final AiResponseMetadata? metadata;
  final AiFinancialSnapshot? financialSnapshot;
  final List<AiFinancialInsight> insights;
  final List<AiFinancialRisk> risks;
  final List<AiFinancialRecommendation> recommendations;
  final AiWorkflowSession? workflowSession;
  final String? proposalDraftText;

  const AiAdvisorResponse({
    required this.mode,
    required this.text,
    required this.memory,
    this.suggestedReplies = const [],
    this.decisionOptions = const [],
    this.shouldPrepareProposal = false,
    this.metadata,
    this.financialSnapshot,
    this.insights = const [],
    this.risks = const [],
    this.recommendations = const [],
    this.workflowSession,
    this.proposalDraftText,
  });

  AiAdvisorResponse copyWith({
    AiAdvisorMode? mode,
    String? text,
    List<String>? suggestedReplies,
    List<AiDecisionOption>? decisionOptions,
    AiConversationMemory? memory,
    bool? shouldPrepareProposal,
    AiResponseMetadata? metadata,
    AiFinancialSnapshot? financialSnapshot,
    List<AiFinancialInsight>? insights,
    List<AiFinancialRisk>? risks,
    List<AiFinancialRecommendation>? recommendations,
    AiWorkflowSession? workflowSession,
    String? proposalDraftText,
  }) {
    return AiAdvisorResponse(
      mode: mode ?? this.mode,
      text: text ?? this.text,
      suggestedReplies: suggestedReplies ?? this.suggestedReplies,
      decisionOptions: decisionOptions ?? this.decisionOptions,
      memory: memory ?? this.memory,
      shouldPrepareProposal:
          shouldPrepareProposal ?? this.shouldPrepareProposal,
      metadata: metadata ?? this.metadata,
      financialSnapshot: financialSnapshot ?? this.financialSnapshot,
      insights: insights ?? this.insights,
      risks: risks ?? this.risks,
      recommendations: recommendations ?? this.recommendations,
      workflowSession: workflowSession ?? this.workflowSession,
      proposalDraftText: proposalDraftText ?? this.proposalDraftText,
    );
  }
}

class AiConversationOrchestrator {
  AiConversationOrchestrator({FinancialTools? financialTools})
      : _toolExecutor = AiToolExecutor(tools: financialTools),
        _toolPlanner = AiToolPlanner(),
        _insightGenerator = AiInsightGenerator(),
        _riskDetector = AiRiskDetector(),
        _workflowManager = AiWorkflowManager(),
        _businessMemoryManager = AiBusinessMemoryManager(),
        _decisionEngine = AiFinancialDecisionEngine(),
        _decisionQuestionnaire = AiDecisionQuestionnaire(),
        _cfoPolicy = AiCfoPolicy();

  final AiToolExecutor _toolExecutor;
  final AiToolPlanner _toolPlanner;
  final AiInsightGenerator _insightGenerator;
  final AiRiskDetector _riskDetector;
  final AiWorkflowManager _workflowManager;
  final AiBusinessMemoryManager _businessMemoryManager;
  final AiFinancialDecisionEngine _decisionEngine;
  final AiDecisionQuestionnaire _decisionQuestionnaire;
  final AiCfoPolicy _cfoPolicy;
  final List<AiConversationTurn> _history = [];
  AiConversationMemory _memory = const AiConversationMemory();

  AiConversationMemory get memory => _memory;
  AiBusinessMemory get businessMemory => _businessMemoryManager.memory;
  List<AiConversationTurn> get history => List.unmodifiable(_history);
  AiWorkflowSession? get activeWorkflow => _workflowManager.activeSession;

  bool get _isArabic => _lastInputWasArabic;
  bool _lastInputWasArabic = false;

  void clearBusinessMemory() {
    _businessMemoryManager.clear();
  }

  Future<AiAdvisorResponse> generateResponse({
    required String userText,
    AiProposalModel? activeProposal,
  }) async {
    _history.add(AiConversationTurn(
      role: 'user',
      text: userText,
      timestamp: DateTime.now(),
    ));
    _remember(userText, activeProposal: activeProposal);
    _businessMemoryManager.updateFromConversation(
      text: userText,
      topic: _memory.latestTopic,
      product: _memory.currentProduct,
      customer: _memory.latestCustomer,
    );

    _lastInputWasArabic = _containsArabic(userText);
    final normalized = _normalized(userText);
    final localAccountingResponse =
        _tryHandleLocalAccountingMessage(userText, normalized);
    if (localAccountingResponse != null) {
      _rememberAssistant(localAccountingResponse);
      return localAccountingResponse;
    }

    final decisionResponse = await _tryHandleFinancialDecision(userText);
    if (decisionResponse != null) {
      _rememberAssistant(decisionResponse);
      return decisionResponse;
    }

    final workflowResult = _workflowManager.handleMessage(userText);
    if (workflowResult != null) {
      final workflowSession = workflowResult.session;
      if (workflowResult.isComplete && workflowSession != null) {
        _businessMemoryManager.updateFromWorkflow(workflowSession);
      }
      final response = AiAdvisorResponse(
        mode: workflowResult.isComplete
            ? AiAdvisorMode.proposalReview
            : AiAdvisorMode.advice,
        text: _decorateWorkflowResponse(workflowResult),
        memory: _memory,
        suggestedReplies: workflowResult.suggestedReplies,
        shouldPrepareProposal: workflowResult.proposalDraftText != null,
        metadata: AiResponseMetadata.low(),
        workflowSession: workflowResult.session,
        proposalDraftText: workflowResult.proposalDraftText,
      );
      _rememberAssistant(response);
      return response;
    }

    final plan = _toolPlanner.plan(
      userText: userText,
      businessId: BusinessContext.businessId,
      currentProduct: _memory.currentProduct,
      latestCustomer: _memory.latestCustomer,
    );

    if (plan.intent == AiAccountantIntent.executionIntent) {
      final response = _executionGuardResponse(activeProposal).copyWith(
        metadata: AiResponseMetadata.low(
          missingEvidence: activeProposal == null
              ? const ['active complete proposal']
              : const [],
        ),
      );
      _rememberAssistant(response);
      return response;
    }
    if (_isClearTransactionCommand(normalized) &&
        !_isPreparationRequest(normalized) &&
        !plan.requiresTools) {
      return AiAdvisorResponse(
        mode: AiAdvisorMode.proposalReview,
        text: '',
        memory: _memory,
        shouldPrepareProposal: true,
        metadata: AiResponseMetadata.low(),
      );
    }

    final evidence = await _buildEvidenceBundle(plan);
    final metadata = AiResponseMetadata.fromEvidence(evidence);
    final snapshot = plan.intent == AiAccountantIntent.financialOverview
        ? AiFinancialSnapshot.fromEvidence(evidence)
        : null;
    final risks =
        snapshot == null ? <AiFinancialRisk>[] : _riskDetector.detect(snapshot);
    final insights = snapshot == null
        ? <AiFinancialInsight>[]
        : _insightGenerator.generateInsights(snapshot);
    final recommendations = snapshot == null
        ? <AiFinancialRecommendation>[]
        : _insightGenerator.generateRecommendations(
            snapshot: snapshot,
            risks: risks,
          );
    final llmResponse = await _tryGenerateLlmResponse(
      userText: userText,
      plan: plan,
      evidence: evidence,
      snapshot: snapshot,
      insights: insights,
      risks: risks,
      recommendations: recommendations,
      activeProposal: activeProposal,
    );
    final baseResponse =
        (llmResponse ?? _fallbackResponse(normalized, plan, evidence)).copyWith(
      metadata: metadata,
      financialSnapshot: snapshot,
      insights: insights,
      risks: risks,
      recommendations: recommendations,
    );
    final response = _withRelevantMemory(
      baseResponse,
      plan: plan,
      userText: userText,
    );
    _businessMemoryManager.extractFromAnalysis(
      plan: plan,
      evidence: evidence,
      snapshot: snapshot,
      risks: risks,
      recommendations: recommendations,
    );
    _rememberAssistant(response);
    return response;
  }

  void rememberProposal(AiProposalModel proposal) {
    final inventory = proposal.inventoryPayload;
    final customer = proposal.customerPayload;
    final pricing = proposal.pricingPayload;
    _memory = _memory.copyWith(latestTopic: 'proposal_review');
    if (inventory != null) {
      final name = inventory['name']?.toString();
      if (name != null && name.trim().isNotEmpty) {
        _memory = _memory.copyWith(currentProduct: name.trim());
      }
    }
    if (customer != null) {
      final name = customer['name']?.toString();
      if (name != null && name.trim().isNotEmpty) {
        _memory = _memory.copyWith(latestCustomer: name.trim());
      }
    }
    if (pricing != null) {
      final destination = pricing['destination']?.toString();
      final margin = (pricing['targetMarginPercentage'] as num?)?.toDouble();
      _memory = _memory.copyWith(
        currentDestination: destination != null && destination.trim().isNotEmpty
            ? destination.trim()
            : null,
        currentMargin: margin,
      );
    }
    _businessMemoryManager.updateFromProposal(proposal);
  }

  void markExecutionFollowUp() {
    _memory = _memory.copyWith(latestTopic: 'execution_follow_up');
  }

  Future<AiEvidenceBundle> _buildEvidenceBundle(AiToolPlan plan) async {
    if (!plan.requiresTools) return AiEvidenceBundle.empty(plan: plan);

    try {
      final results = <AiExecutedToolEvidence>[];
      for (final step in plan.steps) {
        final result = await _toolExecutor.executeTool(
          ToolCall(name: step.toolName, arguments: step.parameters),
        );
        results.add(AiExecutedToolEvidence(
          toolName: result.toolName,
          success: result.success,
          reason: step.reason,
          data: result.data,
          error: result.error,
        ));
      }
      return AiEvidenceBundle.fromToolResults(plan: plan, tools: results);
    } catch (e) {
      return AiEvidenceBundle.empty(
        plan: plan,
        missingEvidence: ['Financial data is not available: $e'],
      );
    }
  }

  Future<AiAdvisorResponse?> _tryHandleFinancialDecision(
      String userText) async {
    final activeDecision = _decisionQuestionnaire.activeState;
    final isContinuingDecision =
        activeDecision != null && !activeDecision.isComplete;
    final isNewDecision = _decisionEngine.isDecisionRequest(userText);

    if (!isContinuingDecision && !isNewDecision) return null;

    AiDecisionQuestionnaireState state;
    AiFinancialDecisionType decisionType;
    if (isContinuingDecision) {
      state = _decisionQuestionnaire.continueWith(userText)!;
      decisionType = _decisionTypeFromName(state.decisionType);
    } else {
      decisionType = _decisionEngine.detectDecisionType(userText);
      state = _decisionQuestionnaire.start(
        decisionType: decisionType.name,
        requiredInputs: _decisionEngine.requiredInputsFor(decisionType),
        seedInputs: _decisionSeedInputs(userText, decisionType),
      );
    }

    final plan = _toolPlanner.plan(
      userText: userText,
      businessId: BusinessContext.businessId,
      currentProduct: _memory.currentProduct,
      latestCustomer: _memory.latestCustomer,
    );
    final evidence = await _buildEvidenceBundle(plan);
    final result = _decisionEngine.evaluate(
      decisionType: decisionType,
      inputs: state.collectedInputs,
      evidence: evidence,
      questionnaire: _decisionQuestionnaire,
    );
    final policy = _cfoPolicy.evaluate(
      decisionType: decisionType,
      inputs: state.collectedInputs,
    );

    final response = _decisionResponseFromResult(
      result: result,
      policyRationale: policy.rationale,
      policyBlocks: policy.blocksRecommendation,
      evidence: evidence,
    );
    if (!result.needsMoreInformation) {
      _businessMemoryManager.extractFromDecision(result: result);
    }
    if (!result.needsMoreInformation) _decisionQuestionnaire.clear();
    return response;
  }

  AiAdvisorResponse _withRelevantMemory(
    AiAdvisorResponse response, {
    required AiToolPlan plan,
    required String userText,
  }) {
    final memorySummary = _businessMemoryManager.summarizeRelevant(
      intent: plan.intent,
      userText: userText,
      relatedEntity: _memory.latestCustomer ?? _memory.currentProduct,
    );
    if (memorySummary.isEmpty || response.text.contains('Relevant Memory:')) {
      return response;
    }
    return response.copyWith(
      text: '${response.text}\n\nRelevant Memory:\n$memorySummary',
    );
  }

  AiAdvisorResponse _decisionResponseFromResult({
    required AiFinancialDecisionResult result,
    required String policyRationale,
    required bool policyBlocks,
    required AiEvidenceBundle evidence,
  }) {
    final recommendation =
        policyBlocks ? policyRationale : result.recommendation;
    final missing =
        result.missingInputs.isEmpty ? 'None' : result.missingInputs.join(', ');
    final shipmentText = result.shipmentDecision == null
        ? ''
        : '\n\nShipment Metrics:\n${_shipmentDecisionLines(result.shipmentDecision!).join('\n')}';
    final scenarioText = result.scenarios.isEmpty
        ? ''
        : '\n\nScenarios:\n${result.scenarios.map(_scenarioLine).join('\n')}';
    final text = [
          'CFO View',
          '',
          'Recommendation:',
          recommendation,
          '',
          'Risk:',
          result.riskLevel.name.toUpperCase(),
          '',
          'Missing Information:',
          missing,
          '',
          'Next Question:',
          result.nextQuestion ??
              'No further question. Review the scenarios before acting.',
          '',
          'Rationale:',
          result.rationaleSummary,
        ].join('\n') +
        shipmentText +
        scenarioText;

    return AiAdvisorResponse(
      mode: AiAdvisorMode.advice,
      text: text,
      memory: _memory.copyWith(
        latestTopic: 'cfo_decision',
        missingData: result.missingInputs,
      ),
      suggestedReplies: result.nextQuestion == null
          ? const [
              'Compare smaller option',
              'Explain cash risk',
              'Prepare a proposal',
            ]
          : const [
              'I have this number',
              'Use conservative assumption',
              'Cancel decision review',
            ],
      metadata: AiResponseMetadata.fromEvidence(evidence),
    );
  }

  String _scenarioLine(AiDecisionScenario scenario) {
    final revenue = scenario.estimatedRevenue == null
        ? 'unknown revenue'
        : 'revenue ${scenario.estimatedRevenue!.toStringAsFixed(2)}';
    final cost = scenario.estimatedCost == null
        ? 'unknown cost'
        : 'cost ${scenario.estimatedCost!.toStringAsFixed(2)}';
    final margin = scenario.margin == null
        ? 'unknown margin'
        : 'margin ${scenario.margin!.toStringAsFixed(1)}%';
    return '- ${scenario.title}: $revenue, $cost, $margin, risk ${scenario.riskLabel}.';
  }

  List<String> _shipmentDecisionLines(AiShipmentDecisionResult decision) {
    return [
      '- Expected revenue: ${decision.expectedRevenue.toStringAsFixed(2)}',
      '- Total landed cost: ${decision.totalLandedCost.toStringAsFixed(2)}',
      '- Expected profit: ${decision.expectedProfit.toStringAsFixed(2)}',
      '- Margin: ${decision.marginPercent.toStringAsFixed(2)}%',
      '- Break-even point: ${decision.breakEvenPointUnits} units',
      '- Risk level: ${decision.riskLabel}',
      '- Assumptions: ${decision.assumptions.join('; ')}',
      '- Evidence: ${decision.evidence.join('; ')}',
      '- Confidence: ${decision.confidence.name.toUpperCase()}',
      '- Recommended action: ${decision.recommendedAction}',
    ];
  }

  Map<AiDecisionInputField, dynamic> _decisionSeedInputs(
    String userText,
    AiFinancialDecisionType decisionType,
  ) {
    final number = _firstNumber(_normalized(userText));
    if (number == null) return const {};
    switch (decisionType) {
      case AiFinancialDecisionType.inventoryPurchase:
      case AiFinancialDecisionType.reorderInventory:
      case AiFinancialDecisionType.importShipment:
      case AiFinancialDecisionType.stockIncrease:
      case AiFinancialDecisionType.dealProfitability:
      case AiFinancialDecisionType.unknown:
        return {AiDecisionInputField.quantity: number};
      case AiFinancialDecisionType.pricingChange:
        return {AiDecisionInputField.proposedPrice: number};
      case AiFinancialDecisionType.customerCreditSale:
        return const {};
    }
  }

  AiFinancialDecisionType _decisionTypeFromName(String name) {
    return AiFinancialDecisionType.values.firstWhere(
      (value) => value.name == name,
      orElse: () => AiFinancialDecisionType.unknown,
    );
  }

  String _decorateWorkflowResponse(AiWorkflowTurnResult result) {
    final session = result.session;
    if (session == null || session.isComplete) return result.responseText;
    final recentProducts = _businessMemoryManager.memory.recentProducts;
    final rememberedProduct =
        recentProducts.isEmpty ? null : recentProducts.first;
    if (session.waitingField == AiWorkflowField.product &&
        rememberedProduct != null) {
      return '${result.responseText}\nهل تقصد المنتج الذي ناقشناه سابقاً: $rememberedProduct؟ إذا نعم، اكتب اسمه أو أعد تأكيده.';
    }
    return result.responseText;
  }

  Future<AiAdvisorResponse?> _tryGenerateLlmResponse({
    required String userText,
    required AiToolPlan plan,
    required AiEvidenceBundle evidence,
    required AiFinancialSnapshot? snapshot,
    required List<AiFinancialInsight> insights,
    required List<AiFinancialRisk> risks,
    required List<AiFinancialRecommendation> recommendations,
    required AiProposalModel? activeProposal,
  }) async {
    const apiKey = String.fromEnvironment(
      'GEMINI_API_KEY',
      defaultValue: 'MOCK_INJECTED_KEY',
    );
    if (apiKey == 'MOCK_INJECTED_KEY') return null;

    try {
      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: apiKey,
        generationConfig:
            GenerationConfig(responseMimeType: 'application/json'),
        systemInstruction: Content.system(_systemInstruction),
      );
      final response = await model.generateContent([
        Content.text(_buildPrompt(
          userText: userText,
          plan: plan,
          evidence: evidence,
          snapshot: snapshot,
          insights: insights,
          risks: risks,
          recommendations: recommendations,
          activeProposal: activeProposal,
        )),
      ]);
      final raw = response.text;
      if (raw == null || raw.trim().isEmpty) return null;
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return _responseFromJson(decoded);
    } catch (e, stack) {
      debugPrint('[AiConversationOrchestrator] LLM fallback used: $e');
      debugPrint('$stack');
      return null;
    }
  }

  AiAdvisorResponse _fallbackResponse(
    String normalized,
    AiToolPlan plan,
    AiEvidenceBundle evidence,
  ) {
    if (_containsAny(
        normalized, ['hello', 'hi', 'hey', 'مرحبا', 'اهلا', 'اهلاً'])) {
      final isArabic = _isArabic;
      return AiAdvisorResponse(
        mode: AiAdvisorMode.chat,
        text: isArabic
            ? 'مرحبًا. أقدر أساعدك في تسعير الشحنات، اختبار قرارات التصدير، مراجعة الربحية، أو تحضير عمليات محاسبة للمراجعة. قولي أي قرار عايز تناقشه؟'
            : 'Welcome. I can help you price shipments, test export decisions, review profitability, think through inventory and customer balances, or prepare accounting operations for review. Tell me what decision is in front of you.',
        suggestedReplies: const [
          'Price a shipment',
          'Review profitability',
          'Prepare a purchase',
        ],
        memory: _memory,
      );
    }
    if (_containsAny(normalized, [
      'how can you help',
      'what can you do',
      'كيف تقدر تساعدني',
      'ماذا تفعل'
    ])) {
      return AiAdvisorResponse(
        mode: AiAdvisorMode.advice,
        text: _isArabic
            ? 'أقدر أشتغل معاك بطريقة عملية: أولاً نضبط القرار المالي، بعدين نجمع البيانات اللي محتاجها، نقارن البدائل، وبعدين نجهّز مقترح شراء أو فاتورة أو تسعير للمراجعة لو اشتريت. ما في أي حفظ أو تسجيل حتى توافق على المقترح.'
            : 'I can work with you in a practical flow: first we clarify the business decision, then collect the numbers that matter, compare trade-offs, and only then prepare a reviewable purchase, sale, or pricing proposal if you want one. Nothing is posted to the books from discussion alone.',
        suggestedReplies: const [
          'Price a shipment',
          'Compare three scenarios',
          'Analyze inventory risk',
        ],
        memory: _memory,
      );
    }
    if (_containsAny(
        normalized, ['scenario', 'compare', 'balanced', 'سيناريو', 'قارن'])) {
      return _scenarioResponse();
    }
    if (_containsAny(normalized,
        ['export', 'saudi', 'shipping', 'customs', 'تصدير', 'شحنة', 'سعودي'])) {
      final isArabic = _isArabic;
      final product =
          _memory.currentProduct ?? (isArabic ? 'المنتج' : 'the product');
      final destination = _memory.currentDestination ??
          (isArabic ? 'الوجهة' : 'the destination');
      return AiAdvisorResponse(
        mode: AiAdvisorMode.export,
        text: isArabic
            ? 'طيب. لتصدير $product لـ $destination، رح أبني القرار حول أربع أرقام: تكلفة الكرتون، تكلفة الشحن، الجمارك، وسعر البيع المستهدف. تكلفة الكرتون هي الحد الأدنى، والشحن والجمارك يوضحان التكلفة الحقيقية، والهدف التسويقي يحدد إذا ندخل بحذر أو نحمي الهامش.'
            : 'Good. For exporting $product to $destination, I would build the decision around four numbers: carton cost, shipping allocation, customs/import fees, and the target selling price. Carton cost tells us the floor, shipping and customs reveal the real landed cost, and your market goal tells us whether to enter carefully or protect margin.',
        suggestedReplies: const [
          'Carton cost is 45 dollars',
          'Compare three scenarios',
          'My goal is fast market entry',
        ],
        memory: _memory.copyWith(
          missingData: _missing(['cost', 'shipping', 'customs', 'goal']),
        ),
      );
    }
    if (_containsAny(
        normalized, ['margin', '25%', 'percent', 'هامش', 'نسبة'])) {
      return AiAdvisorResponse(
        mode: AiAdvisorMode.pricing,
        text: _isArabic
            ? '25% ممكن يكون ملائم، لكن القرار يعتمد على استقرار الطلب، أسعار المنافسين، ومدى عدم اليقين في الشحن، الجمارك، المرتجعات، وتوقيت الدفع. لسوق جديد ما بفضل 25% كقيمة ثابتة؛ الأفضل مقارنة الخيارات الكونسرفاتيف، الBalanced، والAggressive.'
            : '25% can be suitable, but it depends on demand stability, competitor pricing, and how much uncertainty sits in shipping, customs, returns, and payment timing. For a new market I would not treat 25% as automatically right; I would compare conservative, balanced, and aggressive paths first.',
        decisionOptions: _scenarioOptions(),
        suggestedReplies: const [
          'Use balanced scenario',
          'Show risks',
          'Prepare pricing simulation',
        ],
        memory: _memory,
      );
    }
    if (_firstNumber(normalized) != null && _memory.currentProduct != null) {
      final amount = _firstNumber(normalized)!;
      _memory = _memory.copyWith(currentCost: amount);
      return AiAdvisorResponse(
        mode: AiAdvisorMode.pricing,
        text: _isArabic
            ? 'فهمت. هأعامل ${amount.toStringAsFixed(2)} كتكلفة حالية للمنتج ${_memory.currentProduct}. عشان أحوله لنصيحة تسعير مفيدة، لازم أعرف تكلفة الشحن، الجمارك، العملة، وإذا كنت تفضل دخول السوق بسرعة ولا تحافظ على هامش.'
            : 'Got it. I will treat ${amount.toStringAsFixed(2)} as the current cost for ${_memory.currentProduct}. To turn that into useful pricing advice, I still need shipping, customs or import fees, currency, and whether you want faster entry or stronger margin.',
        suggestedReplies: const [
          'Shipping is 1200 dollars',
          'Customs are 300 dollars',
          'Compare three scenarios',
        ],
        memory: _memory.copyWith(
          missingData: _missing(['shipping', 'customs', 'goal']),
        ),
      );
    }
    if (plan.requiresTools) {
      return AiAdvisorResponse(
        mode: AiAdvisorMode.analysis,
        text: FinancialReasoningEngine().buildGroundedResponse(
          plan: plan,
          evidence: evidence,
        ),
        suggestedReplies: const [
          'Explain the risk',
          'Compare options',
          'Prepare a proposal',
        ],
        memory: _memory,
      );
    }
    if (plan.intent == AiAccountantIntent.purchasePreparation ||
        plan.intent == AiAccountantIntent.salePreparation) {
      return AiAdvisorResponse(
        mode: AiAdvisorMode.proposalReview,
        text: FinancialReasoningEngine().buildGroundedResponse(
          plan: plan,
          evidence: evidence,
        ),
        suggestedReplies: plan.intent == AiAccountantIntent.purchasePreparation
            ? const [
                'Product and quantity',
                'Add unit cost',
                'Explain purchase impact',
              ]
            : const [
                'Product and quantity',
                'Add selling price',
                'Explain sale impact',
              ],
        memory: _memory.copyWith(missingData: plan.missingInputs),
      );
    }
    if (plan.intent == AiAccountantIntent.pricingDecision ||
        plan.intent == AiAccountantIntent.exportDecision) {
      return AiAdvisorResponse(
        mode: plan.intent == AiAccountantIntent.exportDecision
            ? AiAdvisorMode.export
            : AiAdvisorMode.pricing,
        text: FinancialReasoningEngine().buildGroundedResponse(
          plan: plan,
          evidence: evidence,
        ),
        suggestedReplies: const [
          'Explain the risk',
          'Compare options',
          'Prepare a proposal',
        ],
        memory: _memory,
      );
    }
    if (plan.intent == AiAccountantIntent.purchasePreparation ||
        plan.intent == AiAccountantIntent.salePreparation) {
      return AiAdvisorResponse(
        mode: AiAdvisorMode.proposalReview,
        text: FinancialReasoningEngine().buildGroundedResponse(
          plan: plan,
          evidence: evidence,
        ),
        suggestedReplies: plan.intent == AiAccountantIntent.purchasePreparation
            ? const [
                'Product and quantity',
                'Add unit cost',
                'Explain purchase impact',
              ]
            : const [
                'Product and quantity',
                'Add selling price',
                'Explain sale impact',
              ],
        memory: _memory.copyWith(missingData: plan.missingInputs),
      );
    }
    if (plan.intent == AiAccountantIntent.pricingDecision ||
        plan.intent == AiAccountantIntent.exportDecision) {
      return AiAdvisorResponse(
        mode: plan.intent == AiAccountantIntent.exportDecision
            ? AiAdvisorMode.export
            : AiAdvisorMode.pricing,
        text: FinancialReasoningEngine().buildGroundedResponse(
          plan: plan,
          evidence: evidence,
        ),
        decisionOptions: plan.intent == AiAccountantIntent.pricingDecision
            ? _scenarioOptions()
            : const [],
        suggestedReplies: const [
          'Compare three scenarios',
          'Share missing costs',
          'Prepare pricing simulation',
        ],
        memory: _memory.copyWith(missingData: plan.missingInputs),
      );
    }
    return AiAdvisorResponse(
      mode: AiAdvisorMode.advice,
      text: _profitabilityFallback(normalized),
      suggestedReplies: const [
        'Price a shipment',
        'Review profitability',
        'Analyze inventory risk',
      ],
      memory: _memory,
    );
  }

  String _profitabilityFallback(String normalized) {
    if (_containsAny(normalized,
        ['ربح', 'ربحي', 'ربحية', 'profit', 'profitability', 'today'])) {
      return _isArabic
          ? 'فهمت عليك. أقدر أساعدك في تقييم الربح، لكن حاليًا أحتاج بيانات بيع وتكلفة ومصروفات كافية حتى أعطيك رقمًا موثوقًا. أفضل خطوة الآن أن تسجل عملية بيع أو ترفع فاتورة/مصروف مرتبط بها، وبعدها أقدر أراجع الربحية بشكل أدق.'
          : 'I understand you want to check profitability, but I do not have enough reliable sales, cost, and expense data yet to give you a trustworthy number. Best next step is to record a sale or add an invoice/expense tied to it, then I can review profit more precisely.';
    }
    return _isArabic
        ? 'أقدر أساعدك، لكن أحتاج أولاً أعرف المجال المالي: تسعير، تصدير، ربحية، مخزون، أرصدة عملاء، تدفق نقدي، أو تحضير عملية شراء أو بيع للمراجعة. اختر واحد وأنا أقودك بالخطوة التالية.'
        : 'I can help, but I need to know the business area first: pricing, export, profitability, inventory, customer balances, cash flow, or preparing a purchase or sale for review. Pick one and I will guide the next step.';
  }

  AiAdvisorResponse _scenarioResponse() {
    return AiAdvisorResponse(
      mode: AiAdvisorMode.pricing,
      text: _isArabic
          ? 'ها هي الخطوط الثلاث اللي رح أقارن بينها. الاختيار الصح الأنسب يعتمد على إذا كنت تحتاج دخول السوق، مبيعات مستمرة متوسطة، ولا هامش قصوى.'
          : 'Here are the three paths I would compare. The right choice depends on whether you need market entry, balanced repeat sales, or maximum margin.',
      decisionOptions: _scenarioOptions(),
      suggestedReplies: const [
        'Use balanced scenario',
        'Prepare pricing simulation',
        'Review profitability',
      ],
      memory: _memory,
    );
  }

  List<AiDecisionOption> _scenarioOptions() {
    return const [
      AiDecisionOption(
        title: 'Conservative',
        recommendation: 'Use a lower margin direction, usually 15-18%.',
        advantage: 'Easier first orders and faster customer testing.',
        risk: 'Thin buffer if shipping, returns, or discounts increase.',
        whenToUse: 'Use it for first market entry or distributor adoption.',
      ),
      AiDecisionOption(
        title: 'Balanced',
        recommendation: 'Use a middle margin direction, usually 22-25%.',
        advantage: 'Protects profit while staying realistic for repeat sales.',
        risk: 'Can be too average if competitors discount aggressively.',
        whenToUse: 'Use it when demand is stable and you want durable pricing.',
      ),
      AiDecisionOption(
        title: 'Aggressive',
        recommendation: 'Use a higher margin direction, often 30%+.',
        advantage: 'Stronger profit per unit.',
        risk: 'Slower sales and more rejection from price-sensitive buyers.',
        whenToUse: 'Use it when quality, scarcity, or urgency supports price.',
      ),
    ];
  }

  AiAdvisorResponse _executionGuardResponse(AiProposalModel? activeProposal) {
    if (activeProposal == null) {
      return AiAdvisorResponse(
        mode: AiAdvisorMode.executionGuard,
        text: _isArabic
            ? 'أنا هنا أساعدك تتخذ قرار مالي مدروس، مش أنفّذ عليك عمليات. استخدم أمر "تحضير" عشان أجهّز مقترح، و"وافق" لو أضفيت موافقتك على المقترح الجاهز.'
            : 'I need a clear proposal before execution. Do you want to prepare a purchase, sale, or pricing simulation?',
        suggestedReplies: const [
          'Prepare a purchase',
          'Prepare a sale',
          'Run pricing simulation',
        ],
        memory: _memory,
      );
    }
    return AiAdvisorResponse(
      mode: AiAdvisorMode.proposalReview,
      text: _isArabic
          ? 'عندك مقترح ${activeProposal.actionType} فعال. راجع الكرت أولاً، وإذا كان صحيح، وافق عليه من خلال تدفق الموافقة الحالي.'
          : 'There is an active ${activeProposal.actionType} proposal. Review the card first; if it is correct, approve it through the existing confirmation flow.',
      suggestedReplies: const ['Approve', 'Change details', 'Explain impact'],
      memory: _memory,
    );
  }

  AiAdvisorResponse _responseFromJson(Map<String, dynamic> json) {
    final decisionOptions = (json['decisionOptions'] is List)
        ? (json['decisionOptions'] as List)
            .whereType<Map>()
            .map((row) =>
                AiDecisionOption.fromMap(Map<String, dynamic>.from(row)))
            .toList()
        : <AiDecisionOption>[];
    final replies = (json['suggestedReplies'] is List)
        ? (json['suggestedReplies'] as List)
            .map((row) => row.toString())
            .toList()
        : <String>[];
    final mode = AiAdvisorMode.values.firstWhere(
      (value) => value.name == json['mode']?.toString(),
      orElse: () => AiAdvisorMode.advice,
    );
    final text = json['text']?.toString().trim();
    if (text == null || text.isEmpty) {
      throw const FormatException('LLM response missing text');
    }
    return AiAdvisorResponse(
      mode: mode,
      text: text,
      suggestedReplies: replies,
      decisionOptions: decisionOptions,
      memory: _memory,
      shouldPrepareProposal: json['shouldPrepareProposal'] == true,
    );
  }

  void _remember(String text, {AiProposalModel? activeProposal}) {
    if (activeProposal != null) rememberProposal(activeProposal);
    final normalized = _normalized(text);
    final product = _extractProduct(normalized);
    final destination = _extractDestination(normalized);
    final margin = _extractMargin(normalized);
    final number = _firstNumber(normalized);
    _memory = _memory.copyWith(
      currentProduct: product,
      currentDestination: destination,
      currentMargin: margin,
      currentCost: number != null && margin == null ? number : null,
      latestTopic: _topicFor(normalized),
    );
  }

  void _rememberAssistant(AiAdvisorResponse response) {
    _history.add(AiConversationTurn(
      role: 'assistant',
      text: response.text,
      timestamp: DateTime.now(),
    ));
  }

  String _buildPrompt({
    required String userText,
    required AiToolPlan plan,
    required AiEvidenceBundle evidence,
    required AiFinancialSnapshot? snapshot,
    required List<AiFinancialInsight> insights,
    required List<AiFinancialRisk> risks,
    required List<AiFinancialRecommendation> recommendations,
    required AiProposalModel? activeProposal,
  }) {
    return jsonEncode({
      'userText': userText,
      'memory': _memory.toJson(),
      'businessMemory': {
        'summary': _businessMemoryManager.summarizeSafely(),
        'facts': _businessMemoryManager.memory.toSafeJson(),
      },
      'activeProposal': activeProposal?.toMap(),
      'toolPlan': {
        'intent': plan.intent.name,
        'requiresTools': plan.requiresTools,
        'steps': plan.steps
            .map((step) => {
                  'toolName': step.toolName,
                  'reason': step.reason,
                  'required': step.required,
                  'parameters': step.parameters,
                })
            .toList(),
        'missingInputs': plan.missingInputs,
        'safetyLevel': plan.safetyLevel.name,
      },
      'evidence': evidence.toJson(),
      'financialSnapshot': snapshot == null
          ? null
          : {
              'revenue': snapshot.revenue,
              'expenses': snapshot.expenses,
              'profit': snapshot.profit,
              'pendingInvoices': snapshot.pendingInvoices,
              'overdueInvoices': snapshot.overdueInvoices,
              'inventoryHealth': snapshot.inventoryHealth,
              'lowStockProducts': snapshot.lowStockProducts,
              'customerRisk': snapshot.customerRisk,
              'confidence': snapshot.confidence.name,
              'missingData': snapshot.missingData,
            },
      'generatedInsights': insights
          .map((insight) => {
                'category': insight.category.name,
                'title': insight.title,
                'description': insight.description,
              })
          .toList(),
      'detectedRisks': risks
          .map((risk) => {
                'level': risk.level.name,
                'title': risk.title,
                'description': risk.description,
              })
          .toList(),
      'generatedRecommendations': recommendations
          .map((recommendation) => {
                'title': recommendation.title,
                'description': recommendation.description,
              })
          .toList(),
      'recentHistory': _history.take(12).map((turn) => turn.toJson()).toList(),
      'responseContract': {
        'mode':
            'chat|advice|pricing|export|analysis|proposalReview|executionGuard',
        'text': 'natural advisor response',
        'suggestedReplies': ['short action chips'],
        'decisionOptions': [
          {
            'title': 'Conservative',
            'recommendation': '',
            'advantage': '',
            'risk': '',
            'whenToUse': '',
          }
        ],
        'shouldPrepareProposal': false,
      },
    });
  }

  static const String _systemInstruction = '''
You are a senior Arabic/English financial advisor and accountant for HASOOB.
Speak naturally, calmly, and practically.
Ask follow-up questions when information is missing.
Challenge weak assumptions and explain trade-offs.
Offer conservative, balanced, and aggressive scenarios when useful.
Never claim facts without data.
Clearly separate advice from confirmed system data.
Never execute purchases, sales, pricing simulations, or database mutations.
If the user wants execution, require a reviewable proposal and explicit confirmation.
Return only JSON matching the response contract.
''';

  List<String> _missing(List<String> candidates) {
    return candidates.where((item) {
      return switch (item) {
        'cost' => _memory.currentCost == null,
        'margin' => _memory.currentMargin == null,
        'shipping' => true,
        'customs' => true,
        'goal' => true,
        _ => true,
      };
    }).toList();
  }

  AiAdvisorResponse? _tryHandleLocalAccountingMessage(
    String input,
    String normalized,
  ) {
    final localSale = _parseLocalSale(input, normalized);
    if (localSale != null) return _localSaleResponse(localSale);

    final localExpense = _parseLocalExpense(input, normalized);
    if (localExpense != null) return _localExpenseResponse(localExpense);

    return null;
  }

  _LocalSaleAnalysis? _parseLocalSale(String input, String normalized) {
    final isSale = _containsAnyLocalAccountingTerm(normalized, [
      'sold',
      'sale',
      'sales',
      'بيع',
      'بعت',
      'مبيعات',
    ]);
    if (!isSale) return null;

    final numbers = _numberMatches(input);
    final quantity = _numberAfterAny(input, [
          'qty',
          'quantity',
          'عدد',
          'كمية',
        ]) ??
        _numberBeforeAny(input, [
          'unit',
          'units',
          'item',
          'items',
          'box',
          'boxes',
          'piece',
          'pieces',
          'قطعة',
          'قطع',
          'كرتون',
          'كراتين',
          'منتج',
          'منتجات',
        ]) ??
        (numbers.length >= 2 ? numbers.first.value : null);

    final sellingPrice = _numberAfterAny(input, [
          'at',
          'for',
          'price',
          'بسعر',
          'سعر',
        ]) ??
        (numbers.length >= 2 ? numbers[1].value : null);

    final unitCost = _numberAfterAny(input, [
      'cost',
      'تكلفة',
      'تكلفتها',
      'وتكلفتها',
    ]);

    if (quantity == null && sellingPrice == null && unitCost == null) {
      return null;
    }

    return _LocalSaleAnalysis(
      isArabic: _containsArabic(input),
      quantity: quantity,
      sellingPrice: sellingPrice,
      unitCost: unitCost,
    );
  }

  _LocalExpenseAnalysis? _parseLocalExpense(String input, String normalized) {
    final isExpense = _containsAnyLocalAccountingTerm(normalized, [
      'expense',
      'paid',
      'pay supplier',
      'paid supplier',
      'rent',
      'shipping',
      'electricity',
      'marketing',
      'مصروف',
      'دفعت',
      'سجل',
      'إيجار',
      'ايجار',
      'شحن',
      'كهرباء',
      'تسويق',
      'مورد',
    ]);
    if (!isExpense) return null;

    final numbers = _numberMatches(input);
    final amount = _numberAfterAny(input, [
          'expense',
          'paid',
          'rent',
          'shipping',
          'electricity',
          'marketing',
          'supplier',
          'مصروف',
          'دفعت',
          'إيجار',
          'ايجار',
          'شحن',
          'كهرباء',
          'تسويق',
          'مورد',
        ]) ??
        (numbers.isEmpty ? null : numbers.last.value);
    final category = _expenseCategory(input);

    if (amount == null && category == null) return null;

    return _LocalExpenseAnalysis(
      isArabic: _containsArabic(input),
      amount: amount,
      category: category,
    );
  }

  AiAdvisorResponse _localSaleResponse(_LocalSaleAnalysis sale) {
    final missing = <String>[
      if (sale.quantity == null) sale.isArabic ? 'الكمية' : 'quantity',
      if (sale.sellingPrice == null)
        sale.isArabic ? 'سعر البيع' : 'selling price',
      if (sale.unitCost == null) sale.isArabic ? 'تكلفة الوحدة' : 'unit cost',
    ];
    final canComputeRevenue =
        sale.quantity != null && sale.sellingPrice != null;
    final revenue =
        canComputeRevenue ? sale.quantity! * sale.sellingPrice! : null;
    final totalCost = revenue != null && sale.unitCost != null
        ? sale.quantity! * sale.unitCost!
        : null;
    final profit = totalCost != null ? revenue! - totalCost : null;
    final margin = profit != null && revenue != null && revenue > 0
        ? (profit / revenue) * 100
        : null;

    final text = sale.isArabic
        ? _arabicSaleText(
            sale: sale,
            revenue: revenue,
            totalCost: totalCost,
            profit: profit,
            margin: margin,
          )
        : _englishSaleText(
            sale: sale,
            revenue: revenue,
            totalCost: totalCost,
            profit: profit,
            margin: margin,
          );

    return AiAdvisorResponse(
      mode: AiAdvisorMode.advice,
      text: text,
      memory: _memory.copyWith(
        latestTopic: 'local_sale_analysis',
        missingData: missing,
      ),
      suggestedReplies: sale.unitCost == null
          ? const ['Add unit cost', 'Prepare review draft', 'Explain margin']
          : const ['Prepare review draft', 'Explain profit', 'Analyze expense'],
      metadata: AiResponseMetadata.low(missingEvidence: missing),
    );
  }

  AiAdvisorResponse _localExpenseResponse(_LocalExpenseAnalysis expense) {
    final missing = <String>[
      if (expense.amount == null) expense.isArabic ? 'المبلغ' : 'amount',
      if (expense.category == null) expense.isArabic ? 'التصنيف' : 'category',
    ];
    final text = _expenseCommandCardText(expense, missing);

    return AiAdvisorResponse(
      mode: AiAdvisorMode.advice,
      text: text,
      memory: _memory.copyWith(
        latestTopic: 'local_expense_analysis',
        missingData: missing,
      ),
      suggestedReplies: const [
        'Prepare review draft',
        'Add missing details',
        'Analyze sale',
      ],
      metadata: AiResponseMetadata.low(missingEvidence: missing),
    );
  }

  String _expenseCommandCardText(
    _LocalExpenseAnalysis expense,
    List<String> missing,
  ) {
    final categoryArabic = expense.category?.arabic;
    final categoryEnglish = expense.category?.english;
    if (expense.isArabic) {
      return [
        'تم تفسير الأمر كمصروف.',
        '',
        'ملخص المصروف:',
        '',
        if (categoryArabic != null) '* التصنيف: $categoryArabic',
        if (expense.amount != null)
          '* المبلغ: ${_formatNumber(expense.amount!)}',
        if (missing.isNotEmpty) ...[
          '',
          'البيانات الناقصة:',
          '',
          if (categoryArabic == null) '* التصنيف',
          if (expense.amount == null) '* المبلغ',
        ],
        '',
        'الحالة:',
        missing.isEmpty
            ? 'مسودة بانتظار المراجعة.'
            : 'تحتاج بيانات قبل تجهيز مسودة دقيقة للمراجعة.',
        '',
        'الخطوة التالية:',
        missing.isEmpty
            ? 'يمكن تجهيز مسودة مصروف، ولن يتم تسجيلها قبل الاعتماد.'
            : 'أرسل البيانات الناقصة، ولن يتم تسجيل أي شيء قبل الاعتماد.',
      ].join('\n');
    }

    return [
      'Command interpreted as an expense.',
      '',
      'Expense summary:',
      '',
      if (categoryEnglish != null)
        '* Category: ${_capitalize(categoryEnglish)}',
      if (expense.amount != null) '* Amount: ${_formatNumber(expense.amount!)}',
      if (missing.isNotEmpty) ...[
        '',
        'Missing data:',
        '',
        if (categoryEnglish == null) '* Category',
        if (expense.amount == null) '* Amount',
      ],
      '',
      'Status:',
      missing.isEmpty
          ? 'Reviewable draft.'
          : 'Needs more data before a reliable review draft.',
      '',
      'Next action:',
      missing.isEmpty
          ? 'Prepare an expense draft. Nothing will be posted before approval.'
          : 'Send the missing data. Nothing will be posted before approval.',
    ].join('\n');
  }

  // ignore: unused_element
  AiAdvisorResponse _localExpenseResponseLegacy(_LocalExpenseAnalysis expense) {
    final missing = <String>[
      if (expense.amount == null) expense.isArabic ? 'المبلغ' : 'amount',
      if (expense.category == null) expense.isArabic ? 'التصنيف' : 'category',
    ];
    final categoryArabic = expense.category?.arabic;
    final categoryEnglish = expense.category?.english;
    final text = expense.isArabic
        ? [
            if (expense.amount != null && categoryArabic != null)
              'تم فهم مصروف $categoryArabic بقيمة ${_formatNumber(expense.amount!)}.'
            else if (expense.amount != null)
              'تم فهم مصروف بقيمة ${_formatNumber(expense.amount!)}.'
            else if (categoryArabic != null)
              'تم فهم مصروف $categoryArabic، لكن المبلغ غير موجود.',
            if (expense.amount == null)
              'أرسل مبلغ المصروف حتى أستطيع تجهيز مسودة للمراجعة.',
            if (categoryArabic == null)
              'أرسل تصنيف المصروف مثل شحن، إيجار، كهرباء، تسويق، أو مورد.',
            if (expense.amount != null && categoryArabic != null)
              'أستطيع تجهيزه كمسودة مصروف للمراجعة، ولن يتم تسجيله قبل الاعتماد.',
          ].whereType<String>().join('\n')
        : [
            if (expense.amount != null && categoryEnglish != null)
              '${_capitalize(categoryEnglish)} expense understood for ${_formatNumber(expense.amount!)}.'
            else if (expense.amount != null)
              'Expense understood for ${_formatNumber(expense.amount!)}.'
            else if (categoryEnglish != null)
              '${_capitalize(categoryEnglish)} expense understood, but the amount is missing.',
            if (expense.amount == null)
              'Send the expense amount so I can prepare it for review.',
            if (categoryEnglish == null)
              'Send the expense category, such as shipping, rent, electricity, marketing, or supplier.',
            if (expense.amount != null && categoryEnglish != null)
              'This can be prepared as an expense draft for review and will not be posted before approval.',
          ].whereType<String>().join('\n');

    return AiAdvisorResponse(
      mode: AiAdvisorMode.advice,
      text: text,
      memory: _memory.copyWith(
        latestTopic: 'local_expense_analysis',
        missingData: missing,
      ),
      suggestedReplies: const [
        'Prepare review draft',
        'Add missing details',
        'Analyze sale',
      ],
      metadata: AiResponseMetadata.low(missingEvidence: missing),
    );
  }

  String _arabicSaleText({
    required _LocalSaleAnalysis sale,
    required double? revenue,
    required double? totalCost,
    required double? profit,
    required double? margin,
  }) {
    final missingQuantity = sale.quantity == null;
    final missingPrice = sale.sellingPrice == null;
    final missingCost = sale.unitCost == null;
    return [
      'تم تفسير الأمر كعملية بيع.',
      '',
      'ملخص العملية:',
      '',
      if (sale.quantity != null) '* الكمية: ${_formatNumber(sale.quantity!)}',
      if (sale.sellingPrice != null)
        '* سعر البيع للوحدة: ${_formatNumber(sale.sellingPrice!)}',
      if (sale.unitCost != null)
        '* تكلفة الوحدة: ${_formatNumber(sale.unitCost!)}',
      if (revenue != null) ...[
        '',
        'النتيجة:',
        '',
        '* الإيراد: ${_formatNumber(revenue)}',
        if (totalCost != null) '* التكلفة: ${_formatNumber(totalCost)}',
        if (profit != null) '* الربح: ${_formatNumber(profit)}',
        if (margin != null) '* هامش الربح: ${_formatPercent(margin)}',
      ],
      if (missingQuantity || missingPrice || missingCost) ...[
        '',
        'البيانات الناقصة:',
        '',
        if (missingQuantity) '* الكمية',
        if (missingPrice) '* سعر البيع للوحدة',
        if (missingCost) '* تكلفة الوحدة أو ربط العملية بمنتج موجود',
      ],
      '',
      'الحالة:',
      if (!missingQuantity && !missingPrice && !missingCost)
        'جاهزة كمسودة للمراجعة.'
      else if (missingCost && !missingQuantity && !missingPrice)
        'تحتاج بيانات قبل حساب الربح بدقة.'
      else
        'تحتاج بيانات قبل تجهيز مسودة دقيقة للمراجعة.',
      '',
      'الخطوة التالية:',
      if (!missingQuantity && !missingPrice && !missingCost)
        'يمكن تجهيز مسودة بيع قبل أي تنفيذ.'
      else if (missingCost && !missingQuantity && !missingPrice)
        'أرسل تكلفة الوحدة أو اختر المنتج من المخزون.'
      else
        'أرسل البيانات الناقصة، ولن يتم تسجيل أي شيء قبل المراجعة والاعتماد.',
    ].join('\n');
  }

  String _englishSaleText({
    required _LocalSaleAnalysis sale,
    required double? revenue,
    required double? totalCost,
    required double? profit,
    required double? margin,
  }) {
    final missingQuantity = sale.quantity == null;
    final missingPrice = sale.sellingPrice == null;
    final missingCost = sale.unitCost == null;
    return [
      'Command interpreted as a sale.',
      '',
      'Operation summary:',
      '',
      if (sale.quantity != null) '* Quantity: ${_formatNumber(sale.quantity!)}',
      if (sale.sellingPrice != null)
        '* Unit selling price: ${_formatNumber(sale.sellingPrice!)}',
      if (sale.unitCost != null)
        '* Unit cost: ${_formatNumber(sale.unitCost!)}',
      if (revenue != null) ...[
        '',
        'Result:',
        '',
        '* Revenue: ${_formatNumber(revenue)}',
        if (totalCost != null) '* Cost: ${_formatNumber(totalCost)}',
        if (profit != null) '* Profit: ${_formatNumber(profit)}',
        if (margin != null) '* Profit margin: ${_formatPercent(margin)}',
      ],
      if (missingQuantity || missingPrice || missingCost) ...[
        '',
        'Missing data:',
        '',
        if (missingQuantity) '* Quantity',
        if (missingPrice) '* Unit selling price',
        if (missingCost) '* Unit cost or an existing linked product',
      ],
      '',
      'Status:',
      if (!missingQuantity && !missingPrice && !missingCost)
        'Ready as a reviewable draft.'
      else if (missingCost && !missingQuantity && !missingPrice)
        'Needs data before profit can be calculated accurately.'
      else
        'Needs more data before a reliable review draft.',
      '',
      'Next action:',
      if (!missingQuantity && !missingPrice && !missingCost)
        'Prepare a sale draft before execution.'
      else if (missingCost && !missingQuantity && !missingPrice)
        'Send the unit cost or choose the product from inventory.'
      else
        'Send the missing data. Nothing will be posted before review and approval.',
    ].join('\n');
  }

  // ignore: unused_element
  String _arabicSaleTextLegacy({
    required _LocalSaleAnalysis sale,
    required double? revenue,
    required double? totalCost,
    required double? profit,
    required double? margin,
  }) {
    if (sale.quantity == null || sale.sellingPrice == null) {
      return [
        'فهمت أنها عملية بيع، لكن البيانات غير كاملة.',
        if (sale.quantity == null) 'أرسل الكمية.',
        if (sale.sellingPrice == null) 'أرسل سعر البيع للوحدة.',
        'لن يتم تسجيل أي شيء قبل المراجعة والاعتماد.',
      ].join('\n');
    }
    if (sale.unitCost == null) {
      return [
        'تم فهم عملية بيع بإجمالي ${_formatNumber(revenue!)}.',
        'لا أستطيع حساب الربح لأن تكلفة الوحدة غير موجودة. أرسل تكلفة الوحدة أو اربط العملية بمنتج موجود.',
        'يمكن تجهيزها كمسودة للمراجعة قبل أي تنفيذ.',
      ].join('\n');
    }
    return [
      'تم تحليل عملية البيع:',
      'الإيراد: ${_formatNumber(revenue!)}',
      'التكلفة: ${_formatNumber(totalCost!)}',
      'الربح: ${_formatNumber(profit!)}',
      'هامش الربح: ${_formatPercent(margin!)}',
      'يمكن تجهيزها كمسودة للمراجعة قبل أي تنفيذ.',
    ].join('\n');
  }

  // ignore: unused_element
  String _englishSaleTextLegacy({
    required _LocalSaleAnalysis sale,
    required double? revenue,
    required double? totalCost,
    required double? profit,
    required double? margin,
  }) {
    if (sale.quantity == null || sale.sellingPrice == null) {
      return [
        'I understood this as a sale, but the details are incomplete.',
        if (sale.quantity == null) 'Send the quantity.',
        if (sale.sellingPrice == null) 'Send the selling price per unit.',
        'Nothing will be posted before review and approval.',
      ].join('\n');
    }
    if (sale.unitCost == null) {
      return [
        'Sale understood with total revenue ${_formatNumber(revenue!)}.',
        'I cannot calculate profit because unit cost is missing. Send the unit cost or link the sale to an existing product.',
        'This can be prepared as a reviewable draft before execution.',
      ].join('\n');
    }
    return [
      'Sale analyzed:',
      'Revenue: ${_formatNumber(revenue!)}',
      'Cost: ${_formatNumber(totalCost!)}',
      'Profit: ${_formatNumber(profit!)}',
      'Profit margin: ${_formatPercent(margin!)}',
      'This can be prepared as a reviewable draft before execution.',
    ].join('\n');
  }

  List<_LocalNumberMatch> _numberMatches(String text) {
    return RegExp(r'(\d+(?:[.,]\d+)?)')
        .allMatches(text)
        .map((match) => _LocalNumberMatch(
              value: double.parse(match.group(1)!.replaceAll(',', '.')),
              start: match.start,
            ))
        .toList();
  }

  double? _numberAfterAny(String text, List<String> keywords) {
    final lower = text.toLowerCase();
    _LocalNumberMatch? best;
    for (final keyword in keywords) {
      final index = lower.indexOf(keyword.toLowerCase());
      if (index < 0) continue;
      for (final number in _numberMatches(text)) {
        if (number.start < index) continue;
        if (best == null || number.start < best.start) best = number;
      }
    }
    return best?.value;
  }

  double? _numberBeforeAny(String text, List<String> keywords) {
    final lower = text.toLowerCase();
    for (final keyword in keywords) {
      final index = lower.indexOf(keyword.toLowerCase());
      if (index < 0) continue;
      final before = _numberMatches(text)
          .where((number) => number.start < index)
          .toList(growable: false);
      if (before.isNotEmpty) return before.last.value;
    }
    return null;
  }

  _LocalExpenseCategory? _expenseCategory(String text) {
    final normalized = _normalized(text);
    const categories = [
      _LocalExpenseCategory(
        arabic: 'شحن',
        english: 'shipping',
        tokens: ['shipping', 'freight', 'شحن'],
      ),
      _LocalExpenseCategory(
        arabic: 'إيجار',
        english: 'rent',
        tokens: ['rent', 'إيجار', 'ايجار'],
      ),
      _LocalExpenseCategory(
        arabic: 'كهرباء',
        english: 'electricity',
        tokens: ['electricity', 'power', 'كهرباء'],
      ),
      _LocalExpenseCategory(
        arabic: 'تسويق',
        english: 'marketing',
        tokens: ['marketing', 'ads', 'advertising', 'تسويق'],
      ),
      _LocalExpenseCategory(
        arabic: 'مورد',
        english: 'supplier',
        tokens: ['supplier', 'vendor', 'مورد'],
      ),
    ];
    for (final category in categories) {
      if (_containsAnyLocalAccountingTerm(normalized, category.tokens)) {
        return category;
      }
    }
    return null;
  }

  bool _containsAnyLocalAccountingTerm(String normalized, List<String> terms) {
    return terms.any((term) => _containsLocalAccountingTerm(normalized, term));
  }

  bool _containsLocalAccountingTerm(String normalized, String term) {
    if (_containsArabic(term)) return normalized.contains(term);
    final escaped = RegExp.escape(term.toLowerCase());
    return RegExp('(^|[^a-z0-9])$escaped([^a-z0-9]|\$)').hasMatch(normalized);
  }

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(2);
  }

  String _formatPercent(double value) {
    if (value == value.roundToDouble()) return '${value.toStringAsFixed(0)}%';
    return '${value.toStringAsFixed(1)}%';
  }

  String _capitalize(String value) {
    if (value.isEmpty) return value;
    return '${value[0].toUpperCase()}${value.substring(1)}';
  }

  bool isExecutionIntent(String normalized) {
    return _containsAny(normalized, [
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
      'حولها',
    ]);
  }

  bool _isClearTransactionCommand(String normalized) {
    return _containsAny(normalized, [
      'bought',
      'purchased',
      'sold',
      'sale',
      'purchase',
      'invoice',
      'pricing simulation',
      'اشتريت',
      'شراء',
      'بعت',
      'بيع',
      'فاتورة',
    ]);
  }

  bool _isPreparationRequest(String normalized) {
    return _containsAny(normalized, [
      'prepare',
      'proposal',
      'simulate',
      'جهز',
      'حضر',
      'مقترح',
    ]);
  }

  bool _containsAny(String value, List<String> needles) {
    return needles.any(value.contains);
  }

  String _normalized(String value) => value.toLowerCase().trim();

  String? _topicFor(String normalized) {
    if (_containsAny(normalized, ['export', 'saudi', 'shipping'])) {
      return 'export';
    }
    if (_containsAny(normalized, ['price', 'pricing', 'margin'])) {
      return 'pricing';
    }
    if (_containsAny(normalized, ['inventory', 'stock'])) return 'inventory';
    if (_containsAny(normalized, ['customer', 'balance'])) return 'customer';
    if (_containsAny(normalized, ['cash', 'invoice'])) return 'cashflow';
    return _memory.latestTopic;
  }

  String? _extractProduct(String normalized) {
    const products = {
      'chocolate': 'chocolate',
      'شوكولاتة': 'chocolate',
      'شوكولاته': 'chocolate',
    };
    for (final entry in products.entries) {
      if (normalized.contains(entry.key)) return entry.value;
    }
    return null;
  }

  String? _extractDestination(String normalized) {
    if (normalized.contains('saudi') || normalized.contains('السعودية')) {
      return 'Saudi Arabia';
    }
    if (normalized.contains('turkey') || normalized.contains('تركيا')) {
      return 'Turkey';
    }
    if (normalized.contains('afghanistan') ||
        normalized.contains('أفغانستان')) {
      return 'Afghanistan';
    }
    return null;
  }

  double? _extractMargin(String normalized) {
    if (!normalized.contains('%') &&
        !normalized.contains('percent') &&
        !normalized.contains('margin') &&
        !normalized.contains('هامش')) {
      return null;
    }
    return _firstNumber(normalized);
  }

  double? _firstNumber(String text) {
    final match = RegExp(r'(\d+(?:[.,]\d+)?)').firstMatch(text);
    if (match == null) return null;
    return double.tryParse(match.group(1)!.replaceAll(',', '.'));
  }

  static bool _containsArabic(String text) {
    return RegExp(r'[\u0600-\u06FF]').hasMatch(text);
  }
}

class _LocalNumberMatch {
  final double value;
  final int start;

  const _LocalNumberMatch({
    required this.value,
    required this.start,
  });
}

class _LocalSaleAnalysis {
  final bool isArabic;
  final double? quantity;
  final double? sellingPrice;
  final double? unitCost;

  const _LocalSaleAnalysis({
    required this.isArabic,
    required this.quantity,
    required this.sellingPrice,
    required this.unitCost,
  });
}

class _LocalExpenseCategory {
  final String arabic;
  final String english;
  final List<String> tokens;

  const _LocalExpenseCategory({
    required this.arabic,
    required this.english,
    required this.tokens,
  });
}

class _LocalExpenseAnalysis {
  final bool isArabic;
  final double? amount;
  final _LocalExpenseCategory? category;

  const _LocalExpenseAnalysis({
    required this.isArabic,
    required this.amount,
    required this.category,
  });
}
