import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hasoob_app/features/ai_accountant/data/models/ai_proposal_model.dart';
import 'package:hasoob_app/features/ai_accountant/domain/ai_cfo_proposal_lifecycle.dart';
import 'package:hasoob_app/features/ai_accountant/domain/services/ai_cfo_proposal_lifecycle_resolver.dart';

void main() {
  group('AiCfoProposalLifecycleResolver', () {
    const resolver = AiCfoProposalLifecycleResolver();

    test('no proposal resolves to none', () {
      final lifecycle = resolver.resolve();

      expect(lifecycle.state, AiCfoProposalLifecycleState.none);
      expect(lifecycle.hasProposal, isFalse);
      expect(lifecycle.requiresApproval, isFalse);
      expect(lifecycle.canExecute, isFalse);
    });

    test('active proposal resolves to awaitingReview', () {
      final proposal = _proposal();

      final lifecycle = resolver.resolve(activeProposal: proposal);

      expect(lifecycle.state, AiCfoProposalLifecycleState.awaitingReview);
      expect(lifecycle.hasActiveProposal, isTrue);
      expect(lifecycle.requiresApproval, isTrue);
      expect(lifecycle.canExecute, isFalse);
    });

    test('confirmation proposal resolves to awaitingApproval', () {
      final proposal = _proposal();

      final lifecycle = resolver.resolve(confirmationProposal: proposal);

      expect(lifecycle.state, AiCfoProposalLifecycleState.awaitingApproval);
      expect(lifecycle.hasConfirmationProposal, isTrue);
      expect(lifecycle.requiresApproval, isTrue);
      expect(lifecycle.canExecute, isTrue);
    });

    test('reviewed proposal id resolves to reviewed', () {
      final proposal = _proposal();
      final reviewed = {resolver.proposalSessionId(proposal)};

      final lifecycle = resolver.resolve(
        activeProposal: proposal,
        reviewedProposalIds: reviewed,
      );

      expect(lifecycle.state, AiCfoProposalLifecycleState.reviewed);
      expect(lifecycle.canExecute, isTrue);
    });

    test('deferred follow-up resolves to deferred', () {
      final lifecycle = resolver.resolve(
        deferredFollowUps: const ['Return to purchase action'],
      );

      expect(lifecycle.state, AiCfoProposalLifecycleState.deferred);
      expect(lifecycle.canExecute, isFalse);
    });

    test('deferred active proposal id resolves to deferred', () {
      final proposal = _proposal();
      final proposalId = resolver.proposalSessionId(proposal);

      final lifecycle = resolver.resolve(
        activeProposal: proposal,
        reviewedProposalIds: {proposalId},
        approvedProposalIds: {proposalId},
        deferredFollowUps: [proposalId],
      );

      expect(lifecycle.state, AiCfoProposalLifecycleState.deferred);
      expect(lifecycle.hasProposal, isTrue);
      expect(lifecycle.canExecute, isFalse);
    });

    test('executing flag resolves to executing', () {
      final lifecycle = resolver.resolve(
        activeProposal: _proposal(),
        isExecuting: true,
      );

      expect(lifecycle.state, AiCfoProposalLifecycleState.executing);
      expect(lifecycle.canExecute, isFalse);
    });

    test('success flag resolves to executed', () {
      final lifecycle = resolver.resolve(lastExecutionSucceeded: true);

      expect(lifecycle.state, AiCfoProposalLifecycleState.executed);
      expect(lifecycle.canExecute, isFalse);
    });

    test('failed flag resolves to failed', () {
      final lifecycle = resolver.resolve(lastExecutionFailed: true);

      expect(lifecycle.state, AiCfoProposalLifecycleState.failed);
      expect(lifecycle.canExecute, isFalse);
    });

    test('blocked reason resolves to blocked', () {
      final lifecycle = resolver.resolve(
        activeProposal: _proposal(),
        reason: 'Missing product confirmation',
      );

      expect(lifecycle.state, AiCfoProposalLifecycleState.blocked);
      expect(lifecycle.isBlocked, isTrue);
      expect(lifecycle.reason, 'Missing product confirmation');
      expect(lifecycle.canExecute, isFalse);
    });

    test('canExecute is never true without a proposal and approval condition',
        () {
      final noProposalStates = [
        resolver.resolve(),
        resolver.resolve(deferredFollowUps: const ['Later']),
        resolver.resolve(lastExecutionSucceeded: true),
        resolver.resolve(lastExecutionFailed: true),
        resolver.resolve(reason: 'Blocked'),
      ];

      for (final lifecycle in noProposalStates) {
        expect(lifecycle.hasProposal, isFalse);
        expect(lifecycle.canExecute, isFalse);
      }

      final awaitingReview = resolver.resolve(activeProposal: _proposal());
      expect(awaitingReview.hasProposal, isTrue);
      expect(awaitingReview.requiresApproval, isTrue);
      expect(awaitingReview.canExecute, isFalse);
    });

    test('lifecycle is session-only and does not persist', () {
      final lifecycle = resolver.resolve(activeProposal: _proposal());
      final lifecycleSource = File(
        'lib/features/ai_accountant/domain/ai_cfo_proposal_lifecycle.dart',
      ).readAsStringSync();
      final resolverSource = File(
        'lib/features/ai_accountant/domain/services/'
        'ai_cfo_proposal_lifecycle_resolver.dart',
      ).readAsStringSync();
      final combinedSource = '$lifecycleSource\n$resolverSource';

      expect(lifecycle.isSessionOnly, isTrue);
      expect(combinedSource, isNot(contains('toMap')));
      expect(combinedSource, isNot(contains('fromMap')));
      expect(combinedSource, isNot(contains('DBHelper')));
      expect(combinedSource, isNot(contains('Firebase')));
      expect(combinedSource, isNot(contains('Firestore')));
      expect(combinedSource, isNot(contains('database')));
      expect(combinedSource, isNot(contains('insert')));
      expect(combinedSource, isNot(contains('update')));
      expect(combinedSource, isNot(contains('delete')));
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
