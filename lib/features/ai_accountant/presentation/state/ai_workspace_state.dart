import 'package:flutter/foundation.dart';

/// State model for AI CFO Workspace
/// This class holds immutable state data for the workspace.
@immutable
class AiWorkspaceState {
  final List<LedgerEntry> ledgerRows;
  final bool isAnalyzing;
  final bool isCommitting;
  final int contextTabIndex;

  const AiWorkspaceState({
    this.ledgerRows = const [],
    this.isAnalyzing = false,
    this.isCommitting = false,
    this.contextTabIndex = 0,
  });

  AiWorkspaceState copyWith({
    List<LedgerEntry>? ledgerRows,
    bool? isAnalyzing,
    bool? isCommitting,
    int? contextTabIndex,
  }) {
    return AiWorkspaceState(
      ledgerRows: ledgerRows ?? this.ledgerRows,
      isAnalyzing: isAnalyzing ?? this.isAnalyzing,
      isCommitting: isCommitting ?? this.isCommitting,
      contextTabIndex: contextTabIndex ?? this.contextTabIndex,
    );
  }
}

/// Ledger entry model - mirrors the existing LedgerEntry from ai_accountant_screen.dart
@immutable
class LedgerEntry {
  final String code;
  final String account;
  final double debit;
  final double credit;
  final String description;
  final String date;
  final bool isUncommitted;

  const LedgerEntry({
    required this.code,
    required this.account,
    required this.debit,
    required this.credit,
    required this.description,
    required this.date,
    this.isUncommitted = false,
  });

  LedgerEntry copyWith({
    String? code,
    String? account,
    double? debit,
    double? credit,
    String? description,
    String? date,
    bool? isUncommitted,
  }) {
    return LedgerEntry(
      code: code ?? this.code,
      account: account ?? this.account,
      debit: debit ?? this.debit,
      credit: credit ?? this.credit,
      description: description ?? this.description,
      date: date ?? this.date,
      isUncommitted: isUncommitted ?? this.isUncommitted,
    );
  }
}
