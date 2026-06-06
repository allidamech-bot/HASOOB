import 'dart:async';
import '../../domain/repositories/customer_repository.dart';
import '../models/customer_model.dart';

class MockCustomerRepository implements CustomerRepository {
  final List<CustomerModel> _mockCustomers = [
    CustomerModel(
      id: '1',
      name: 'أحمد محمد العمري',
      phone: '+966501234567',
      email: 'ahmed.omari@example.com',
      address: 'الرياض، حي النزهة، شارع الملك فهد',
      status: 'active',
      createdAt: DateTime.now().subtract(const Duration(days: 120)),
      tags: ['vip', 'wholesale'],
    ),
    CustomerModel(
      id: '2',
      name: 'سارة عبدالله الحربي',
      phone: '+966509876543',
      email: 'sara.harbi@example.com',
      address: 'جدة، حي الروضة، شارع التحلية',
      status: 'active',
      createdAt: DateTime.now().subtract(const Duration(days: 60)),
      tags: ['retail'],
    ),
    CustomerModel(
      id: '3',
      name: 'خالد سالم القحطاني',
      phone: '+966555123456',
      email: 'khalid.qahtani@example.com',
      address: 'الدمام، حي الشاطئ، شارع الأمير محمد',
      status: 'inactive',
      createdAt: DateTime.now().subtract(const Duration(days: 200)),
      tags: ['wholesale'],
    ),
    CustomerModel(
      id: '4',
      name: 'نورة فهد الدوسري',
      phone: '+966502468135',
      email: 'noura.dosari@example.com',
      address: 'مكة المكرمة، حي العزيزية',
      status: 'active',
      createdAt: DateTime.now().subtract(const Duration(days: 15)),
      tags: ['new', 'retail'],
    ),
  ];

  final _controller = StreamController<List<CustomerModel>>.broadcast();

  MockCustomerRepository() {
    _controller.add(_mockCustomers);
  }

  @override
  Stream<List<CustomerModel>> getCustomers() {
    Timer(
      const Duration(milliseconds: 300),
      () => _controller.add(_mockCustomers),
    );
    return _controller.stream;
  }

  @override
  Future<void> addCustomer(CustomerModel customer) async {
    _mockCustomers.add(customer);
    _controller.add(_mockCustomers);
  }

  @override
  Future<void> updateCustomer(CustomerModel customer) async {
    final index =
        _mockCustomers.indexWhere((element) => element.id == customer.id);
    if (index != -1) {
      _mockCustomers[index] = customer;
      _controller.add(_mockCustomers);
    }
  }

  @override
  Future<void> deleteCustomer(String id) async {
    _mockCustomers.removeWhere((element) => element.id == id);
    _controller.add(_mockCustomers);
  }
}
