import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hasoob_app/features/ai_accountant/data/models/ai_proposal_model.dart';
import 'package:hasoob_app/features/ai_accountant/domain/ai_cfo_conversation_intent.dart';
import 'package:hasoob_app/features/ai_accountant/domain/ai_cfo_conversation_response.dart';
import 'package:hasoob_app/features/ai_accountant/domain/ai_cfo_proposal_command.dart';
import 'package:hasoob_app/features/ai_accountant/domain/services/ai_cfo_proposal_command_adapter.dart';
import 'package:hasoob_app/features/ai_accountant/domain/services/ai_cfo_proposal_lifecycle_resolver.dart';

void main() {
  group('AiCfoProposalCommandAdapter', () {
    const adapter = AiCfoProposalCommandAdapter();
    const lifecycleResolver = AiCfoProposalLifecycleResolver();

    test('unsupported and read-only intents return none', () {
      final unsupported = adapter.adapt(
        intent: AiCfoConversationIntent.unsupported,
        lifecycle: lifecycleResolver.resolve(activeProposal: _proposal()),
      );
      final readOnly = adapter.adapt(
        intent: AiCfoConversationIntent.businessHealth,
        lifecycle: lifecycleResolver.resolve(activeProposal: _proposal()),
      );

      expect(unsupported.type, AiCfoProposalCommandType.none);
      expect(unsupported.isNoOp, isTrue);
      expect(readOnly.type, AiCfoProposalCommandType.none);
    });

    test('blocked response returns showGuardMessage', () {
      const response = AiCfoConversationResponse(
        type: AiCfoResponseType.blocked,
        intent: AiCfoConversationIntent.executeProposal,
        title: 'Execution blocked',
        message: 'No proposal.',
        isBlocked: true,
        blockedReason: 'No active proposal.',
      );

      final command = adapter.adapt(
        intent: AiCfoConversationIntent.executeProposal,
        lifecycle: lifecycleResolver.resolve(),
        response: response,
      );

      expect(command.type, AiCfoProposalCommandType.showGuardMessage);
      expect(command.isBlocked, isTrue);
      expect(command.response, same(response));
      expect(command.reason, 'No active proposal.');
    });

    test('review intent with active proposal returns reviewProposal', () {
      final proposal = _proposal();

      final command = adapter.adapt(
        intent: AiCfoConversationIntent.createProposal,
        lifecycle: lifecycleResolver.resolve(activeProposal: proposal),
        activeProposal: proposal,
      );

      expect(command.type, AiCfoProposalCommandType.reviewProposal);
      expect(command.proposal, same(proposal));
      expect(command.requiresScreenAction, isTrue);
    });

    test('approve intent with active proposal returns approveProposal', () {
      final proposal = _proposal();

      final command = adapter.adapt(
        intent: AiCfoConversationIntent.approveProposal,
        lifecycle: lifecycleResolver.resolve(activeProposal: proposal),
        activeProposal: proposal,
      );

      expect(command.type, AiCfoProposalCommandType.approveProposal);
      expect(command.proposal, same(proposal));
      expect(command.canMutateLedger, isFalse);
    });

    test('defer intent with active proposal returns deferProposal', () {
      final proposal = _proposal();

      final command = adapter.adapt(
        intent: AiCfoConversationIntent.deferProposal,
        lifecycle: lifecycleResolver.resolve(activeProposal: proposal),
        activeProposal: proposal,
      );

      expect(command.type, AiCfoProposalCommandType.deferProposal);
      expect(command.proposal, same(proposal));
      expect(command.isSessionOnly, isTrue);
    });

    test('execute intent with lifecycle canExecute returns executeProposal',
        () {
      final proposal = _proposal();
      final lifecycle = lifecycleResolver.resolve(
        activeProposal: proposal,
        reviewedProposalIds: {lifecycleResolver.proposalSessionId(proposal)},
      );

      final command = adapter.adapt(
        intent: AiCfoConversationIntent.executeProposal,
        lifecycle: lifecycle,
        activeProposal: proposal,
      );

      expect(command.type, AiCfoProposalCommandType.executeProposal);
      expect(command.proposal, same(proposal));
      expect(command.requiresScreenAction, isTrue);
      expect(command.canMutateLedger, isTrue);
      expect(command.isSessionOnly, isFalse);
    });

    test('execute intent without executable lifecycle is guarded', () {
      final proposal = _proposal();

      final command = adapter.adapt(
        intent: AiCfoConversationIntent.executeProposal,
        lifecycle: lifecycleResolver.resolve(activeProposal: proposal),
        activeProposal: proposal,
      );

      expect(command.type, AiCfoProposalCommandType.showGuardMessage);
      expect(command.canMutateLedger, isFalse);
      expect(command.reason, contains('explicitly approved'));
    });

    test('no proposal never creates execute approve or review command', () {
      final commands = [
        adapter.adapt(
          intent: AiCfoConversationIntent.executeProposal,
          lifecycle: lifecycleResolver.resolve(),
        ),
        adapter.adapt(
          intent: AiCfoConversationIntent.approveProposal,
          lifecycle: lifecycleResolver.resolve(),
        ),
        adapter.adapt(
          intent: AiCfoConversationIntent.createProposal,
          lifecycle: lifecycleResolver.resolve(),
        ),
      ];

      expect(
        commands.map((command) => command.type),
        everyElement(AiCfoProposalCommandType.none),
      );
    });

    test('adapter is pure with no repository database or ledger dependency',
        () {
      final commandSource = File(
        'lib/features/ai_accountant/domain/ai_cfo_proposal_command.dart',
      ).readAsStringSync();
      final adapterSource = File(
        'lib/features/ai_accountant/domain/services/'
        'ai_cfo_proposal_command_adapter.dart',
      ).readAsStringSync();
      final source = '$commandSource\n$adapterSource';

      expect(source, isNot(contains('Repository')));
      expect(source, isNot(contains('DBHelper')));
      expect(source, isNot(contains('Firebase')));
      expect(source, isNot(contains('Firestore')));
      expect(source, isNot(contains('database')));
      expect(source, isNot(contains('LedgerEntry')));
      expect(source, isNot(contains('_ledgerRows')));
      expect(source, isNot(contains('executeProposalDetailed')));
      expect(source, isNot(contains('toMap')));
      expect(source, isNot(contains('fromMap')));
    });

    test('adapter does not fake success or persistence', () {
      final adapterSource = File(
        'lib/features/ai_accountant/domain/services/'
        'ai_cfo_proposal_command_adapter.dart',
      ).readAsStringSync();

      expect(adapterSource, isNot(contains('success: true')));
      expect(adapterSource, isNot(contains('persist')));
      expect(adapterSource, isNot(contains('save')));
      expect(adapterSource, isNot(contains('insert')));
      expect(adapterSource, isNot(contains('update')));
      expect(adapterSource, isNot(contains('delete')));
    });

    test('commands are session-only except delegated execution semantics', () {
      final proposal = _proposal();
      final reviewedLifecycle = lifecycleResolver.resolve(
        activeProposal: proposal,
        reviewedProposalIds: {lifecycleResolver.proposalSessionId(proposal)},
      );

      final defer = adapter.adapt(
        intent: AiCfoConversationIntent.deferProposal,
        lifecycle: lifecycleResolver.resolve(activeProposal: proposal),
        activeProposal: proposal,
      );
      final execute = adapter.adapt(
        intent: AiCfoConversationIntent.executeProposal,
        lifecycle: reviewedLifecycle,
        activeProposal: proposal,
      );

      expect(defer.isSessionOnly, isTrue);
      expect(defer.canMutateLedger, isFalse);
      expect(execute.isSessionOnly, isFalse);
      expect(execute.canMutateLedger, isTrue);
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
