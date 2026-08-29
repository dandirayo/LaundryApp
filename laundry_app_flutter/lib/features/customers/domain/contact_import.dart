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
