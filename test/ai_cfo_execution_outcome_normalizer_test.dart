import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hasoob_app/features/ai_accountant/data/models/ai_proposal_model.dart';
import 'package:hasoob_app/features/ai_accountant/domain/ai_cfo_execution_outcome.dart';
import 'package:hasoob_app/features/ai_accountant/domain/ai_cfo_proposal_state_event.dart';
import 'package:hasoob_app/features/ai_accountant/domain/services/ai_cfo_execution_outcome_normalizer.dart';

void main() {
  group('AiCfoExecutionOutcomeNormalizer', () {
    const normalizer = AiCfoExecutionOutcomeNormalizer();
    const proposalId = 'proposal-1';

    test('blocked outcome is blocked terminal session-only without mutation',
        () {
      final outcome = normalizer.blocked(
        proposal: _proposal(),
        proposalSessionId: proposalId,
        reason: 'Needs confirmation.',
      );

      expect(outcome.type, AiCfoExecutionOutcomeType.blocked);
      expect(outcome.isBlocked, isTrue);
      expect(outcome.isTerminal, isTrue);
      expect(outcome.isSessionOnly, isTrue);
      expect(outcome.mutatedLedger, isFalse);
    });

    test('started outcome is not terminal and not complete', () {
      final outcome = normalizer.started(
        proposal: _proposal(),
        proposalSessionId: proposalId,
      );

      expect(outcome.type, AiCfoExecutionOutcomeType.started);
      expect(outcome.isTerminal, isFalse);
      expect(outcome.completedExternally, isFalse);
      expect(outcome.mutatedLedger, isFalse);
    });

    test('succeeded outcome describes external completion and mutation', () {
      final outcome = normalizer.succeeded(
        proposal: _proposal(),
        proposalSessionId: proposalId,
        message: 'Executed by existing engine.',
      );

      expect(outcome.isSuccess, isTrue);
      expect(outcome.isTerminal, isTrue);
      expect(outcome.completedExternally, isTrue);
      expect(outcome.mutatedLedger, isTrue);
      expect(outcome.isSessionOnly, isFalse);
    });

    test('failed outcome is terminal without mutation', () {
      final outcome = normalizer.failed(
        proposal: _proposal(),
        proposalSessionId: proposalId,
        reason: 'Insufficient stock.',
      );

      expect(outcome.isFailure, isTrue);
      expect(outcome.isTerminal, isTrue);
      expect(outcome.mutatedLedger, isFalse);
      expect(outcome.completedExternally, isFalse);
    });

    test('skipped outcome is terminal no-op without mutation', () {
      final outcome = normalizer.skipped(reason: 'No executable proposal.');

      expect(outcome.type, AiCfoExecutionOutcomeType.skipped);
      expect(outcome.isTerminal, isTrue);
      expect(outcome.mutatedLedger, isFalse);
      expect(outcome.completedExternally, isFalse);
    });

    test('blocked maps to blocked state event', () {
      final event = normalizer.toStateEventOrNull(
        normalizer.blocked(
          proposal: _proposal(),
          proposalSessionId: proposalId,
          reason: 'Blocked.',
        ),
      );

      expect(event, isNotNull);
      expect(event!.type, AiCfoProposalStateEventType.blocked);
      expect(event.reason, 'Blocked.');
      expect(event.completedExternally, isFalse);
      expect(event.mutatesLedger, isFalse);
    });

    test('started maps to executionStarted state event', () {
      final event = normalizer.toStateEventOrNull(
        normalizer.started(
          proposal: _proposal(),
          proposalSessionId: proposalId,
        ),
      );

      expect(event, isNotNull);
      expect(event!.type, AiCfoProposalStateEventType.executionStarted);
      expect(event.completedExternally, isFalse);
    });

    test('succeeded maps to executed state event with external completion', () {
      final event = normalizer.toStateEventOrNull(
        normalizer.succeeded(
          proposal: _proposal(),
          proposalSessionId: proposalId,
          message: 'Executed.',
        ),
      );

      expect(event, isNotNull);
      expect(event!.type, AiCfoProposalStateEventType.executed);
      expect(event.completedExternally, isTrue);
      expect(event.mutatesLedger, isFalse);
    });

    test('failed maps to failed state event', () {
      final event = normalizer.toStateEventOrNull(
        normalizer.failed(
          proposal: _proposal(),
          proposalSessionId: proposalId,
          reason: 'Failed.',
        ),
      );

      expect(event, isNotNull);
      expect(event!.type, AiCfoProposalStateEventType.failed);
      expect(event.reason, 'Failed.');
    });

    test('skipped and none do not map to fake executed event', () {
      const none = AiCfoExecutionOutcome(type: AiCfoExecutionOutcomeType.none);
      final skipped = normalizer.skipped(
        reason: 'No-op.',
        proposal: _proposal(),
        proposalSessionId: proposalId,
      );

      expect(normalizer.toStateEventOrNull(none), isNull);
      expect(normalizer.toStateEventOrNull(skipped), isNull);
    });

    test('no proposal or session id does not fabricate proposal state', () {
      final event = normalizer.toStateEventOrNull(
        normalizer.failed(proposal: null, reason: 'No proposal.'),
      );

      expect(event, isNull);
    });

    test('normalizer is pure with no repository database or ledger dependency',
        () {
      final modelSource = File(
        'lib/features/ai_accountant/domain/ai_cfo_execution_outcome.dart',
      ).readAsStringSync();
      final normalizerSource = File(
        'lib/features/ai_accountant/domain/services/'
        'ai_cfo_execution_outcome_normalizer.dart',
      ).readAsStringSync();
      final source = '$modelSource\n$normalizerSource';

      expect(source, isNot(contains('Repository')));
      expect(source, isNot(contains('DBHelper')));
      expect(source, isNot(contains('Firebase')));
      expect(source, isNot(contains('Firestore')));
      expect(source, isNot(contains('database')));
      expect(source, isNot(contains('LedgerEntry')));
      expect(source, isNot(contains('_ledgerRows')));
      expect(source, isNot(contains('executeProposalDetailed')));
    });

    test('normalizer does not fake success or persistence', () {
      final normalizerSource = File(
        'lib/features/ai_accountant/domain/services/'
        'ai_cfo_execution_outcome_normalizer.dart',
      ).readAsStringSync();

      expect(normalizerSource, isNot(contains('success: true')));
      expect(normalizerSource, isNot(contains('persist')));
      expect(normalizerSource, isNot(contains('save')));
      expect(normalizerSource, isNot(contains('insert')));
      expect(normalizerSource, isNot(contains('update')));
      expect(normalizerSource, isNot(contains('delete')));
    });

    test('normalizer is deterministic for same inputs', () {
      final first = normalizer.failed(
        proposal: _proposal(),
        proposalSessionId: proposalId,
        reason: 'Failed.',
      );
      final second = normalizer.failed(
        proposal: first.proposal,
        proposalSessionId: proposalId,
        reason: 'Failed.',
      );

      expect(first.type, second.type);
      expect(first.proposalSessionId, second.proposalSessionId);
      expect(first.message, second.message);
      expect(first.reason, second.reason);
      expect(first.completedExternally, second.completedExternally);
      expect(first.mutatedLedger, second.mutatedLedger);
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
