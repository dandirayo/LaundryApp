import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_app_flutter/features/customers/data/device_contact_repository.dart';
import 'package:laundry_app_flutter/features/customers/domain/customer.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('flutter_contacts');
  const account = Account(
    id: '',
    name: 'laundry@example.com',
    type: 'com.google',
  );

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'nomor sama memperbarui nama Google menjadi CS tanpa membuat duplikat',
    () async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            if (call.method == 'crud.getAll') {
              return [
                const Contact(
                  id: 'google-1',
                  displayName: 'Ayu',
                  name: Name(first: 'Ayu'),
                  phones: [Phone(number: '0812 0000 0001')],
                ).toJson(),
              ];
            }
            if (call.method == 'crud.update') return null;
            throw StateError('Unexpected method: ${call.method}');
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );

      final result = await DeviceContactRepository().exportCustomers(
        account: account,
        customers: [_customer(name: 'Ayu', phone: '081200000001')],
      );

      expect(result.createdCount, 0);
      expect(result.updatedCount, 1);
      final update = calls.singleWhere((call) => call.method == 'crud.update');
      final contact = Contact.fromJson(
        (update.arguments as Map)['contact'] as Map,
      );
      expect(contact.name?.first, 'Ayu CS');
    },
  );

  test(
    'nama sama dan nomor berbeda meminta merge sebelum menambah nomor',
    () async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            if (call.method == 'crud.getAll') {
              return [
                const Contact(
                  id: 'google-1',
                  displayName: 'Ayu CS',
                  name: Name(first: 'Ayu CS'),
                  phones: [Phone(number: '0812 0000 0001')],
                ).toJson(),
              ];
            }
            if (call.method == 'crud.update') return null;
            throw StateError('Unexpected method: ${call.method}');
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final repository = DeviceContactRepository();
      final customer = _customer(name: 'Ayu CS', phone: '081200000002');

      final pending = await repository.exportCustomers(
        account: account,
        customers: [customer],
      );
      expect(pending.mergeCandidates, hasLength(1));
      expect(calls.where((call) => call.method == 'crud.update'), isEmpty);

      final merged = await repository.exportCustomers(
        account: account,
        customers: [customer],
        mergeNameConflicts: true,
      );
      expect(merged.updatedCount, 1);
      final update = calls.lastWhere((call) => call.method == 'crud.update');
      final contact = Contact.fromJson(
        (update.arguments as Map)['contact'] as Map,
      );
      expect(contact.phones.map((phone) => phone.number), [
        '0812 0000 0001',
        '081200000002',
      ]);
    },
  );
}

Customer _customer({required String name, required String phone}) => Customer(
  id: 'customer-1',
  shopId: 'shop-1',
  name: name,
  phone: phone,
  normalizedPhone: Customer.normalizeIndonesianPhone(phone),
  address: '',
  note: '',
  createdAt: DateTime(2026),
);
