import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/repositories/customer_repository.dart';
import '../models/customer_model.dart';

class FirestoreCustomerRepository implements CustomerRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _customersCollection =>
      _firestore.collection('customers');

  @override
  Stream<List<CustomerModel>> getCustomers() {
    return _customersCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return CustomerModel.fromMap(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );
      }).toList();
    });
  }

  @override
  Future<void> addCustomer(CustomerModel customer) async {
    await _customersCollection.add(customer.toMap());
  }

  @override
  Future<void> updateCustomer(CustomerModel customer) async {
    await _customersCollection.doc(customer.id).update(customer.toMap());
  }

  @override
  Future<void> deleteCustomer(String id) async {
    await _customersCollection.doc(id).delete();
  }
}
