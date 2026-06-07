import '../../data/models/ai_proposal_model.dart';

abstract class AiAccountantRepository {
  Future<AiProposalModel> parseNaturalLanguage(String text);
  Future<bool> executeProposal(AiProposalModel proposal);
}
