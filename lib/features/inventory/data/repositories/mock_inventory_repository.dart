import 'dart:async';
import '../../domain/repositories/inventory_repository.dart';
import '../models/inventory_item.dart';

class MockInventoryRepository implements InventoryRepository {
  final List<InventoryItem> _mockItems = [
    InventoryItem(id: '1', name: 'حاسوب محمول عالي الأداء', sku: 'LAP-001', quantity: 15, price: 1200.0, category: 'أجهزة', updatedAt: DateTime.now()),
    InventoryItem(id: '2', name: 'شاشة 4K ذكية', sku: 'MON-04K', quantity: 8, price: 350.0, category: 'شاشات', updatedAt: DateTime.now()),
    InventoryItem(id: '3', name: 'لوحة مفاتيح ميكانيكية صامتة', sku: 'KEY-RGB', quantity: 45, price: 75.0, category: 'ملحقات', updatedAt: DateTime.now()),
    InventoryItem(id: '4', name: 'فأرة لاسلكية مريحة', sku: 'MSE-WRL', quantity: 60, price: 45.0, category: 'ملحقات', updatedAt: DateTime.now()),
  ];

  final _controller = StreamController<List<InventoryItem>>.broadcast();

  MockInventoryRepository() {
    _controller.add(_mockItems);
  }

  @override
  Stream<List<InventoryItem>> getInventoryItems() {
    Timer(const Duration(milliseconds: 300), () => _controller.add(_mockItems));
    return _controller.stream;
  }

  @override
  Future<void> addItem(InventoryItem item) async {
    _mockItems.add(item);
    _controller.add(_mockItems);
  }

  @override
  Future<void> updateItem(InventoryItem item) async {
    final index = _mockItems.indexWhere((element) => element.id == item.id);
    if (index != -1) {
      _mockItems[index] = item;
      _controller.add(_mockItems);
    }
  }

  @override
  Future<void> deleteItem(String id) async {
    _mockItems.removeWhere((element) => element.id == id);
    _controller.add(_mockItems);
  }
}
