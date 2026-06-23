import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hasoob_app/features/ai_accountant/data/models/ai_proposal_model.dart';
import 'package:hasoob_app/features/ai_accountant/domain/ai_cfo_proposal_session_state.dart';
import 'package:hasoob_app/features/ai_accountant/presentation/proposal_execution_presentation_state.dart';

void main() {
  group('AiCfoProposalExecutionPresentationState', () {
    test('ready proposal can delegate execution only while current and idle',
        () {
      final state = _resolve();

      expect(state.state, AiCfoProposalExecutionUxState.ready);
      expect(state.canDelegateExecution, isTrue);
      expect(state.executionLabel, 'Not executed yet');
      expect(state.decisionLabel, contains('guarded execution'));
    });

    test('running execution cannot delegate or render as executed', () {
      final state = _resolve(isExecuting: true);

      expect(state.state, AiCfoProposalExecutionUxState.executing);
      expect(state.canDelegateExecution, isFalse);
      expect(state.statusLabel, 'Executing');
      expect(state.executionLabel, contains('waiting for external result'));
      expect(state.executionLabel, isNot(contains('Executed')));
    });

    test('external success is required before executed state appears', () {
      final started = _resolve(isExecuting: true);
      final succeeded = _resolve(
        sessionState: const AiCfoProposalSessionState(
          executedProposalIds: {'p-1'},
        ),
      );

      expect(started.state, isNot(AiCfoProposalExecutionUxState.executed));
      expect(started.canDelegateExecution, isFalse);
      expect(succeeded.state, AiCfoProposalExecutionUxState.executed);
      expect(succeeded.canDelegateExecution, isFalse);
      expect(succeeded.executionLabel, contains('confirmed completion'));
    });

    test('deferred proposal stays non-executed and non-delegated', () {
      final state = _resolve(
        sessionState: const AiCfoProposalSessionState(
          deferredProposalIds: {'p-1'},
        ),
      );

      expect(state.state, AiCfoProposalExecutionUxState.deferred);
      expect(state.canDelegateExecution, isFalse);
      expect(state.statusLabel, 'Deferred');
      expect(state.executionLabel, 'Deferred - not executed');
    });

    test('failed and blocked states are follow-up states, not success', () {
      final failed = _resolve(
        sessionState: const AiCfoProposalSessionState(
          failureReasons: {'p-1': 'Insufficient stock.'},
        ),
      );
      final blocked = _resolve(
        sessionState: const AiCfoProposalSessionState(
          blockedReasons: {'p-1': 'Product confirmation required.'},
        ),
      );

      expect(failed.state, AiCfoProposalExecutionUxState.failed);
      expect(failed.canDelegateExecution, isFalse);
      expect(failed.executionLabel, 'Failed - not executed');
      expect(failed.decisionLabel, 'Insufficient stock.');

      expect(blocked.state, AiCfoProposalExecutionUxState.blocked);
      expect(blocked.canDelegateExecution, isFalse);
      expect(blocked.executionLabel, 'Blocked - not executed');
      expect(blocked.decisionLabel, 'Product confirmation required.');
    });

    test('duplicate execution after executed is non-delegated', () {
      final state = _resolve(
        sessionState: const AiCfoProposalSessionState(
          executedProposalIds: {'p-1'},
        ),
      );

      expect(state.state, AiCfoProposalExecutionUxState.executed);
      expect(state.canDelegateExecution, isFalse);
      expect(state.decisionLabel, contains('guarded external execution path'));
    });

    test('no current or unsupported proposal cannot delegate execution', () {
      final historical = _resolve(isCurrent: false);
      final unsupported = _resolve(proposal: _proposal(actionType: 'unknown'));

      expect(historical.state, AiCfoProposalExecutionUxState.reviewOnly);
      expect(historical.canDelegateExecution, isFalse);
      expect(unsupported.state, AiCfoProposalExecutionUxState.unsupported);
      expect(unsupported.canDelegateExecution, isFalse);
    });

    test('helper stays presentation-only with no persistence or execution', () {
      final source = File(
        'lib/features/ai_accountant/presentation/'
        'proposal_execution_presentation_state.dart',
      ).readAsStringSync();

      expect(source, isNot(contains('executeProposalDetailed')));
      expect(source, isNot(contains('ProposalExecutionEngine')));
      expect(source, isNot(contains('Repository')));
      expect(source, isNot(contains('DBHelper')));
      expect(source, isNot(contains('Firebase')));
      expect(source, isNot(contains('Firestore')));
      expect(source, isNot(contains('auth')));
      expect(source, isNot(contains('success: true')));
      expect(source, isNot(contains('persist')));
      expect(source, isNot(contains('save(')));
      expect(source, isNot(contains('saveAi')));
      expect(source, isNot(contains('insert')));
      expect(source, isNot(contains('delete')));
    });
  });
}

AiCfoProposalExecutionPresentationState _resolve({
  AiProposalModel? proposal,
  AiCfoProposalSessionState sessionState = const AiCfoProposalSessionState(),
  bool isCurrent = true,
  bool isExecuting = false,
}) {
  return AiCfoProposalExecutionPresentationState.resolve(
    proposal: proposal ?? _proposal(),
    proposalSessionId: 'p-1',
    sessionState: sessionState,
    isCurrent: isCurrent,
    isExecuting: isExecuting,
  );
}

AiProposalModel _proposal({String actionType = 'sale'}) {
  return AiProposalModel(
    actionType: actionType,
    explanation: 'Review sale before guarded execution.',
    confidenceScore: 0.91,
    inventoryPayload: const {'productId': 'p-1', 'quantity': 1},
    financialPayload: const {'totalAmount': 100.0},
  );
}
