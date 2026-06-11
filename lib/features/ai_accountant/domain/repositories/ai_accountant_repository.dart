import 'dart:typed_data';

import '../../data/models/ai_proposal_model.dart';
import '../services/proposal_execution_engine.dart';

abstract class AiAccountantRepository {
  Future<AiProposalModel> parseNaturalLanguage(String text);

  Future<AiProposalModel> parseInvoiceImage(
      Uint8List imageBytes, String mimeType);

  Future<bool> executeProposal(AiProposalModel proposal);

  Future<ProposalExecutionResult> executeProposalDetailed(
    AiProposalModel proposal,
  );
}
