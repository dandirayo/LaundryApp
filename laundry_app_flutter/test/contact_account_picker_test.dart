import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_app_flutter/features/customers/data/device_contact_repository.dart';
import 'package:laundry_app_flutter/features/customers/presentation/contact_account_picker.dart';

void main() {
  const channel = MethodChannel('flutter_contacts');
  for (final cancel in [false, true]) {
    testWidgets(
      cancel
          ? 'cancel does not read contacts'
          : 'reads only selected Google account',
      (tester) async {
        final reads = <dynamic>[];
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          (call) async {
            if (call.method == 'accounts.getAll') {
              return [
                {
                  'id': '',
                  'name': 'personal@example.com',
                  'type': 'com.google',
                },
                {'id': '', 'name': 'laundry@example.com', 'type': 'com.google'},
              ];
            }
            if (call.method == 'crud.getAll') {
              reads.add(call.arguments);
              return [];
            }
            throw StateError('Unexpected method: ${call.method}');
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            channel,
            null,
          ),
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(splashFactory: InkRipple.splashFactory),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => fetchContactsFromSelectedAccount(
                    context,
                    DeviceContactRepository(),
                  ),
                  child: const Text('Sync'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Sync'));
        await tester.pumpAndSettle();
        expect(find.text('personal@example.com'), findsOneWidget);
        expect(reads, isEmpty);
        await tester.tap(find.text(cancel ? 'Batal' : 'laundry@example.com'));
        await tester.pumpAndSettle();
        if (cancel) {
          expect(reads, isEmpty);
        } else {
          expect(reads.single['account']['name'], 'laundry@example.com');
          expect(reads.single['account']['type'], 'com.google');
        }
      },
    );
  }
}
