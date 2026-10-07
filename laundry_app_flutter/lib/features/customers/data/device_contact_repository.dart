import 'dart:async';

import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/contact_import.dart';
import '../domain/customer.dart';

class DeviceContactMergeCandidate {
  const DeviceContactMergeCandidate({
    required this.customer,
    required this.contact,
  });

  final Customer customer;
  final Contact contact;
}

class DeviceContactExportResult {
  const DeviceContactExportResult({
    required this.createdCount,
    required this.updatedCount,
    required this.skippedNoPhoneCount,
    required this.mergeCandidates,
  });

  final int createdCount;
  final int updatedCount;
  final int skippedNoPhoneCount;
  final List<DeviceContactMergeCandidate> mergeCandidates;
}

final class DeviceContactRepository {
  static const _accountNameKey = 'customer_google_account_name';
  static const _accountTypeKey = 'customer_google_account_type';
  Account? _selectedAccount;

  Future<bool> requestReadPermission() async {
    final permission = await FlutterContacts.permissions.request(
      PermissionType.read,
    );
    return permission == PermissionStatus.granted ||
        permission == PermissionStatus.limited;
  }

  Future<bool> requestReadWritePermission() async {
    final permission = await FlutterContacts.permissions.request(
      PermissionType.readWrite,
    );
    return permission == PermissionStatus.granted ||
        permission == PermissionStatus.limited;
  }

  Future<List<Account>> fetchAccounts() => FlutterContacts.accounts.getAll();

  Future<List<ContactImportCandidate>> fetchContactCandidates({
    required Account account,
  }) async {
    await rememberGoogleAccount(account);
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

  Future<void> rememberGoogleAccount(Account account) async {
    _selectedAccount = account;
    unawaited(_persistGoogleAccount(account));
  }

  Future<void> _persistGoogleAccount(Account account) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_accountNameKey, account.name);
      await preferences.setString(_accountTypeKey, account.type);
    } catch (_) {
      // The selected account remains available for this page session.
    }
  }

  Future<Account?> preferredGoogleAccount() async {
    final selected = _selectedAccount;
    if (selected != null) return selected;
    try {
      final preferences = await SharedPreferences.getInstance();
      final name = preferences.getString(_accountNameKey);
      final type = preferences.getString(_accountTypeKey);
      if (name == null || type == null) return null;
      final accounts = await fetchAccounts();
      _selectedAccount = accounts
          .where((account) => account.name == name && account.type == type)
          .firstOrNull;
      return _selectedAccount;
    } catch (_) {
      return null;
    }
  }

  Future<DeviceContactExportResult> exportCustomers({
    required Account account,
    required Iterable<Customer> customers,
    bool mergeNameConflicts = false,
  }) async {
    await rememberGoogleAccount(account);
    final contacts = await FlutterContacts.getAll(
      properties: {ContactProperty.name, ContactProperty.phone},
      account: account,
    );
    var createdCount = 0;
    var updatedCount = 0;
    var skippedNoPhoneCount = 0;
    final mergeCandidates = <DeviceContactMergeCandidate>[];

    for (final customer in customers) {
      final phone = customer.phone?.trim() ?? '';
      final normalizedPhone = Customer.normalizeIndonesianPhone(phone);
      if (normalizedPhone == null) {
        skippedNoPhoneCount++;
        continue;
      }
      final contactName = customerNameWithCs(customer.name);
      final phoneMatch = contacts.where((contact) {
        return contact.phones.any(
          (entry) =>
              Customer.normalizeIndonesianPhone(entry.number) ==
              normalizedPhone,
        );
      }).firstOrNull;
      if (phoneMatch != null) {
        if ((phoneMatch.displayName ?? '').trim() != contactName) {
          await FlutterContacts.update(
            phoneMatch.copyWith(name: Name(first: contactName)),
          );
          updatedCount++;
        }
        continue;
      }

      final nameMatch = contacts.where((contact) {
        return normalizedCustomerName(contact.displayName ?? '') ==
            normalizedCustomerName(contactName);
      }).firstOrNull;
      if (nameMatch != null) {
        if (!mergeNameConflicts) {
          mergeCandidates.add(
            DeviceContactMergeCandidate(customer: customer, contact: nameMatch),
          );
          continue;
        }
        final phones = distinctContactPhones([
          ...nameMatch.phones.map((entry) => entry.number),
          phone,
        ]).map((number) => Phone(number: number)).toList();
        await FlutterContacts.update(
          nameMatch.copyWith(
            name: Name(first: contactName),
            phones: phones,
          ),
        );
        updatedCount++;
        continue;
      }

      await FlutterContacts.create(
        Contact(
          name: Name(first: contactName),
          phones: [Phone(number: phone)],
        ),
        account: account,
      );
      createdCount++;
    }

    return DeviceContactExportResult(
      createdCount: createdCount,
      updatedCount: updatedCount,
      skippedNoPhoneCount: skippedNoPhoneCount,
      mergeCandidates: mergeCandidates,
    );
  }

  Future<void> openSettings() {
    return FlutterContacts.permissions.openSettings();
  }
}
