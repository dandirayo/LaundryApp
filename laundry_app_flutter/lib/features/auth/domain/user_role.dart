enum UserRole {
  owner,
  employee;

  String get storageValue {
    return switch (this) {
      UserRole.owner => 'OWNER',
      UserRole.employee => 'EMPLOYEE',
    };
  }

  String get label {
    return switch (this) {
      UserRole.owner => 'Owner',
      UserRole.employee => 'Karyawan',
    };
  }

  static UserRole fromStorageValue(String value) {
    return switch (value.toUpperCase()) {
      'OWNER' => UserRole.owner,
      'EMPLOYEE' || 'KARYAWAN' => UserRole.employee,
      _ => throw ArgumentError('Role tidak dikenal: $value'),
    };
  }
}
