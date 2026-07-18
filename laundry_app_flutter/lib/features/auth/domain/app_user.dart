import 'user_role.dart';

class AppUser {
  const AppUser({
    required this.userId,
    required this.shopId,
    required this.name,
    required this.role,
    required this.isActive,
    this.employeeId,
    this.photoUrl,
    this.phone,
  });

  final String userId;
  final String shopId;
  final String? employeeId;
  final String name;
  final UserRole role;
  final bool isActive;
  final String? photoUrl;
  final String? phone;

  bool get isOwner => role == UserRole.owner;

  AppUser copyWith({String? name, String? phone, String? photoUrl}) {
    return AppUser(
      userId: userId,
      shopId: shopId,
      employeeId: employeeId,
      name: name ?? this.name,
      role: role,
      isActive: isActive,
      photoUrl: photoUrl ?? this.photoUrl,
      phone: phone ?? this.phone,
    );
  }

  factory AppUser.fromProfileMap(Map<String, dynamic> map) {
    return AppUser(
      userId: map['id'] as String,
      shopId: map['shop_id'] as String,
      employeeId: map['employee_id'] as String?,
      name: (map['full_name'] ?? map['name'] ?? 'Pengguna') as String,
      role: UserRole.fromStorageValue(map['role'] as String),
      isActive: (map['is_active'] ?? true) as bool,
      photoUrl: map['avatar_url'] as String?,
      phone: map['phone'] as String?,
    );
  }

  Map<String, String> toStorageMap() {
    final values = {
      'userId': userId,
      'shopId': shopId,
      'name': name,
      'role': role.storageValue,
      'isActive': isActive.toString(),
    };
    if (employeeId != null) {
      values['employeeId'] = employeeId!;
    }
    if (photoUrl != null) {
      values['photoUrl'] = photoUrl!;
    }
    if (phone != null) {
      values['phone'] = phone!;
    }
    return values;
  }

  factory AppUser.fromStorageMap(Map<String, String> map) {
    return AppUser(
      userId: map['userId'] ?? '',
      shopId: map['shopId'] ?? '',
      employeeId: map['employeeId'],
      name: map['name'] ?? 'Pengguna',
      role: UserRole.fromStorageValue(map['role'] ?? 'EMPLOYEE'),
      isActive: map['isActive'] != 'false',
      photoUrl: map['photoUrl'],
      phone: map['phone'],
    );
  }
}
