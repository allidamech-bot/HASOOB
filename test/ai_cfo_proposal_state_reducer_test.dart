import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hasoob_app/features/ai_accountant/data/models/ai_proposal_model.dart';
import 'package:hasoob_app/features/ai_accountant/domain/ai_cfo_proposal_session_state.dart';
import 'package:hasoob_app/features/ai_accountant/domain/ai_cfo_proposal_state_event.dart';
import 'package:hasoob_app/features/ai_accountant/domain/services/ai_cfo_proposal_state_reducer.dart';

void main() {
  group('AiCfoProposalStateReducer', () {
    const reducer = AiCfoProposalStateReducer();
    const proposalId = 'proposal-1';

    test('empty state has no proposal state', () {
      final state = AiCfoProposalSessionState.empty();

      expect(state.isReviewed(proposalId), isFalse);
      expect(state.isDeferred(proposalId), isFalse);
      expect(state.isApproved(proposalId), isFalse);
      expect(state.isExecuted(proposalId), isFalse);
      expect(state.isBlocked(proposalId), isFalse);
      expect(state.isFailed(proposalId), isFalse);
      expect(state.isSessionOnly, isTrue);
    });

    test('reviewed event marks proposal reviewed', () {
      final state = reducer.reduce(
        state: AiCfoProposalSessionState.empty(),
        event: const AiCfoProposalStateEvent(
          type: AiCfoProposalStateEventType.reviewed,
          proposalSessionId: proposalId,
        ),
      );

      expect(state.isReviewed(proposalId), isTrue);
    });

    test('approved event marks proposal approved without executed', () {
      final state = reducer.reduce(
        state: AiCfoProposalSessionState.empty(),
        event: const AiCfoProposalStateEvent(
          type: AiCfoProposalStateEventType.approved,
          proposalSessionId: proposalId,
        ),
      );

      expect(state.isApproved(proposalId), isTrue);
      expect(state.isExecuted(proposalId), isFalse);
    });

    test('deferred event marks proposal deferred without executed', () {
      final state = reducer.reduce(
        state: AiCfoProposalSessionState.empty(),
        event: const AiCfoProposalStateEvent(
          type: AiCfoProposalStateEventType.deferred,
          proposalSessionId: proposalId,
        ),
      );

      expect(state.isDeferred(proposalId), isTrue);
      expect(state.isExecuted(proposalId), isFalse);
    });

    test('executionStarted does not mark executed', () {
      final state = reducer.reduce(
        state: AiCfoProposalSessionState.empty(),
        event: const AiCfoProposalStateEvent(
          type: AiCfoProposalStateEventType.executionStarted,
          proposalSessionId: proposalId,
        ),
      );

      expect(state.isExecuted(proposalId), isFalse);
    });

    test('executed event marks executed only as external completion', () {
      final ignored = reducer.reduce(
        state: AiCfoProposalSessionState.empty(),
        event: const AiCfoProposalStateEvent(
          type: AiCfoProposalStateEventType.executed,
          proposalSessionId: proposalId,
        ),
      );
      final completed = reducer.reduce(
        state: AiCfoProposalSessionState.empty(),
        event: const AiCfoProposalStateEvent(
          type: AiCfoProposalStateEventType.executed,
          proposalSessionId: proposalId,
          completedExternally: true,
        ),
      );

      expect(ignored.isExecuted(proposalId), isFalse);
      expect(completed.isExecuted(proposalId), isTrue);
    });

    test('failed event records reason and does not mark executed', () {
      final state = reducer.reduce(
        state: AiCfoProposalSessionState.empty(),
        event: const AiCfoProposalStateEvent(
          type: AiCfoProposalStateEventType.failed,
          proposalSessionId: proposalId,
          reason: 'Missing stock.',
        ),
      );

      expect(state.isFailed(proposalId), isTrue);
      expect(state.failureReasons[proposalId], 'Missing stock.');
      expect(state.isExecuted(proposalId), isFalse);
    });

    test('blocked event records reason and does not mark executed', () {
      final state = reducer.reduce(
        state: AiCfoProposalSessionState.empty(),
        event: const AiCfoProposalStateEvent(
          type: AiCfoProposalStateEventType.blocked,
          proposalSessionId: proposalId,
          reason: 'Needs product confirmation.',
        ),
      );

      expect(state.isBlocked(proposalId), isTrue);
      expect(state.blockedReasons[proposalId], 'Needs product confirmation.');
      expect(state.isExecuted(proposalId), isFalse);
    });

    test('cleared event for one proposal removes that proposal', () {
      var state = AiCfoProposalSessionState.empty();
      for (final id in [proposalId, 'proposal-2']) {
        state = reducer.reduce(
          state: state,
          event: AiCfoProposalStateEvent(
            type: AiCfoProposalStateEventType.reviewed,
            proposalSessionId: id,
          ),
        );
      }

      final cleared = reducer.reduce(
        state: state,
        event: const AiCfoProposalStateEvent(
          type: AiCfoProposalStateEventType.cleared,
          proposalSessionId: proposalId,
        ),
      );

      expect(cleared.isReviewed(proposalId), isFalse);
      expect(cleared.isReviewed('proposal-2'), isTrue);
    });

    test('cleared event without proposal clears all session state', () {
      final state = reducer.reduce(
        state: AiCfoProposalSessionState.empty(),
        event: const AiCfoProposalStateEvent(
          type: AiCfoProposalStateEventType.blocked,
          proposalSessionId: proposalId,
          reason: 'Blocked.',
        ),
      );

      final cleared = reducer.reduce(
        state: state,
        event: const AiCfoProposalStateEvent(
          type: AiCfoProposalStateEventType.cleared,
        ),
      );

      expect(cleared.blockedReasons, isEmpty);
      expect(cleared.reviewedProposalIds, isEmpty);
      expect(cleared.executedProposalIds, isEmpty);
    });

    test('reducer is immutable and does not mutate input state', () {
      final original = AiCfoProposalSessionState.empty();

      final next = reducer.reduce(
        state: original,
        event: const AiCfoProposalStateEvent(
          type: AiCfoProposalStateEventType.reviewed,
          proposalSessionId: proposalId,
        ),
      );

      expect(identical(original, next), isFalse);
      expect(original.isReviewed(proposalId), isFalse);
      expect(next.isReviewed(proposalId), isTrue);
    });

    test('reducer is pure with no repository database or ledger dependency',
        () {
      final eventSource = File(
        'lib/features/ai_accountant/domain/ai_cfo_proposal_state_event.dart',
      ).readAsStringSync();
      final stateSource = File(
        'lib/features/ai_accountant/domain/ai_cfo_proposal_session_state.dart',
      ).readAsStringSync();
      final reducerSource = File(
        'lib/features/ai_accountant/domain/services/'
        'ai_cfo_proposal_state_reducer.dart',
      ).readAsStringSync();
      final source = '$eventSource\n$stateSource\n$reducerSource';

      expect(source, isNot(contains('Repository')));
      expect(source, isNot(contains('DBHelper')));
      expect(source, isNot(contains('Firebase')));
      expect(source, isNot(contains('Firestore')));
      expect(source, isNot(contains('database')));
      expect(source, isNot(contains('ledger')));
      expect(source, isNot(contains('executeProposal')));
      expect(source, isNot(contains('executeProposalDetailed')));
    });

    test('reducer does not fake persistence or fake execution', () {
      final reducerSource = File(
        'lib/features/ai_accountant/domain/services/'
        'ai_cfo_proposal_state_reducer.dart',
      ).readAsStringSync();

      expect(reducerSource, isNot(contains('success: true')));
      expect(reducerSource, isNot(contains('persist')));
      expect(reducerSource, isNot(contains('save')));
      expect(reducerSource, isNot(contains('insert')));
      expect(reducerSource, isNot(contains('update')));
      expect(reducerSource, isNot(contains('delete')));
    });

    test('reducer is deterministic for same state and event', () {
      const event = AiCfoProposalStateEvent(
        type: AiCfoProposalStateEventType.reviewed,
        proposalSessionId: proposalId,
      );
      final state = AiCfoProposalSessionState.empty();

      final first = reducer.reduce(state: state, event: event);
      final second = reducer.reduce(state: state, event: event);

      expect(first.reviewedProposalIds, second.reviewedProposalIds);
      expect(first.deferredProposalIds, second.deferredProposalIds);
      expect(first.blockedReasons, second.blockedReasons);
      expect(first.failureReasons, second.failureReasons);
    });

    test('proposal object can provide a session id descriptor', () {
      final proposal = _proposal();
      final state = reducer.reduce(
        state: AiCfoProposalSessionState.empty(),
        event: AiCfoProposalStateEvent(
          type: AiCfoProposalStateEventType.reviewed,
          proposal: proposal,
        ),
      );

      expect(state.reviewedProposalIds, hasLength(1));
      expect(state.reviewedProposalIds.single, isNotEmpty);
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
