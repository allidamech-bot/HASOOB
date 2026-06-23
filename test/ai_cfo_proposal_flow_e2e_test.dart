import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hasoob_app/features/ai_accountant/data/models/ai_proposal_model.dart';
import 'package:hasoob_app/features/ai_accountant/domain/ai_cfo_execution_outcome.dart';
import 'package:hasoob_app/features/ai_accountant/domain/ai_cfo_proposal_command.dart';
import 'package:hasoob_app/features/ai_accountant/domain/ai_cfo_proposal_lifecycle.dart';
import 'package:hasoob_app/features/ai_accountant/domain/ai_cfo_proposal_session_controller_result.dart';
import 'package:hasoob_app/features/ai_accountant/domain/ai_cfo_proposal_session_state.dart';
import 'package:hasoob_app/features/ai_accountant/domain/ai_cfo_proposal_state_event.dart';
import 'package:hasoob_app/features/ai_accountant/domain/services/ai_cfo_execution_outcome_normalizer.dart';
import 'package:hasoob_app/features/ai_accountant/domain/services/ai_cfo_proposal_session_controller.dart';

void main() {
  group('AI CFO proposal flow E2E guardrails', () {
    const controller = AiCfoProposalSessionController();
    const normalizer = AiCfoExecutionOutcomeNormalizer();

    test('proposal lifecycle delegates execution only after external success',
        () async {
      var state = AiCfoProposalSessionState.empty();

      final noProposalApprove = await controller.resolveCommand(
        input: 'approve this proposal',
        businessId: '',
        sessionState: state,
      );
      expect(noProposalApprove.isBlocked, isTrue);
      expect(noProposalApprove.canDelegateExecution, isFalse);
      expect(noProposalApprove.command.canMutateLedger, isFalse);

      final noProposalExecute = await controller.resolveCommand(
        input: 'execute this proposal',
        businessId: '',
        sessionState: state,
      );
      expect(noProposalExecute.isBlocked, isTrue);
      expect(noProposalExecute.canDelegateExecution, isFalse);
      expect(noProposalExecute.command.canMutateLedger, isFalse);

      final proposal = _proposal();
      final proposalId = controller.proposalSessionId(proposal);

      final review = await controller.resolveCommand(
        input: 'prepare proposal',
        businessId: '',
        sessionState: state,
        activeProposal: proposal,
      );
      expect(
          review.action, AiCfoProposalSessionControllerAction.reviewProposal);
      state = controller.reduceEvent(
        state: state,
        event: AiCfoProposalStateEvent(
          type: AiCfoProposalStateEventType.reviewed,
          proposal: proposal,
          proposalSessionId: proposalId,
          reason: 'Reviewed in session.',
        ),
      );
      expect(state.isReviewed(proposalId), isTrue);
      expect(state.isExecuted(proposalId), isFalse);

      final approve = await controller.resolveCommand(
        input: 'approve this proposal',
        businessId: '',
        sessionState: state,
        activeProposal: proposal,
      );
      expect(
          approve.action, AiCfoProposalSessionControllerAction.approveProposal);
      expect(approve.canDelegateExecution, isFalse);
      state = controller.reduceEvent(
        state: state,
        event: AiCfoProposalStateEvent(
          type: AiCfoProposalStateEventType.approved,
          proposal: proposal,
          proposalSessionId: proposalId,
          reason: 'Approved in session.',
        ),
      );
      expect(state.isApproved(proposalId), isTrue);

      final execute = await controller.resolveCommand(
        input: 'execute this proposal',
        businessId: '',
        sessionState: state,
        activeProposal: proposal,
      );
      expect(
          execute.action, AiCfoProposalSessionControllerAction.executeProposal);
      expect(execute.command.type, AiCfoProposalCommandType.executeProposal);
      expect(execute.canDelegateExecution, isTrue);
      expect(execute.command.canMutateLedger, isTrue);

      final afterStarted = controller.reduceOutcome(
        state: state,
        outcome: normalizer.started(
          proposal: proposal,
          proposalSessionId: proposalId,
        ),
      );
      expect(afterStarted.isExecuted(proposalId), isFalse);

      final afterSucceeded = controller.reduceOutcome(
        state: afterStarted,
        outcome: normalizer.succeeded(
          proposal: proposal,
          proposalSessionId: proposalId,
          message: 'External execution completed.',
        ),
      );
      expect(afterSucceeded.isExecuted(proposalId), isTrue);

      final duplicateExecute = await controller.resolveCommand(
        input: 'execute this proposal again',
        businessId: '',
        sessionState: afterSucceeded,
        activeProposal: proposal,
      );
      expect(duplicateExecute.isBlocked, isTrue);
      expect(duplicateExecute.canDelegateExecution, isFalse);
      expect(duplicateExecute.command.canMutateLedger, isFalse);
      expect(
        duplicateExecute.lifecycle.state,
        AiCfoProposalLifecycleState.executed,
      );
    });

    test('external failure blocked skipped and deferred states do not execute',
        () async {
      final failedProposal = _proposal();
      final failedId = controller.proposalSessionId(failedProposal);
      final failedState = controller.reduceOutcome(
        state: AiCfoProposalSessionState.empty(),
        outcome: normalizer.failed(
          proposal: failedProposal,
          proposalSessionId: failedId,
          reason: 'External execution failed.',
        ),
      );
      expect(failedState.isFailed(failedId), isTrue);
      expect(failedState.isExecuted(failedId), isFalse);

      final failedExecute = await controller.resolveCommand(
        input: 'execute this proposal',
        businessId: '',
        sessionState: failedState,
        activeProposal: failedProposal,
      );
      expect(failedExecute.isBlocked, isTrue);
      expect(failedExecute.canDelegateExecution, isFalse);
      expect(failedExecute.lifecycle.state, AiCfoProposalLifecycleState.failed);

      final blockedProposal = _proposal();
      final blockedId = controller.proposalSessionId(blockedProposal);
      final blockedState = controller.reduceOutcome(
        state: AiCfoProposalSessionState.empty(),
        outcome: normalizer.blocked(
          proposal: blockedProposal,
          proposalSessionId: blockedId,
          reason: 'Product confirmation required.',
        ),
      );
      expect(blockedState.isBlocked(blockedId), isTrue);
      expect(blockedState.isExecuted(blockedId), isFalse);

      final blockedExecute = await controller.resolveCommand(
        input: 'execute this proposal',
        businessId: '',
        sessionState: blockedState,
        activeProposal: blockedProposal,
      );
      expect(blockedExecute.isBlocked, isTrue);
      expect(blockedExecute.canDelegateExecution, isFalse);
      expect(
          blockedExecute.lifecycle.state, AiCfoProposalLifecycleState.blocked);

      final skippedProposal = _proposal();
      final skippedId = controller.proposalSessionId(skippedProposal);
      final reviewedState = AiCfoProposalSessionState(
        reviewedProposalIds: {skippedId},
      );
      final skippedState = controller.reduceOutcome(
        state: reviewedState,
        outcome: normalizer.skipped(
          reason: 'No executable proposal.',
          proposal: skippedProposal,
          proposalSessionId: skippedId,
        ),
      );
      final noneState = controller.reduceOutcome(
        state: reviewedState,
        outcome: const AiCfoExecutionOutcome(
          type: AiCfoExecutionOutcomeType.none,
        ),
      );
      expect(
          skippedState.reviewedProposalIds, reviewedState.reviewedProposalIds);
      expect(noneState.reviewedProposalIds, reviewedState.reviewedProposalIds);
      expect(skippedState.isExecuted(skippedId), isFalse);
      expect(noneState.isExecuted(skippedId), isFalse);

      final deferredProposal = _proposal();
      final deferredId = controller.proposalSessionId(deferredProposal);
      final deferredState = controller.reduceEvent(
        state: AiCfoProposalSessionState(
          reviewedProposalIds: {deferredId},
          approvedProposalIds: {deferredId},
        ),
        event: AiCfoProposalStateEvent(
          type: AiCfoProposalStateEventType.deferred,
          proposal: deferredProposal,
          proposalSessionId: deferredId,
          reason: 'Deferred for follow-up.',
        ),
      );
      expect(deferredState.isDeferred(deferredId), isTrue);
      expect(deferredState.isExecuted(deferredId), isFalse);

      final deferredExecute = await controller.resolveCommand(
        input: 'execute this proposal',
        businessId: '',
        sessionState: deferredState,
        activeProposal: deferredProposal,
      );
      expect(deferredExecute.isBlocked, isTrue);
      expect(deferredExecute.canDelegateExecution, isFalse);
      expect(
        deferredExecute.lifecycle.state,
        AiCfoProposalLifecycleState.deferred,
      );
    });

    test('controller source stays pure and does not fake persistence', () {
      final source = _controllerSource();

      expect(source, isNot(contains('package:flutter')));
      expect(source, isNot(contains('Widget')));
      expect(source, isNot(contains('BuildContext')));
      expect(source, isNot(contains('Repository')));
      expect(source, isNot(contains('DBHelper')));
      expect(source, isNot(contains('Firebase')));
      expect(source, isNot(contains('Firestore')));
      expect(source, isNot(contains('SQLite')));
      expect(source, isNot(contains('auth')));
      expect(source, isNot(contains('executeProposalDetailed')));
      expect(source, isNot(contains('ProposalExecutionEngine')));
      expect(source, isNot(contains('success: true')));
      expect(source, isNot(contains('persist')));
      expect(source, isNot(contains('save')));
      expect(source, isNot(contains('insert')));
      expect(source, isNot(contains('delete')));
      expect(source, isNot(contains('toMap')));
      expect(source, isNot(contains('fromMap')));
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
