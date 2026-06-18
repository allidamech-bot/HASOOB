import 'package:flutter/foundation.dart';
import '../../data/models/ai_proposal_model.dart';
import 'ai_workspace_state.dart';

/// Controller for AI CFO Workspace state management
/// Provides centralized, testable ownership of workspace state.
/// Uses ChangeNotifier pattern consistent with existing codebase patterns.
class AiWorkspaceController extends ChangeNotifier {
  AiWorkspaceController();

  // Proposal state - corresponds to _activeProposal, _confirmationProposal in screen
  AiProposalModel? _activeProposal;
  AiProposalModel? _confirmationProposal;

  // Ledger state - corresponds to _ledgerRows in screen
  final List<LedgerEntry> _ledgerRows = [];

  // UI state - corresponds to _isAnalyzing, _isCommitting, _contextTabIndex in screen
  bool _isAnalyzing = false;
  bool _isCommitting = false;
  int _contextTabIndex = 0;

  // Getters
  AiProposalModel? get activeProposal => _activeProposal;
  AiProposalModel? get confirmationProposal => _confirmationProposal;
  List<LedgerEntry> get ledgerRows => List.unmodifiable(_ledgerRows);
  bool get isAnalyzing => _isAnalyzing;
  bool get isCommitting => _isCommitting;
  int get contextTabIndex => _contextTabIndex;

  // Proposal management
  void setActiveProposal(AiProposalModel? proposal) {
    _activeProposal = proposal;
    notifyListeners();
  }

  void setConfirmationProposal(AiProposalModel? proposal) {
    _confirmationProposal = proposal;
    notifyListeners();
  }

  void clearActiveProposal() {
    _activeProposal = null;
    notifyListeners();
  }

  void clearConfirmationProposal() {
    _confirmationProposal = null;
    notifyListeners();
  }

  void clearProposals({bool clearActive = true, bool clearConfirmation = true}) {
    if (clearActive) _activeProposal = null;
    if (clearConfirmation) _confirmationProposal = null;
    notifyListeners();
  }

  // Ledger management
  void addLedgerRow(LedgerEntry entry) {
    _ledgerRows.insert(0, entry);
    notifyListeners();
  }

  void updateLedgerRowWhere(
      String code, bool Function(LedgerEntry) predicate, LedgerEntry update) {
    for (var i = 0; i < _ledgerRows.length; i++) {
      if (predicate(_ledgerRows[i])) {
        _ledgerRows[i] = update;
      }
    }
    notifyListeners();
  }

  void removeLedgerRowsWhere(bool Function(LedgerEntry) predicate) {
    _ledgerRows.removeWhere(predicate);
    notifyListeners();
  }

  // Analysis state
  void setAnalyzing(bool value) {
    _isAnalyzing = value;
    notifyListeners();
  }

  // Commit state
  void setCommitting(bool value) {
    _isCommitting = value;
    notifyListeners();
  }

  // Context tab
  void setContextTabIndex(int index) {
    _contextTabIndex = index;
    notifyListeners();
  }

  // TODO(UI.4.3): Persist active proposal
  // TODO(UI.4.3): Persist ledger rows
  // TODO(UI.4.3): Persist workflow session
  // TODO(UI.4.3): Hydrate workspace state after refresh
}