import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

import '../../../../core/business/business_context.dart';
import '../../data/models/ai_proposal_model.dart';
import '../../data/tools/financial_tools.dart';
import 'ai_evidence_bundle.dart';
import 'ai_financial_snapshot.dart';
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
        _reasoningEngine = FinancialReasoningEngine(),
        _insightGenerator = AiInsightGenerator(),
        _riskDetector = AiRiskDetector(),
        _workflowManager = AiWorkflowManager();

  final AiToolExecutor _toolExecutor;
  final AiToolPlanner _toolPlanner;
  final FinancialReasoningEngine _reasoningEngine;
  final AiInsightGenerator _insightGenerator;
  final AiRiskDetector _riskDetector;
  final AiWorkflowManager _workflowManager;
  final List<AiConversationTurn> _history = [];
  AiConversationMemory _memory = const AiConversationMemory();

  AiConversationMemory get memory => _memory;
  List<AiConversationTurn> get history => List.unmodifiable(_history);
  AiWorkflowSession? get activeWorkflow => _workflowManager.activeSession;

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

    final normalized = _normalized(userText);
    final workflowResult = _workflowManager.handleMessage(userText);
    if (workflowResult != null) {
      final response = AiAdvisorResponse(
        mode: workflowResult.isComplete
            ? AiAdvisorMode.proposalReview
            : AiAdvisorMode.advice,
        text: workflowResult.responseText,
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
    final response =
        (llmResponse ?? _fallbackResponse(normalized, plan, evidence)).copyWith(
      metadata: metadata,
      financialSnapshot: snapshot,
      insights: insights,
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
    if (_containsAny(normalized, ['hello', 'hi', 'hey', 'مرحبا', 'اهلا'])) {
      return AiAdvisorResponse(
        mode: AiAdvisorMode.chat,
        text:
            'Welcome. I can help you price shipments, test export decisions, review profitability, think through inventory and customer balances, or prepare accounting operations for review. Tell me what decision is in front of you.',
        suggestedReplies: const [
          'Price a shipment',
          'Review profitability',
          'Prepare a purchase',
        ],
        memory: _memory,
      );
    }
    if (_containsAny(normalized, ['how can you help', 'what can you do'])) {
      return AiAdvisorResponse(
        mode: AiAdvisorMode.advice,
        text:
            'I can work with you in a practical flow: first we clarify the business decision, then collect the numbers that matter, compare trade-offs, and only then prepare a reviewable purchase, sale, or pricing proposal if you want one. Nothing is posted to the books from discussion alone.',
        suggestedReplies: const [
          'Price a shipment',
          'Compare three scenarios',
          'Analyze inventory risk',
        ],
        memory: _memory,
      );
    }
    if (_containsAny(normalized, ['scenario', 'compare', 'balanced'])) {
      return _scenarioResponse();
    }
    if (_containsAny(normalized, ['export', 'saudi', 'shipping', 'customs'])) {
      final product = _memory.currentProduct ?? 'the product';
      final destination = _memory.currentDestination ?? 'the destination';
      return AiAdvisorResponse(
        mode: AiAdvisorMode.export,
        text:
            'Good. For exporting $product to $destination, I would build the decision around four numbers: carton cost, shipping allocation, customs/import fees, and the target selling price. Carton cost tells us the floor, shipping and customs reveal the real landed cost, and your market goal tells us whether to enter carefully or protect margin.',
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
    if (_containsAny(normalized, ['margin', '25%', 'percent'])) {
      return AiAdvisorResponse(
        mode: AiAdvisorMode.pricing,
        text:
            '25% can be suitable, but it depends on demand stability, competitor pricing, and how much uncertainty sits in shipping, customs, returns, and payment timing. For a new market I would not treat 25% as automatically right; I would compare conservative, balanced, and aggressive paths first.',
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
        text:
            'Got it. I will treat ${amount.toStringAsFixed(2)} as the current cost for ${_memory.currentProduct}. To turn that into useful pricing advice, I still need shipping, customs or import fees, currency, and whether you want faster entry or stronger margin.',
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
        text: _reasoningEngine.buildGroundedResponse(
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
        text: _reasoningEngine.buildGroundedResponse(
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
        text: _reasoningEngine.buildGroundedResponse(
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
      text:
          'I can help, but I need to know the business area first: pricing, export, profitability, inventory, customer balances, cash flow, or preparing a purchase or sale for review. Pick one and I will guide the next step.',
      suggestedReplies: const [
        'Price a shipment',
        'Review profitability',
        'Analyze inventory risk',
      ],
      memory: _memory,
    );
  }

  AiAdvisorResponse _scenarioResponse() {
    return AiAdvisorResponse(
      mode: AiAdvisorMode.pricing,
      text:
          'Here are the three paths I would compare. The right choice depends on whether you need market entry, balanced repeat sales, or maximum margin.',
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
        text:
            'I need a clear proposal before execution. Do you want to prepare a purchase, sale, or pricing simulation?',
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
      text:
          'There is an active ${activeProposal.actionType} proposal. Review the card first; if it is correct, approve it through the existing confirmation flow.',
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
}
