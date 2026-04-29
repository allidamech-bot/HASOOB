import 'package:flutter_test/flutter_test.dart';
import 'package:hasoob_app/core/permissions/permissions.dart';

void main() {
  group('AppPermissions', () {
    test('owner can delete', () {
      expect(AppPermissions.canDelete('owner'), isTrue);
    });

    test('manager cannot delete', () {
      expect(AppPermissions.canDelete('manager'), isFalse);
    });

    test('employee cannot delete', () {
      expect(AppPermissions.canDelete('employee'), isFalse);
    });

    test('employee cannot edit products', () {
      expect(AppPermissions.canEditProducts('employee'), isFalse);
    });

    test('manager can edit products', () {
      expect(AppPermissions.canEditProducts('manager'), isTrue);
    });

    test('owner can edit products', () {
      expect(AppPermissions.canEditProducts('owner'), isTrue);
    });

    test('everyone can sell', () {
      expect(AppPermissions.canSell('owner'), isTrue);
      expect(AppPermissions.canSell('manager'), isTrue);
      expect(AppPermissions.canSell('employee'), isTrue);
    });

    test('only owner can manage users', () {
      expect(AppPermissions.canManageUsers('owner'), isTrue);
      expect(AppPermissions.canManageUsers('manager'), isFalse);
      expect(AppPermissions.canManageUsers('employee'), isFalse);
    });
  });
}
