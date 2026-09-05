import 'package:flutter_contacts/flutter_contacts.dart';

import '../domain/contact_import.dart';

final class DeviceContactRepository {
  Future<bool> requestReadPermission() async {
    final permission = await FlutterContacts.permissions.request(
      PermissionType.read,
    );
    return permission == PermissionStatus.granted ||
        permission == PermissionStatus.limited;
  }

  Future<List<Account>> fetchAccounts() => FlutterContacts.accounts.getAll();

  Future<List<ContactImportCandidate>> fetchContactCandidates({
    required Account account,
  }) async {
    final contacts = await FlutterContacts.getAll(
      properties: {ContactProperty.phone},
      account: account,
    );
    return contacts
        .where((contact) => (contact.displayName ?? '').trim().isNotEmpty)
        .map(
          (contact) => ContactImportCandidate(
            name: (contact.displayName ?? '').trim(),
            phones: distinctContactPhones(
              contact.phones.map((phone) => phone.number),
            ),
          ),
        )
        .toList()
      ..sort(
        (first, second) =>
            first.name.toLowerCase().compareTo(second.name.toLowerCase()),
      );
  }

  Future<void> openSettings() {
    return FlutterContacts.permissions.openSettings();
  }
}
