import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../models/inventory_item.dart';

class FirestoreInventoryRepository implements InventoryRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _inventoryCollection => _firestore.collection('inventory');

  @override
  Stream<List<InventoryItem>> getInventoryItems() {
    return _inventoryCollection
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return InventoryItem.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  @override
  Future<void> addItem(InventoryItem item) async {
    await _inventoryCollection.add(item.toMap());
  }

  @override
  Future<void> updateItem(InventoryItem item) async {
    await _inventoryCollection.doc(item.id).update(item.toMap());
  }

  @override
  Future<void> deleteItem(String id) async {
    await _inventoryCollection.doc(id).delete();
  }
}
