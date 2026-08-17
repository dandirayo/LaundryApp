class Customer {
  const Customer({
    required this.id,
    required this.shopId,
    required this.name,
    required this.address,
    required this.note,
    required this.createdAt,
    this.phone,
    this.normalizedPhone,
    this.updatedAt,
  });

  final String id;
  final String shopId;
  final String name;
  final String? phone;
  final String? normalizedPhone;
  final String address;
  final String note;
  final DateTime createdAt;
  final DateTime? updatedAt;

  bool get hasPhone =>
      phone != null &&
      phone!.trim().isNotEmpty &&
      normalizedPhone != null &&
      normalizedPhone!.isNotEmpty;

  Customer copyWith({
    String? name,
    Object? phone = _sentinel,
    Object? normalizedPhone = _sentinel,
    String? address,
    String? note,
    DateTime? updatedAt,
  }) {
    return Customer(
      id: id,
      shopId: shopId,
      name: name ?? this.name,
      phone: phone == _sentinel ? this.phone : phone as String?,
      normalizedPhone: normalizedPhone == _sentinel
          ? this.normalizedPhone
          : normalizedPhone as String?,
      address: address ?? this.address,
      note: note ?? this.note,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map['id'] as String,
      shopId: map['shop_id'] as String,
      name: (map['name'] ?? '') as String,
      phone: _nullableText(map['phone']),
      normalizedPhone: _nullableText(map['normalized_phone']),
      address: (map['address'] ?? '') as String,
      note: (map['note'] ?? '') as String,
      createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
      updatedAt: map['updated_at'] == null
          ? null
          : DateTime.parse(map['updated_at'] as String).toLocal(),
    );
  }

  static String? phoneFromInput(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static String? normalizeIndonesianPhone(String value) {
    var phone = value.trim().replaceAll(RegExp(r'[^0-9+]'), '');
    if (phone.isEmpty) {
      return null;
    }
    if (phone.startsWith('+62')) {
      phone = phone.substring(1);
    } else if (phone.startsWith('0')) {
      phone = '62${phone.substring(1)}';
    }
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.isEmpty ? null : digits;
  }

  static bool isValidOptionalPhone(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return true;
    }
    final normalized = normalizeIndonesianPhone(trimmed);
    return normalized != null && normalized.length >= 8;
  }

  static String? _nullableText(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}

const _sentinel = Object();
