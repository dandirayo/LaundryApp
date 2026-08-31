import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_app_flutter/features/customers/domain/contact_import.dart';
import 'package:laundry_app_flutter/features/customers/domain/customer.dart';

void main() {
  group('contact import mapping', () {
    test('normalizes Indonesian phone and preserves name-only contact', () {
      const withPhone = ContactImportSelection(
        name: 'Budi',
        phone: '0812-3456-7890',
      );
      const withoutPhone = ContactImportSelection(name: 'Siti', phone: '');

      expect(withPhone.normalizedPhone, '6281234567890');
      expect(withoutPhone.normalizedPhone, isNull);
    });

    test('keeps distinct normalized numbers for multiple-phone selection', () {
      final phones = distinctContactPhones([
        '0812 3456 7890',
        '+62 812-3456-7890',
        '0813 0000 0000',
        '',
      ]);

      expect(phones, ['0812 3456 7890', '0813 0000 0000']);
    });
  });

  test('duplicate detection uses normalized phone and not customer name', () {
    final customers = [
      Customer(
        id: 'customer-1',
        shopId: 'shop-1',
        name: 'Nama Berbeda',
        phone: '0812 3456 7890',
        normalizedPhone: '6281234567890',
        address: '',
        note: '',
        createdAt: DateTime(2026),
      ),
    ];

    expect(
      findCustomerWithNormalizedPhone(customers, '+62 812 3456 7890')?.id,
      'customer-1',
    );
    expect(findCustomerWithNormalizedPhone(customers, ''), isNull);
  });

  test('bulk import plan skips existing, invalid, and no-phone contacts', () {
    final existingCustomers = [
      Customer(
        id: 'customer-1',
        shopId: 'shop-1',
        name: 'Budi Lama',
        phone: '0812 3456 7890',
        normalizedPhone: '6281234567890',
        address: '',
        note: '',
        createdAt: DateTime(2026),
      ),
    ];

    final plan = buildContactImportPlan(
      candidates: const [
        ContactImportCandidate(
          name: 'Budi Duplikat',
          phones: ['+62 812-3456-7890'],
        ),
        ContactImportCandidate(name: 'Siti', phones: ['0813 0000 0000']),
        ContactImportCandidate(name: 'Nomor Pendek', phones: ['123']),
        ContactImportCandidate(name: 'Tanpa Nomor', phones: []),
        ContactImportCandidate(
          name: 'Nomor Kedua',
          phones: ['0812 3456 7890', '0814 0000 0000'],
        ),
      ],
      existingCustomers: existingCustomers,
    );

    expect(plan.selections.map((selection) => selection.name), [
      'Siti',
      'Nomor Kedua',
    ]);
    expect(plan.selections.map((selection) => selection.normalizedPhone), [
      '6281300000000',
      '6281400000000',
    ]);
    expect(plan.duplicatePhoneCount, 2);
    expect(plan.invalidPhoneCount, 1);
    expect(plan.noPhoneCount, 1);
  });
}
