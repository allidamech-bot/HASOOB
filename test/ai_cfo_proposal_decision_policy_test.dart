import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hasoob_app/features/ai_accountant/data/models/ai_proposal_model.dart';
import 'package:hasoob_app/features/ai_accountant/domain/ai_cfo_conversation_response.dart';
import 'package:hasoob_app/features/ai_accountant/domain/ai_cfo_evidence.dart';
import 'package:hasoob_app/features/ai_accountant/domain/ai_cfo_proposal_decision_policy.dart';
import 'package:hasoob_app/features/ai_accountant/domain/ai_cfo_proposal_lifecycle.dart';
import 'package:hasoob_app/features/ai_accountant/domain/services/ai_cfo_proposal_decision_policy_resolver.dart';
import 'package:hasoob_app/features/ai_accountant/domain/services/ai_cfo_proposal_lifecycle_resolver.dart';

void main() {
  group('AiCfoProposalDecisionPolicyResolver', () {
    const resolver = AiCfoProposalDecisionPolicyResolver();
    const lifecycleResolver = AiCfoProposalLifecycleResolver();

    test('approve with no proposal is denied', () {
      final result = resolver.resolve(
        decision: AiCfoProposalDecision.approve,
        lifecycle: const AiCfoProposalLifecycle(),
      );

      expect(result.allowed, isFalse);
      expect(result.responseType, AiCfoResponseType.proposal);
      expect(result.reason, contains('no active proposal'));
    });

    test('execute with no proposal is denied', () {
      final result = resolver.resolve(
        decision: AiCfoProposalDecision.execute,
        lifecycle: const AiCfoProposalLifecycle(),
      );

      expect(result.allowed, isFalse);
      expect(result.responseType, AiCfoResponseType.blocked);
      expect(result.reason, contains('active proposal'));
    });

    test('defer with no proposal is safely handled', () {
      final result = resolver.resolve(
        decision: AiCfoProposalDecision.defer,
        lifecycle: const AiCfoProposalLifecycle(),
      );

      expect(result.allowed, isFalse);
      expect(result.responseType, AiCfoResponseType.blocked);
      expect(result.reason, contains('no active proposal'));
    });

    test('review with active proposal is allowed', () {
      final lifecycle = lifecycleResolver.resolve(activeProposal: _proposal());

      final result = resolver.resolve(
        decision: AiCfoProposalDecision.review,
        lifecycle: lifecycle,
      );

      expect(result.allowed, isTrue);
      expect(result.responseType, AiCfoResponseType.proposal);
    });

    test('approve with active proposal does not execute', () {
      final lifecycle = lifecycleResolver.resolve(activeProposal: _proposal());

      final result = resolver.resolve(
        decision: AiCfoProposalDecision.approve,
        lifecycle: lifecycle,
      );

      expect(result.allowed, isTrue);
      expect(result.responseType, AiCfoResponseType.proposal);
      expect(result.reason, isNot(contains('execut')));
    });

    test('execute before approval is denied', () {
      final lifecycle = lifecycleResolver.resolve(activeProposal: _proposal());

      final result = resolver.resolve(
        decision: AiCfoProposalDecision.execute,
        lifecycle: lifecycle,
      );

      expect(lifecycle.canExecute, isFalse);
      expect(result.allowed, isFalse);
      expect(result.responseType, AiCfoResponseType.blocked);
      expect(result.reason, contains('explicitly approved'));
    });

    test('execute when lifecycle canExecute is true is policy-only allowed',
        () {
      final proposal = _proposal();
      final lifecycle = lifecycleResolver.resolve(
        activeProposal: proposal,
        reviewedProposalIds: {lifecycleResolver.proposalSessionId(proposal)},
      );

      final result = resolver.resolve(
        decision: AiCfoProposalDecision.execute,
        lifecycle: lifecycle,
      );

      expect(lifecycle.canExecute, isTrue);
      expect(result.allowed, isTrue);
      expect(result.responseType, AiCfoResponseType.executionResult);
      expect(result.reason, contains('existing guarded execution path only'));
    });

    test('blocked lifecycle denies execute', () {
      final lifecycle = lifecycleResolver.resolve(
        activeProposal: _proposal(),
        reason: 'Missing product confirmation',
      );

      final result = resolver.resolve(
        decision: AiCfoProposalDecision.execute,
        lifecycle: lifecycle,
      );

      expect(result.allowed, isFalse);
      expect(result.reason, 'Missing product confirmation');
    });

    test('deferred lifecycle denies execute', () {
      const lifecycle = AiCfoProposalLifecycle(
        state: AiCfoProposalLifecycleState.deferred,
        deferredFollowUps: ['Return later'],
      );

      final result = resolver.resolve(
        decision: AiCfoProposalDecision.execute,
        lifecycle: lifecycle,
      );

      expect(result.allowed, isFalse);
      expect(result.reason, contains('Deferred'));
    });

    test('executed lifecycle denies repeat execute', () {
      const lifecycle = AiCfoProposalLifecycle(
        state: AiCfoProposalLifecycleState.executed,
      );

      final result = resolver.resolve(
        decision: AiCfoProposalDecision.execute,
        lifecycle: lifecycle,
      );

      expect(result.allowed, isFalse);
      expect(result.reason, contains('cannot repeat execution'));
    });

    test('policy is pure and session-only', () {
      final result = resolver.resolve(
        decision: AiCfoProposalDecision.review,
        lifecycle: lifecycleResolver.resolve(activeProposal: _proposal()),
      );

      expect(result.isSessionOnly, isTrue);
      expect(result.confidence, AiCfoEvidenceConfidence.high);
    });

    test('no service role, repository, database, or ledger dependency exists',
        () {
      final policySource = File(
        'lib/features/ai_accountant/domain/'
        'ai_cfo_proposal_decision_policy.dart',
      ).readAsStringSync();
      final resolverSource = File(
        'lib/features/ai_accountant/domain/services/'
        'ai_cfo_proposal_decision_policy_resolver.dart',
      ).readAsStringSync();
      final source = '$policySource\n$resolverSource';

      expect(source, isNot(contains('service_role')));
      expect(source, isNot(contains('Repository')));
      expect(source, isNot(contains('DBHelper')));
      expect(source, isNot(contains('Firebase')));
      expect(source, isNot(contains('Firestore')));
      expect(source, isNot(contains('database')));
      expect(source, isNot(contains('ledger')));
      expect(source, isNot(contains('executeProposal')));
      expect(source, isNot(contains('toMap')));
      expect(source, isNot(contains('fromMap')));
    });
  });
}

AiProposalModel _proposal() {
  return AiProposalModel(
    actionType: 'sale',
    explanation: 'Review sale before guarded execution.',
    confidenceScore: 0.91,
    inventoryPayload: const {'productId': 'p-1', 'quantity': 1},
    financialPayload: const {'totalAmount': 100.0},
  );
}
