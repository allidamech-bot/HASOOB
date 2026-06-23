import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hasoob_app/features/ai_accountant/data/models/ai_proposal_model.dart';
import 'package:hasoob_app/features/ai_accountant/domain/ai_cfo_conversation_intent.dart';
import 'package:hasoob_app/features/ai_accountant/domain/ai_cfo_execution_outcome.dart';
import 'package:hasoob_app/features/ai_accountant/domain/ai_cfo_proposal_command.dart';
import 'package:hasoob_app/features/ai_accountant/domain/ai_cfo_proposal_lifecycle.dart';
import 'package:hasoob_app/features/ai_accountant/domain/ai_cfo_proposal_session_controller_result.dart';
import 'package:hasoob_app/features/ai_accountant/domain/ai_cfo_proposal_session_state.dart';
import 'package:hasoob_app/features/ai_accountant/domain/ai_cfo_proposal_state_event.dart';
import 'package:hasoob_app/features/ai_accountant/domain/services/ai_cfo_execution_outcome_normalizer.dart';
import 'package:hasoob_app/features/ai_accountant/domain/services/ai_cfo_proposal_session_controller.dart';

void main() {
  group('AiCfoProposalSessionController', () {
    const controller = AiCfoProposalSessionController();
    const normalizer = AiCfoExecutionOutcomeNormalizer();

    test('resolveLifecycle uses session reviewed IDs', () {
      final proposal = _proposal();
      final proposalId = controller.proposalSessionId(proposal);
      final lifecycle = controller.resolveLifecycle(
        activeProposal: proposal,
        sessionState: AiCfoProposalSessionState(
          reviewedProposalIds: {proposalId},
        ),
      );

      expect(lifecycle.state, AiCfoProposalLifecycleState.reviewed);
      expect(lifecycle.canExecute, isTrue);
    });

    test('resolveLifecycle uses session approved IDs', () {
      final proposal = _proposal();
      final proposalId = controller.proposalSessionId(proposal);
      final lifecycle = controller.resolveLifecycle(
        activeProposal: proposal,
        sessionState: AiCfoProposalSessionState(
          approvedProposalIds: {proposalId},
        ),
      );

      expect(lifecycle.state, AiCfoProposalLifecycleState.approved);
      expect(lifecycle.canExecute, isTrue);
    });

    test('classifyIntent delegates proposal commands correctly', () {
      expect(
        controller.classifyIntent(input: 'approve this'),
        AiCfoConversationIntent.approveProposal,
      );
      expect(
        controller.classifyIntent(input: 'execute this'),
        AiCfoConversationIntent.executeProposal,
      );
      expect(
        controller.classifyIntent(input: 'defer this'),
        AiCfoConversationIntent.deferProposal,
      );
    });

    test('no-active approve and execute produce guard not execution', () async {
      final approve = await controller.resolveCommand(
        input: 'موافق',
        businessId: '',
        sessionState: AiCfoProposalSessionState.empty(),
      );
      final execute = await controller.resolveCommand(
        input: 'execute',
        businessId: '',
        sessionState: AiCfoProposalSessionState.empty(),
      );

      expect(approve.action,
          AiCfoProposalSessionControllerAction.showGuardMessage);
      expect(approve.isBlocked, isTrue);
      expect(approve.canDelegateExecution, isFalse);
      expect(execute.action,
          AiCfoProposalSessionControllerAction.showGuardMessage);
      expect(execute.isBlocked, isTrue);
      expect(execute.canDelegateExecution, isFalse);
    });

    test('active review produces reviewProposal result', () async {
      final proposal = _proposal();
      final result = await controller.resolveCommand(
        input: 'prepare proposal',
        businessId: '',
        sessionState: AiCfoProposalSessionState.empty(),
        activeProposal: proposal,
      );

      expect(
          result.action, AiCfoProposalSessionControllerAction.reviewProposal);
      expect(result.command.type, AiCfoProposalCommandType.reviewProposal);
      expect(result.proposal, same(proposal));
      expect(result.requiresScreenAction, isTrue);
    });

    test('active defer produces deferProposal result', () async {
      final proposal = _proposal();
      final result = await controller.resolveCommand(
        input: 'defer this',
        businessId: '',
        sessionState: AiCfoProposalSessionState.empty(),
        activeProposal: proposal,
      );

      expect(result.action, AiCfoProposalSessionControllerAction.deferProposal);
      expect(result.command.type, AiCfoProposalCommandType.deferProposal);
      expect(result.canDelegateExecution, isFalse);
      expect(result.isSessionOnly, isTrue);
    });

    test('deferred active proposal blocks execution delegation', () async {
      final proposal = _proposal();
      final proposalId = controller.proposalSessionId(proposal);
      final result = await controller.resolveCommand(
        input: 'execute this',
        businessId: '',
        sessionState: AiCfoProposalSessionState(
          reviewedProposalIds: {proposalId},
          approvedProposalIds: {proposalId},
          deferredProposalIds: {proposalId},
        ),
        activeProposal: proposal,
      );

      expect(
          result.action, AiCfoProposalSessionControllerAction.showGuardMessage);
      expect(result.lifecycle.state, AiCfoProposalLifecycleState.deferred);
      expect(result.isBlocked, isTrue);
      expect(result.canDelegateExecution, isFalse);
      expect(result.command.canMutateLedger, isFalse);
    });

    test('blocked active proposal blocks execution delegation', () async {
      final proposal = _proposal();
      final proposalId = controller.proposalSessionId(proposal);
      final result = await controller.resolveCommand(
        input: 'execute this',
        businessId: '',
        sessionState: AiCfoProposalSessionState(
          approvedProposalIds: {proposalId},
          blockedReasons: {proposalId: 'Product confirmation required.'},
        ),
        activeProposal: proposal,
      );

      expect(result.lifecycle.state, AiCfoProposalLifecycleState.blocked);
      expect(result.isBlocked, isTrue);
      expect(result.canDelegateExecution, isFalse);
      expect(result.command.canMutateLedger, isFalse);
    });

    test('failed active proposal blocks execution delegation', () async {
      final proposal = _proposal();
      final proposalId = controller.proposalSessionId(proposal);
      final result = await controller.resolveCommand(
        input: 'execute this',
        businessId: '',
        sessionState: AiCfoProposalSessionState(
          approvedProposalIds: {proposalId},
          failureReasons: {proposalId: 'Insufficient stock.'},
        ),
        activeProposal: proposal,
      );

      expect(result.lifecycle.state, AiCfoProposalLifecycleState.failed);
      expect(result.isBlocked, isTrue);
      expect(result.canDelegateExecution, isFalse);
      expect(result.command.canMutateLedger, isFalse);
    });

    test('executable proposal delegates execution only', () async {
      final proposal = _proposal();
      final proposalId = controller.proposalSessionId(proposal);
      final result = await controller.resolveCommand(
        input: 'execute this',
        businessId: '',
        sessionState: AiCfoProposalSessionState(
          approvedProposalIds: {proposalId},
        ),
        activeProposal: proposal,
      );

      expect(
          result.action, AiCfoProposalSessionControllerAction.executeProposal);
      expect(result.command.type, AiCfoProposalCommandType.executeProposal);
      expect(result.canDelegateExecution, isTrue);
      expect(result.command.canMutateLedger, isTrue);
    });

    test('non-executable proposal does not delegate execution', () async {
      final proposal = _proposal();
      final result = await controller.resolveCommand(
        input: 'execute this',
        businessId: '',
        sessionState: AiCfoProposalSessionState.empty(),
        activeProposal: proposal,
      );

      expect(
          result.action, AiCfoProposalSessionControllerAction.showGuardMessage);
      expect(result.isBlocked, isTrue);
      expect(result.canDelegateExecution, isFalse);
    });

    test('executed proposal blocks duplicate execution delegation', () async {
      final proposal = _proposal();
      final proposalId = controller.proposalSessionId(proposal);
      final result = await controller.resolveCommand(
        input: 'execute this again',
        businessId: '',
        sessionState: AiCfoProposalSessionState(
          reviewedProposalIds: {proposalId},
          approvedProposalIds: {proposalId},
          executedProposalIds: {proposalId},
        ),
        activeProposal: proposal,
      );

      expect(
          result.action, AiCfoProposalSessionControllerAction.showGuardMessage);
      expect(result.lifecycle.state, AiCfoProposalLifecycleState.executed);
      expect(result.isBlocked, isTrue);
      expect(result.canDelegateExecution, isFalse);
      expect(result.command.canMutateLedger, isFalse);
    });

    test('reduceEvent reviewed updates session state', () {
      final proposal = _proposal();
      final proposalId = controller.proposalSessionId(proposal);
      final state = controller.reduceEvent(
        state: AiCfoProposalSessionState.empty(),
        event: AiCfoProposalStateEvent(
          type: AiCfoProposalStateEventType.reviewed,
          proposal: proposal,
          proposalSessionId: proposalId,
        ),
      );

      expect(state.isReviewed(proposalId), isTrue);
    });

    test('reduceEvent deferred updates session state', () {
      final proposal = _proposal();
      final proposalId = controller.proposalSessionId(proposal);
      final state = controller.reduceEvent(
        state: AiCfoProposalSessionState.empty(),
        event: AiCfoProposalStateEvent(
          type: AiCfoProposalStateEventType.deferred,
          proposal: proposal,
          proposalSessionId: proposalId,
        ),
      );

      expect(state.isDeferred(proposalId), isTrue);
    });

    test('reduceOutcome started does not mark executed', () {
      final proposal = _proposal();
      final proposalId = controller.proposalSessionId(proposal);
      final state = controller.reduceOutcome(
        state: AiCfoProposalSessionState.empty(),
        outcome: normalizer.started(
          proposal: proposal,
          proposalSessionId: proposalId,
        ),
      );

      expect(state.isExecuted(proposalId), isFalse);
    });

    test('reduceOutcome succeeded marks executed after external completion',
        () {
      final proposal = _proposal();
      final proposalId = controller.proposalSessionId(proposal);
      final state = controller.reduceOutcome(
        state: AiCfoProposalSessionState.empty(),
        outcome: normalizer.succeeded(
          proposal: proposal,
          proposalSessionId: proposalId,
          message: 'Executed by existing engine.',
        ),
      );

      expect(state.isExecuted(proposalId), isTrue);
    });

    test('reduceOutcome failed records failure without marking executed', () {
      final proposal = _proposal();
      final proposalId = controller.proposalSessionId(proposal);
      final state = controller.reduceOutcome(
        state: AiCfoProposalSessionState.empty(),
        outcome: normalizer.failed(
          proposal: proposal,
          proposalSessionId: proposalId,
          reason: 'Insufficient stock.',
        ),
      );

      expect(state.isFailed(proposalId), isTrue);
      expect(state.failureReasons[proposalId], 'Insufficient stock.');
      expect(state.isExecuted(proposalId), isFalse);
    });

    test('reduceOutcome skipped and none leave state unchanged', () {
      final proposal = _proposal();
      final proposalId = controller.proposalSessionId(proposal);
      final state = AiCfoProposalSessionState(
        reviewedProposalIds: {proposalId},
      );
      final skipped = controller.reduceOutcome(
        state: state,
        outcome: normalizer.skipped(
          reason: 'No executable proposal.',
          proposal: proposal,
          proposalSessionId: proposalId,
        ),
      );
      final none = controller.reduceOutcome(
        state: state,
        outcome: const AiCfoExecutionOutcome(
          type: AiCfoExecutionOutcomeType.none,
        ),
      );

      expect(skipped.reviewedProposalIds, state.reviewedProposalIds);
      expect(none.reviewedProposalIds, state.reviewedProposalIds);
      expect(skipped.executedProposalIds, isEmpty);
      expect(none.executedProposalIds, isEmpty);
    });

    test('controller is pure with no repository database or ledger dependency',
        () {
      final source = _controllerSource();

      expect(source, isNot(contains('Repository')));
      expect(source, isNot(contains('DBHelper')));
      expect(source, isNot(contains('Firebase')));
      expect(source, isNot(contains('Firestore')));
      expect(source, isNot(contains('database')));
      expect(source, isNot(contains('LedgerEntry')));
      expect(source, isNot(contains('_ledgerRows')));
      expect(source, isNot(contains('executeProposalDetailed')));
      expect(source, isNot(contains('ProposalExecutionEngine')));
    });

    test('controller does not fake persistence or fake execution', () {
      final source = _controllerSource();

      expect(source, isNot(contains('success: true')));
      expect(source, isNot(contains('persist')));
      expect(source, isNot(contains('save')));
      expect(source, isNot(contains('insert')));
      expect(source, isNot(contains('delete')));
      expect(source, isNot(contains('toMap')));
      expect(source, isNot(contains('fromMap')));
    });

    test('controller does not import Flutter UI or widgets', () {
      final source = _controllerSource();

      expect(source, isNot(contains('package:flutter')));
      expect(source, isNot(contains('Widget')));
      expect(source, isNot(contains('BuildContext')));
      expect(source, isNot(contains('Material')));
    });
  });
}

String _controllerSource() {
  final resultSource = File(
    'lib/features/ai_accountant/domain/'
    'ai_cfo_proposal_session_controller_result.dart',
  ).readAsStringSync();
  final controllerSource = File(
    'lib/features/ai_accountant/domain/services/'
    'ai_cfo_proposal_session_controller.dart',
  ).readAsStringSync();
  return '$resultSource\n$controllerSource';
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
