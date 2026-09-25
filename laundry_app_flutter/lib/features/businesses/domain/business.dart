enum BusinessKind {
  laundry,
  beverage;

  String get storageValue => name;

  String get label => switch (this) {
    BusinessKind.laundry => 'Laundry',
    BusinessKind.beverage => 'POS Minuman',
  };

  factory BusinessKind.fromStorage(String value) => switch (value) {
    'beverage' => BusinessKind.beverage,
    _ => BusinessKind.laundry,
  };
}

class Business {
  const Business({
    required this.id,
    required this.shopId,
    required this.ownerId,
    required this.name,
    required this.kind,
    required this.isActive,
  });

  final String id;
  final String shopId;
  final String ownerId;
  final String name;
  final BusinessKind kind;
  final bool isActive;

  Business copyWith({String? name, bool? isActive}) => Business(
    id: id,
    shopId: shopId,
    ownerId: ownerId,
    name: name ?? this.name,
    kind: kind,
    isActive: isActive ?? this.isActive,
  );

  factory Business.fromMap(Map<String, dynamic> map) => Business(
    id: map['id'] as String,
    shopId: map['shop_id'] as String,
    ownerId: map['owner_id'] as String,
    name: (map['name'] ?? 'Usaha') as String,
    kind: BusinessKind.fromStorage((map['kind'] ?? 'laundry') as String),
    isActive: map['status'] == 'active',
  );
}

class BusinessAssignee {
  const BusinessAssignee({
    required this.profileId,
    required this.employeeId,
    required this.name,
  });

  final String profileId;
  final String? employeeId;
  final String name;
}
