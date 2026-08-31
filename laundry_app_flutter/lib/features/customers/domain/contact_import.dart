import 'customer.dart';

class ContactImportCandidate {
  const ContactImportCandidate({
    required this.name,
    required this.phones,
    this.address = '',
  });

  final String name;
  final List<String> phones;
  final String address;

  String get primaryPhone => phones.firstOrNull ?? '';
}

class ContactImportSelection {
  const ContactImportSelection({
    required this.name,
    required this.phone,
    this.address = '',
  });

  final String name;
  final String phone;
  final String address;

  String? get normalizedPhone => Customer.normalizeIndonesianPhone(phone);
}

class ContactImportPlan {
  const ContactImportPlan({
    required this.selections,
    required this.duplicatePhoneCount,
    required this.invalidPhoneCount,
    required this.noPhoneCount,
  });

  final List<ContactImportSelection> selections;
  final int duplicatePhoneCount;
  final int invalidPhoneCount;
  final int noPhoneCount;

  int get importableCount => selections.length;
  int get skippedCount =>
      duplicatePhoneCount + invalidPhoneCount + noPhoneCount;
}

class ContactSyncResult {
  const ContactSyncResult({
    required this.importedCount,
    required this.duplicatePhoneCount,
    required this.invalidPhoneCount,
    required this.noPhoneCount,
  });

  final int importedCount;
  final int duplicatePhoneCount;
  final int invalidPhoneCount;
  final int noPhoneCount;

  int get skippedCount =>
      duplicatePhoneCount + invalidPhoneCount + noPhoneCount;
}

List<String> distinctContactPhones(Iterable<String> phones) {
  final seen = <String>{};
  final result = <String>[];
  for (final rawPhone in phones) {
    final phone = rawPhone.trim();
    if (phone.isEmpty) continue;
    final key = Customer.normalizeIndonesianPhone(phone) ?? phone;
    if (seen.add(key)) result.add(phone);
  }
  return result;
}

Customer? findCustomerWithNormalizedPhone(
  Iterable<Customer> customers,
  String phone,
) {
  final normalized = Customer.normalizeIndonesianPhone(phone);
  if (normalized == null) return null;
  return customers
      .where((customer) => customer.normalizedPhone == normalized)
      .firstOrNull;
}

ContactImportPlan buildContactImportPlan({
  required Iterable<ContactImportCandidate> candidates,
  required Iterable<Customer> existingCustomers,
}) {
  final seenPhones = {
    for (final customer in existingCustomers)
      if ((customer.normalizedPhone ?? '').trim().isNotEmpty)
        customer.normalizedPhone!.trim(),
  };
  final selections = <ContactImportSelection>[];
  var duplicatePhoneCount = 0;
  var invalidPhoneCount = 0;
  var noPhoneCount = 0;

  for (final candidate in candidates) {
    final name = candidate.name.trim();
    if (name.isEmpty) {
      continue;
    }

    final phones = distinctContactPhones(candidate.phones);
    if (phones.isEmpty) {
      noPhoneCount++;
      continue;
    }

    for (final phone in phones) {
      final normalizedPhone = Customer.normalizeIndonesianPhone(phone);
      if (normalizedPhone == null || normalizedPhone.length < 8) {
        invalidPhoneCount++;
        continue;
      }
      if (!seenPhones.add(normalizedPhone)) {
        duplicatePhoneCount++;
        continue;
      }

      selections.add(
        ContactImportSelection(
          name: name,
          phone: phone,
          address: candidate.address,
        ),
      );
      break;
    }
  }

  return ContactImportPlan(
    selections: selections,
    duplicatePhoneCount: duplicatePhoneCount,
    invalidPhoneCount: invalidPhoneCount,
    noPhoneCount: noPhoneCount,
  );
}
