import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:async/async.dart' show StreamGroup;
import '../../domain/repositories/command_dock_repository.dart';
import '../models/command_search_result.dart';

class FirestoreCommandDockRepository implements CommandDockRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  List<CommandSearchResult> getQuickActions() {
    return [
      CommandSearchResult(id: 'act1', title: 'إضافة منتج جديد', subtitle: 'انتقال سريع لإضافة مادة للمخزون', type: 'action', routePath: '/inventory/add'),
      CommandSearchResult(id: 'act2', title: 'إنشاء فاتورة جديدة', subtitle: 'فتح نافذة تحصيل سريعة', type: 'action', routePath: '/collection/invoice/new'),
      CommandSearchResult(id: 'act3', title: 'إضافة عميل', subtitle: 'تسجيل عميل جديد في النظام', type: 'action', routePath: '/customers/new'),
    ];
  }

  @override
  Stream<List<CommandSearchResult>> globalSearch(String query) {
    if (query.isEmpty) {
      return Stream.value(getQuickActions());
    }

    final productsStream = _firestore.collection('inventory').snapshots();
    final customersStream = _firestore.collection('customers').snapshots();

    return StreamGroup.merge([productsStream, customersStream]).asyncMap((_) async {
      final prodSnap = await _firestore.collection('inventory')
          .where('name', isGreaterThanOrEqualTo: query)
          .where('name', isLessThanOrEqualTo: '$query\uf8ff')
          .get();

      final custSnap = await _firestore.collection('customers')
          .where('name', isGreaterThanOrEqualTo: query)
          .where('name', isLessThanOrEqualTo: '$query\uf8ff')
          .get();

      final List<CommandSearchResult> results = [];

      for (var doc in prodSnap.docs) {
        final data = doc.data();
        results.add(CommandSearchResult(
          id: doc.id, 
          title: data['name'] ?? '', 
          subtitle: 'مخزون — SKU: ${data['sku']}', 
          type: 'product', 
          routePath: '/inventory'
        ));
      }

      for (var doc in custSnap.docs) {
        final data = doc.data();
        results.add(CommandSearchResult(
          id: doc.id, 
          title: data['name'] ?? '', 
          subtitle: 'عميل — ${data['phone']}', 
          type: 'customer', 
          routePath: '/customers'
        ));
      }

      results.addAll(getQuickActions().where((act) => act.title.contains(query)));
      return results;
    });
  }
}
