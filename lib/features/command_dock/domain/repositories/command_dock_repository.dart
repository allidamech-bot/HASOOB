import '../../data/models/command_search_result.dart';

abstract class CommandDockRepository {
  Stream<List<CommandSearchResult>> globalSearch(String query);
  List<CommandSearchResult> getQuickActions();
}
