import 'dart:async';
import '../../domain/repositories/command_dock_repository.dart';
import '../models/command_search_result.dart';

class MockCommandDockRepository implements CommandDockRepository {
  final _controller = StreamController<List<CommandSearchResult>>.broadcast();

  final List<CommandSearchResult> _staticActions = [
    CommandSearchResult(id: 'act1', title: 'إضافة منتج جديد', subtitle: 'انتقال سريع لإضافة مادة للمخزون', type: 'action', routePath: '/inventory/add'),
    CommandSearchResult(id: 'act2', title: 'إنشاء فاتورة جديدة', subtitle: 'فتح نافذة تحصيل سريعة', type: 'action', routePath: '/collection/invoice/new'),
    CommandSearchResult(id: 'act3', title: 'إضافة عميل', subtitle: 'تسجيل عميل جديد في النظام', type: 'action', routePath: '/customers/new'),
  ];

  @override
  List<CommandSearchResult> getQuickActions() => _staticActions;

  @override
  Stream<List<CommandSearchResult>> globalSearch(String query) {
    if (query.isEmpty) {
      _controller.add(_staticActions);
      return _controller.stream;
    }

    final List<CommandSearchResult> mockDatabase = [
      CommandSearchResult(id: '1', title: 'حاسوب محمول عالي الأداء', subtitle: 'مخزون — LAP-001', type: 'product', routePath: '/inventory'),
      CommandSearchResult(id: 'c1', title: 'مؤسسة أحمد التجارية', subtitle: 'عميل — الرياض', type: 'customer', routePath: '/customers'),
      CommandSearchResult(id: 'inv2', title: 'فاتورة شركة النور للتموين', subtitle: 'مالية — بقيمة 1400 ر.س', type: 'invoice', routePath: '/collection'),
    ];

    final results = mockDatabase.where((item) => 
      item.title.contains(query) || item.subtitle.contains(query)
    ).toList();

    results.addAll(_staticActions.where((act) => act.title.contains(query)));

    Timer(const Duration(milliseconds: 150), () => _controller.add(results));
    return _controller.stream;
  }
}
