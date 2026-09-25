class PosProduct {
  const PosProduct({
    required this.id,
    required this.businessId,
    required this.name,
    required this.category,
    required this.price,
    required this.isActive,
  });

  final String id;
  final String businessId;
  final String name;
  final String category;
  final int price;
  final bool isActive;

  PosProduct copyWith({
    String? name,
    String? category,
    int? price,
    bool? isActive,
  }) => PosProduct(
    id: id,
    businessId: businessId,
    name: name ?? this.name,
    category: category ?? this.category,
    price: price ?? this.price,
    isActive: isActive ?? this.isActive,
  );

  factory PosProduct.fromMap(Map<String, dynamic> map) => PosProduct(
    id: map['id'] as String,
    businessId: map['business_id'] as String,
    name: (map['name'] ?? 'Produk') as String,
    category: (map['category'] ?? 'Minuman') as String,
    price: (map['price'] as num? ?? 0).toInt(),
    isActive: (map['is_active'] ?? true) as bool,
  );
}

class PosSale {
  const PosSale({
    required this.id,
    required this.businessId,
    required this.saleNumber,
    required this.total,
    required this.paymentMethod,
    required this.createdAt,
  });

  final String id;
  final String businessId;
  final String saleNumber;
  final int total;
  final String paymentMethod;
  final DateTime createdAt;

  factory PosSale.fromMap(Map<String, dynamic> map) => PosSale(
    id: map['id'] as String,
    businessId: map['business_id'] as String,
    saleNumber: (map['sale_number'] ?? '') as String,
    total: (map['total'] as num? ?? 0).toInt(),
    paymentMethod: (map['payment_method'] ?? 'Tunai') as String,
    createdAt:
        DateTime.tryParse((map['created_at'] ?? '') as String)?.toLocal() ??
        DateTime.now(),
  );
}
