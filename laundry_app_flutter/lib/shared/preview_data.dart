import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'imported_contacts.dart';

final previewDataProvider =
    NotifierProvider<PreviewDataController, PreviewDataState>(
      PreviewDataController.new,
    );

const _uuid = Uuid();

enum PreviewOrderStatus {
  received('Diterima'),
  processing('Diproses'),
  ready('Selesai'),
  pickedUp('Diambil'),
  cancelled('Dibatalkan');

  const PreviewOrderStatus(this.label);

  final String label;
}

enum PreviewPaymentStatus {
  unpaid('Belum bayar'),
  partiallyPaid('DP'),
  paid('Lunas');

  const PreviewPaymentStatus(this.label);

  final String label;
}

enum PreviewRequestStatus {
  pending('Menunggu'),
  approved('Disetujui'),
  rejected('Ditolak'),
  paid('Dibayar'),
  completed('Selesai');

  const PreviewRequestStatus(this.label);

  final String label;
}

class PreviewDataState {
  const PreviewDataState({
    required this.customers,
    required this.services,
    required this.orders,
    required this.payments,
    required this.cashTransactions,
    required this.inventory,
    required this.inventoryMovements,
    required this.employees,
    required this.attendance,
    required this.shifts,
    required this.requests,
    required this.notifications,
    required this.expenses,
    required this.shopName,
    required this.shopAddress,
    required this.weeklySalaryAmount,
    this.lastBackupAt,
  });

  final List<PreviewCustomer> customers;
  final List<PreviewService> services;
  final List<PreviewOrder> orders;
  final List<PreviewPayment> payments;
  final List<PreviewCashTransaction> cashTransactions;
  final List<PreviewInventoryItem> inventory;
  final List<PreviewInventoryMovement> inventoryMovements;
  final List<PreviewEmployee> employees;
  final List<PreviewAttendance> attendance;
  final List<PreviewShift> shifts;
  final List<PreviewEmployeeRequest> requests;
  final List<PreviewNotification> notifications;
  final List<PreviewExpense> expenses;
  final String shopName;
  final String shopAddress;
  final int weeklySalaryAmount;
  final DateTime? lastBackupAt;

  PreviewDataState copyWith({
    List<PreviewCustomer>? customers,
    List<PreviewService>? services,
    List<PreviewOrder>? orders,
    List<PreviewPayment>? payments,
    List<PreviewCashTransaction>? cashTransactions,
    List<PreviewInventoryItem>? inventory,
    List<PreviewInventoryMovement>? inventoryMovements,
    List<PreviewEmployee>? employees,
    List<PreviewAttendance>? attendance,
    List<PreviewShift>? shifts,
    List<PreviewEmployeeRequest>? requests,
    List<PreviewNotification>? notifications,
    List<PreviewExpense>? expenses,
    String? shopName,
    String? shopAddress,
    int? weeklySalaryAmount,
    DateTime? lastBackupAt,
  }) {
    return PreviewDataState(
      customers: customers ?? this.customers,
      services: services ?? this.services,
      orders: orders ?? this.orders,
      payments: payments ?? this.payments,
      cashTransactions: cashTransactions ?? this.cashTransactions,
      inventory: inventory ?? this.inventory,
      inventoryMovements: inventoryMovements ?? this.inventoryMovements,
      employees: employees ?? this.employees,
      attendance: attendance ?? this.attendance,
      shifts: shifts ?? this.shifts,
      requests: requests ?? this.requests,
      notifications: notifications ?? this.notifications,
      expenses: expenses ?? this.expenses,
      shopName: shopName ?? this.shopName,
      shopAddress: shopAddress ?? this.shopAddress,
      weeklySalaryAmount: weeklySalaryAmount ?? this.weeklySalaryAmount,
      lastBackupAt: lastBackupAt ?? this.lastBackupAt,
    );
  }
}

class PreviewCustomer {
  const PreviewCustomer({
    required this.id,
    required this.name,
    required this.phone,
    required this.normalizedPhone,
    required this.address,
    required this.note,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String phone;
  final String normalizedPhone;
  final String address;
  final String note;
  final DateTime createdAt;

  PreviewCustomer copyWith({
    String? name,
    String? phone,
    String? normalizedPhone,
    String? address,
    String? note,
  }) {
    return PreviewCustomer(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      normalizedPhone: normalizedPhone ?? this.normalizedPhone,
      address: address ?? this.address,
      note: note ?? this.note,
      createdAt: createdAt,
    );
  }
}

class PreviewService {
  const PreviewService({
    required this.id,
    required this.name,
    required this.category,
    required this.unit,
    required this.price,
    required this.estimatedHours,
    required this.isExpress,
    required this.isActive,
  });

  final String id;
  final String name;
  final String category;
  final String unit;
  final int price;
  final int estimatedHours;
  final bool isExpress;
  final bool isActive;
}

class PreviewOrder {
  const PreviewOrder({
    required this.id,
    required this.orderNumber,
    required this.customerId,
    required this.customerNameSnapshot,
    required this.customerPhoneSnapshot,
    required this.items,
    required this.totalPrice,
    required this.paidAmount,
    required this.orderStatus,
    required this.paymentStatus,
    required this.receivedAt,
    required this.dueAt,
    required this.assignedEmployeeId,
    required this.note,
  });

  final String id;
  final String orderNumber;
  final String customerId;
  final String customerNameSnapshot;
  final String customerPhoneSnapshot;
  final List<PreviewOrderItem> items;
  final int totalPrice;
  final int paidAmount;
  final PreviewOrderStatus orderStatus;
  final PreviewPaymentStatus paymentStatus;
  final DateTime receivedAt;
  final DateTime dueAt;
  final String assignedEmployeeId;
  final String note;

  int get remainingAmount => totalPrice - paidAmount;

  double get totalQuantity =>
      items.fold(0, (previous, item) => previous + item.quantity);

  PreviewOrder copyWith({
    int? paidAmount,
    PreviewOrderStatus? orderStatus,
    PreviewPaymentStatus? paymentStatus,
    String? assignedEmployeeId,
    String? note,
  }) {
    return PreviewOrder(
      id: id,
      orderNumber: orderNumber,
      customerId: customerId,
      customerNameSnapshot: customerNameSnapshot,
      customerPhoneSnapshot: customerPhoneSnapshot,
      items: items,
      totalPrice: totalPrice,
      paidAmount: paidAmount ?? this.paidAmount,
      orderStatus: orderStatus ?? this.orderStatus,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      receivedAt: receivedAt,
      dueAt: dueAt,
      assignedEmployeeId: assignedEmployeeId ?? this.assignedEmployeeId,
      note: note ?? this.note,
    );
  }
}

class PreviewOrderItem {
  const PreviewOrderItem({
    required this.id,
    required this.serviceId,
    required this.serviceNameSnapshot,
    required this.unit,
    required this.quantity,
    required this.price,
    required this.total,
  });

  final String id;
  final String serviceId;
  final String serviceNameSnapshot;
  final String unit;
  final double quantity;
  final int price;
  final int total;
}

class PreviewPayment {
  const PreviewPayment({
    required this.id,
    required this.orderId,
    required this.amount,
    required this.method,
    required this.paidAt,
    required this.receiverName,
  });

  final String id;
  final String orderId;
  final int amount;
  final String method;
  final DateTime paidAt;
  final String receiverName;
}

class PreviewCashTransaction {
  const PreviewCashTransaction({
    required this.id,
    required this.referenceId,
    required this.referenceType,
    required this.type,
    required this.category,
    required this.description,
    required this.amount,
    required this.method,
    required this.createdAt,
  });

  final String id;
  final String referenceId;
  final String referenceType;
  final String type;
  final String category;
  final String description;
  final int amount;
  final String method;
  final DateTime createdAt;
}

class PreviewInventoryItem {
  const PreviewInventoryItem({
    required this.id,
    required this.name,
    required this.stock,
    required this.unit,
    required this.minStock,
    required this.purchasePrice,
    required this.note,
    required this.isActive,
  });

  final String id;
  final String name;
  final double stock;
  final String unit;
  final double minStock;
  final int purchasePrice;
  final String note;
  final bool isActive;

  bool get isLowStock => stock <= minStock;

  PreviewInventoryItem copyWith({double? stock, bool? isActive, String? note}) {
    return PreviewInventoryItem(
      id: id,
      name: name,
      stock: stock ?? this.stock,
      unit: unit,
      minStock: minStock,
      purchasePrice: purchasePrice,
      note: note ?? this.note,
      isActive: isActive ?? this.isActive,
    );
  }
}

class PreviewInventoryMovement {
  const PreviewInventoryMovement({
    required this.id,
    required this.itemId,
    required this.itemName,
    required this.type,
    required this.quantity,
    required this.note,
    required this.createdAt,
  });

  final String id;
  final String itemId;
  final String itemName;
  final String type;
  final double quantity;
  final String note;
  final DateTime createdAt;
}

class PreviewEmployee {
  const PreviewEmployee({
    required this.id,
    required this.name,
    required this.phone,
    required this.position,
    required this.isActive,
  });

  final String id;
  final String name;
  final String phone;
  final String position;
  final bool isActive;

  PreviewEmployee copyWith({
    String? name,
    String? phone,
    String? position,
    bool? isActive,
  }) {
    return PreviewEmployee(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      position: position ?? this.position,
      isActive: isActive ?? this.isActive,
    );
  }
}

class PreviewAttendance {
  const PreviewAttendance({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.date,
    required this.checkInAt,
    required this.status,
    this.checkOutAt,
    this.note = '',
  });

  final String id;
  final String employeeId;
  final String employeeName;
  final DateTime date;
  final DateTime checkInAt;
  final DateTime? checkOutAt;
  final String status;
  final String note;

  PreviewAttendance copyWith({
    DateTime? checkOutAt,
    String? status,
    String? employeeName,
    String? note,
  }) {
    return PreviewAttendance(
      id: id,
      employeeId: employeeId,
      employeeName: employeeName ?? this.employeeName,
      date: date,
      checkInAt: checkInAt,
      checkOutAt: checkOutAt ?? this.checkOutAt,
      status: status ?? this.status,
      note: note ?? this.note,
    );
  }
}

class PreviewShift {
  const PreviewShift({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.day,
    required this.startTime,
    required this.endTime,
    required this.isDayOff,
  });

  final String id;
  final String employeeId;
  final String employeeName;
  final String day;
  final String startTime;
  final String endTime;
  final bool isDayOff;

  PreviewShift copyWith({String? employeeName, bool? isDayOff}) {
    return PreviewShift(
      id: id,
      employeeId: employeeId,
      employeeName: employeeName ?? this.employeeName,
      day: day,
      startTime: startTime,
      endTime: endTime,
      isDayOff: isDayOff ?? this.isDayOff,
    );
  }
}

class PreviewEmployeeRequest {
  const PreviewEmployeeRequest({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.type,
    required this.reason,
    required this.amount,
    required this.status,
    required this.createdAt,
    this.reviewNote = '',
  });

  final String id;
  final String employeeId;
  final String employeeName;
  final String type;
  final String reason;
  final int amount;
  final PreviewRequestStatus status;
  final DateTime createdAt;
  final String reviewNote;

  PreviewEmployeeRequest copyWith({
    PreviewRequestStatus? status,
    String? reviewNote,
    String? employeeName,
  }) {
    return PreviewEmployeeRequest(
      id: id,
      employeeId: employeeId,
      employeeName: employeeName ?? this.employeeName,
      type: type,
      reason: reason,
      amount: amount,
      status: status ?? this.status,
      createdAt: createdAt,
      reviewNote: reviewNote ?? this.reviewNote,
    );
  }
}

class PreviewNotification {
  const PreviewNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.createdAt,
    required this.isRead,
    required this.actionRoute,
  });

  final String id;
  final String title;
  final String message;
  final String type;
  final DateTime createdAt;
  final bool isRead;
  final String actionRoute;

  PreviewNotification copyWith({bool? isRead}) {
    return PreviewNotification(
      id: id,
      title: title,
      message: message,
      type: type,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
      actionRoute: actionRoute,
    );
  }
}

class PreviewExpense {
  const PreviewExpense({
    required this.id,
    required this.description,
    required this.category,
    required this.amount,
    required this.method,
    required this.createdAt,
  });

  final String id;
  final String description;
  final String category;
  final int amount;
  final String method;
  final DateTime createdAt;
}

class PreviewDataController extends Notifier<PreviewDataState> {
  static const _days = [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
    'Minggu',
  ];
  static const _lateTolerance = Duration(hours: 2);
  static const _defaultServices = [
    PreviewService(
      id: 'service-cs-reguler',
      name: 'Cuci Setrika Reguler',
      category: 'Cuci Setrika',
      unit: 'kg',
      price: 7000,
      estimatedHours: 72,
      isExpress: false,
      isActive: true,
    ),
    PreviewService(
      id: 'service-cs-express',
      name: 'Cuci Setrika Express',
      category: 'Cuci Setrika',
      unit: 'kg',
      price: 9000,
      estimatedHours: 24,
      isExpress: true,
      isActive: true,
    ),
    PreviewService(
      id: 'service-cs-kilat',
      name: 'Cuci Setrika Kilat',
      category: 'Cuci Setrika',
      unit: 'kg',
      price: 12000,
      estimatedHours: 8,
      isExpress: true,
      isActive: true,
    ),
    PreviewService(
      id: 'service-ckl-reguler',
      name: 'Cuci Kering Lipat Reguler',
      category: 'Cuci Kering Lipat',
      unit: 'kg',
      price: 4000,
      estimatedHours: 72,
      isExpress: false,
      isActive: true,
    ),
    PreviewService(
      id: 'service-ckl-express',
      name: 'Cuci Kering Lipat Express',
      category: 'Cuci Kering Lipat',
      unit: 'kg',
      price: 6000,
      estimatedHours: 24,
      isExpress: true,
      isActive: true,
    ),
    PreviewService(
      id: 'service-ckl-kilat',
      name: 'Cuci Kering Lipat Kilat',
      category: 'Cuci Kering Lipat',
      unit: 'kg',
      price: 9000,
      estimatedHours: 8,
      isExpress: true,
      isActive: true,
    ),
    PreviewService(
      id: 'service-sl-reguler',
      name: 'Setrika Lipat Reguler',
      category: 'Setrika Lipat',
      unit: 'kg',
      price: 5000,
      estimatedHours: 72,
      isExpress: false,
      isActive: true,
    ),
    PreviewService(
      id: 'service-sl-express',
      name: 'Setrika Lipat Express',
      category: 'Setrika Lipat',
      unit: 'kg',
      price: 7000,
      estimatedHours: 24,
      isExpress: true,
      isActive: true,
    ),
    PreviewService(
      id: 'service-sl-kilat',
      name: 'Setrika Lipat Kilat',
      category: 'Setrika Lipat',
      unit: 'kg',
      price: 10000,
      estimatedHours: 8,
      isExpress: true,
      isActive: true,
    ),
    PreviewService(
      id: 'service-add-noda-bandel',
      name: 'Noda Bandel',
      category: 'Layanan Tambahan',
      unit: 'layanan',
      price: 5000,
      estimatedHours: 24,
      isExpress: false,
      isActive: true,
    ),
    PreviewService(
      id: 'service-add-speed-satuan',
      name: 'Speed Satuan',
      category: 'Layanan Tambahan',
      unit: 'layanan',
      price: 5000,
      estimatedHours: 24,
      isExpress: true,
      isActive: true,
    ),
    PreviewService(
      id: 'service-add-antar-jemput',
      name: 'Antar Jemput',
      category: 'Layanan Tambahan',
      unit: 'layanan',
      price: 2000,
      estimatedHours: 24,
      isExpress: false,
      isActive: true,
    ),
    PreviewService(
      id: 'service-satuan-kaos',
      name: 'Kaos / Polo Shirt / Singlet',
      category: 'Laundry Satuan',
      unit: 'pcs',
      price: 5000,
      estimatedHours: 72,
      isExpress: false,
      isActive: true,
    ),
    PreviewService(
      id: 'service-satuan-kemeja',
      name: 'Kemeja Pendek / Panjang',
      category: 'Laundry Satuan',
      unit: 'pcs',
      price: 6000,
      estimatedHours: 72,
      isExpress: false,
      isActive: true,
    ),
    PreviewService(
      id: 'service-satuan-celana-panjang',
      name: 'Celana Panjang Kain / Chino / Kulot',
      category: 'Laundry Satuan',
      unit: 'pcs',
      price: 7000,
      estimatedHours: 72,
      isExpress: false,
      isActive: true,
    ),
    PreviewService(
      id: 'service-satuan-jaket',
      name: 'Jaket / Hoodie / Sweater',
      category: 'Laundry Satuan',
      unit: 'pcs',
      price: 10000,
      estimatedHours: 72,
      isExpress: false,
      isActive: true,
    ),
    PreviewService(
      id: 'service-satuan-dress',
      name: 'Dress / Rok Terusan Simple',
      category: 'Laundry Satuan',
      unit: 'pcs',
      price: 10000,
      estimatedHours: 72,
      isExpress: false,
      isActive: true,
    ),
    PreviewService(
      id: 'service-satuan-sprei-single',
      name: 'Sprei Single',
      category: 'Laundry Satuan',
      unit: 'pcs',
      price: 10000,
      estimatedHours: 72,
      isExpress: false,
      isActive: true,
    ),
    PreviewService(
      id: 'service-satuan-bedcover-single',
      name: 'Bedcover Single',
      category: 'Laundry Satuan',
      unit: 'pcs',
      price: 20000,
      estimatedHours: 72,
      isExpress: false,
      isActive: true,
    ),
    PreviewService(
      id: 'service-satuan-bedcover-double',
      name: 'Bedcover Double / King Size',
      category: 'Laundry Satuan',
      unit: 'pcs',
      price: 30000,
      estimatedHours: 72,
      isExpress: false,
      isActive: true,
    ),
    PreviewService(
      id: 'service-satuan-bantal-guling',
      name: 'Sarung Bantal / Guling',
      category: 'Laundry Satuan',
      unit: 'pcs',
      price: 2000,
      estimatedHours: 72,
      isExpress: false,
      isActive: true,
    ),
    PreviewService(
      id: 'service-satuan-boneka-sedang',
      name: 'Boneka Ukuran Sedang',
      category: 'Laundry Satuan',
      unit: 'pcs',
      price: 15000,
      estimatedHours: 72,
      isExpress: false,
      isActive: true,
    ),
  ];

  @override
  PreviewDataState build() {
    final now = DateTime.now();
    final employee1 = PreviewEmployee(
      id: 'employee-1',
      name: 'Karyawan 1',
      phone: '081234567891',
      position: 'Operator',
      isActive: true,
    );
    final employee2 = PreviewEmployee(
      id: 'employee-2',
      name: 'Karyawan 2',
      phone: '081234567892',
      position: 'Kasir',
      isActive: true,
    );
    final customer = PreviewCustomer(
      id: 'customer-1',
      name: 'Budi Santoso',
      phone: '081234567800',
      normalizedPhone: '6281234567800',
      address: 'Jl. Melati No. 12',
      note: 'Pelanggan reguler',
      createdAt: now,
    );
    final importedCustomers = importedCustomerContacts.map((contact) {
      return PreviewCustomer(
        id: contact['id']!,
        name: contact['name']!,
        phone: contact['phone']!,
        normalizedPhone: contact['normalizedPhone']!,
        address: contact['address']!,
        note: contact['note']!,
        createdAt: now,
      );
    }).toList();
    final service = _defaultServices.first;
    final order = _buildOrder(
      orderIndex: 1,
      customer: customer,
      service: service,
      quantity: 5,
      paidAmount: 20000,
      employeeId: employee1.id,
      note: 'Pisahkan pakaian putih.',
      createdAt: now.subtract(const Duration(hours: 2)),
    );
    final payment = PreviewPayment(
      id: 'payment-1',
      orderId: order.id,
      amount: 20000,
      method: 'Tunai',
      paidAt: order.receivedAt,
      receiverName: 'Owner Idola',
    );
    return PreviewDataState(
      customers: [customer, ...importedCustomers],
      services: _defaultServices,
      orders: [order],
      payments: [payment],
      cashTransactions: [
        PreviewCashTransaction(
          id: 'cash-1',
          referenceId: payment.id,
          referenceType: 'PAYMENT',
          type: 'IN',
          category: 'Pembayaran Pesanan',
          description: 'DP ${order.orderNumber}',
          amount: payment.amount,
          method: payment.method,
          createdAt: payment.paidAt,
        ),
      ],
      inventory: const [
        PreviewInventoryItem(
          id: 'inventory-1',
          name: 'Deterjen Cair',
          stock: 3,
          unit: 'liter',
          minStock: 5,
          purchasePrice: 25000,
          note: 'Perlu restock',
          isActive: true,
        ),
        PreviewInventoryItem(
          id: 'inventory-2',
          name: 'Pewangi',
          stock: 8,
          unit: 'liter',
          minStock: 4,
          purchasePrice: 30000,
          note: '',
          isActive: true,
        ),
      ],
      inventoryMovements: const [],
      employees: [employee1, employee2],
      attendance: const [],
      shifts: [
        for (final (index, day) in _days.indexed) ...[
          PreviewShift(
            id: 'shift-employee-1-${index + 1}',
            employeeId: employee1.id,
            employeeName: employee1.name,
            day: day,
            startTime: '06.00',
            endTime: '14.00',
            isDayOff: false,
          ),
          PreviewShift(
            id: 'shift-employee-2-${index + 1}',
            employeeId: employee2.id,
            employeeName: employee2.name,
            day: day,
            startTime: '12.00',
            endTime: '20.00',
            isDayOff: false,
          ),
        ],
      ],
      requests: const [],
      notifications: [
        PreviewNotification(
          id: 'notification-1',
          title: 'Stok menipis',
          message: 'Deterjen Cair sudah di bawah stok minimum.',
          type: 'WARNING',
          createdAt: now.subtract(const Duration(minutes: 20)),
          isRead: false,
          actionRoute: '/inventory',
        ),
      ],
      expenses: const [],
      shopName: 'Idola Laundry',
      shopAddress: 'Jl. Contoh Operasional No. 1',
      weeklySalaryAmount: 400000,
    );
  }

  void addCustomer({
    required String name,
    required String phone,
    required String address,
    required String note,
  }) {
    final normalizedPhone = normalizeIndonesianPhone(phone);
    final exists = state.customers.any(
      (customer) => customer.normalizedPhone == normalizedPhone,
    );
    if (exists) {
      throw StateError('Nomor telepon sudah terdaftar.');
    }
    final customer = PreviewCustomer(
      id: _uuid.v4(),
      name: name.trim(),
      phone: phone.trim(),
      normalizedPhone: normalizedPhone,
      address: address.trim(),
      note: note.trim(),
      createdAt: DateTime.now(),
    );
    state = state.copyWith(customers: [...state.customers, customer]);
  }

  void updateCustomer({
    required String id,
    required String name,
    required String phone,
    required String address,
    required String note,
  }) {
    final normalizedPhone = normalizeIndonesianPhone(phone);
    final duplicate = state.customers.any(
      (customer) =>
          customer.id != id && customer.normalizedPhone == normalizedPhone,
    );
    if (duplicate) {
      throw StateError('Nomor telepon sudah terdaftar.');
    }

    var found = false;
    final customers = state.customers.map((customer) {
      if (customer.id != id) {
        return customer;
      }
      found = true;
      return customer.copyWith(
        name: name.trim(),
        phone: phone.trim(),
        normalizedPhone: normalizedPhone,
        address: address.trim(),
        note: note.trim(),
      );
    }).toList();

    if (!found) {
      throw StateError('Pelanggan tidak ditemukan.');
    }
    state = state.copyWith(customers: customers);
  }

  void addService({
    required String name,
    required String category,
    required String unit,
    required int price,
    required int estimatedHours,
    required bool isExpress,
  }) {
    final service = PreviewService(
      id: _uuid.v4(),
      name: name.trim(),
      category: category,
      unit: unit,
      price: price,
      estimatedHours: estimatedHours,
      isExpress: isExpress,
      isActive: true,
    );
    state = state.copyWith(services: [...state.services, service]);
  }

  PreviewOrder createOrder({
    required String customerId,
    required String serviceId,
    required double quantity,
    required int paidAmount,
    required String paymentMethod,
    required String employeeId,
    required String note,
  }) {
    final customer = state.customers.firstWhere(
      (item) => item.id == customerId,
    );
    final service = state.services.firstWhere((item) => item.id == serviceId);
    final total = (service.price * quantity).round();
    if (paidAmount < 0 || paidAmount > total) {
      throw StateError('Nominal pembayaran tidak valid.');
    }
    final order = _buildOrder(
      orderIndex: state.orders.length + 1,
      customer: customer,
      service: service,
      quantity: quantity,
      paidAmount: paidAmount,
      employeeId: employeeId,
      note: note,
      createdAt: DateTime.now(),
    );
    final payments = [...state.payments];
    final cash = [...state.cashTransactions];
    if (paidAmount > 0) {
      final payment = PreviewPayment(
        id: _uuid.v4(),
        orderId: order.id,
        amount: paidAmount,
        method: paymentMethod,
        paidAt: DateTime.now(),
        receiverName: 'Owner Idola',
      );
      payments.add(payment);
      cash.add(
        PreviewCashTransaction(
          id: _uuid.v4(),
          referenceId: payment.id,
          referenceType: 'PAYMENT',
          type: 'IN',
          category: order.paymentStatus == PreviewPaymentStatus.paid
              ? 'Pelunasan'
              : 'DP',
          description: 'Pembayaran ${order.orderNumber}',
          amount: paidAmount,
          method: paymentMethod,
          createdAt: payment.paidAt,
        ),
      );
    }
    state = state.copyWith(
      orders: [order, ...state.orders],
      payments: payments,
      cashTransactions: cash,
      notifications: [
        _notification(
          'Pesanan baru',
          '${order.orderNumber} untuk ${order.customerNameSnapshot} berhasil dibuat.',
          '/orders/${order.id}',
        ),
        ...state.notifications,
      ],
    );
    return order;
  }

  PreviewOrder createOrderWithItems({
    required String customerId,
    required List<({String serviceId, double quantity})> items,
    required int paidAmount,
    required String paymentMethod,
    required String employeeId,
    required String note,
  }) {
    if (items.isEmpty) {
      throw StateError('Tambahkan minimal satu item pesanan.');
    }
    final customer = state.customers.firstWhere(
      (item) => item.id == customerId,
    );
    final servicesById = {for (final service in state.services) service.id: service};
    final orderItems = <PreviewOrderItem>[];
    var total = 0;
    var longestHours = 0;
    for (final item in items) {
      final service = servicesById[item.serviceId];
      if (service == null) {
        throw StateError('Layanan tidak ditemukan.');
      }
      if (service.unit.toLowerCase() == 'kg' && item.quantity < 3) {
        throw StateError('Minimum laundry kiloan 3 kg.');
      }
      final itemTotal = (service.price * item.quantity).round();
      total += itemTotal;
      if (service.estimatedHours > longestHours) {
        longestHours = service.estimatedHours;
      }
      orderItems.add(
        PreviewOrderItem(
          id: _uuid.v4(),
          serviceId: service.id,
          serviceNameSnapshot: service.name,
          unit: service.unit,
          quantity: item.quantity,
          price: service.price,
          total: itemTotal,
        ),
      );
    }
    if (paidAmount < 0 || paidAmount > total) {
      throw StateError('Nominal pembayaran tidak valid.');
    }
    final createdAt = DateTime.now();
    final orderIndex = state.orders.length + 1;
    final orderNumber =
        'IDL-${createdAt.year}${createdAt.month.toString().padLeft(2, '0')}${createdAt.day.toString().padLeft(2, '0')}-${orderIndex.toString().padLeft(4, '0')}';
    final order = PreviewOrder(
      id: _uuid.v4(),
      orderNumber: orderNumber,
      customerId: customer.id,
      customerNameSnapshot: customer.name,
      customerPhoneSnapshot: customer.phone,
      items: orderItems,
      totalPrice: total,
      paidAmount: paidAmount,
      paymentStatus: paidAmount == 0
          ? PreviewPaymentStatus.unpaid
          : paidAmount >= total
          ? PreviewPaymentStatus.paid
          : PreviewPaymentStatus.partiallyPaid,
      orderStatus: PreviewOrderStatus.received,
      receivedAt: createdAt,
      dueAt: createdAt.add(Duration(hours: longestHours)),
      assignedEmployeeId: employeeId,
      note: note,
    );
    final payments = [...state.payments];
    final cash = [...state.cashTransactions];
    if (paidAmount > 0) {
      final payment = PreviewPayment(
        id: _uuid.v4(),
        orderId: order.id,
        amount: paidAmount,
        method: paymentMethod,
        paidAt: DateTime.now(),
        receiverName: 'Owner Idola',
      );
      payments.add(payment);
      cash.add(
        PreviewCashTransaction(
          id: _uuid.v4(),
          referenceId: payment.id,
          referenceType: 'PAYMENT',
          type: 'IN',
          category: order.paymentStatus == PreviewPaymentStatus.paid
              ? 'Pelunasan'
              : 'DP',
          description: 'Pembayaran ${order.orderNumber}',
          amount: paidAmount,
          method: paymentMethod,
          createdAt: payment.paidAt,
        ),
      );
    }
    state = state.copyWith(
      orders: [order, ...state.orders],
      payments: payments,
      cashTransactions: cash,
      notifications: [
        _notification(
          'Pesanan baru',
          '${order.orderNumber} untuk ${order.customerNameSnapshot} berhasil dibuat.',
          '/orders/${order.id}',
        ),
        ...state.notifications,
      ],
    );
    return order;
  }

  void addPayment({
    required String orderId,
    required int amount,
    required String method,
  }) {
    final order = state.orders.firstWhere((item) => item.id == orderId);
    if (amount <= 0 || amount > order.remainingAmount) {
      throw StateError(
        'Nominal pembayaran harus di antara Rp1 dan sisa tagihan.',
      );
    }
    final payment = PreviewPayment(
      id: _uuid.v4(),
      orderId: orderId,
      amount: amount,
      method: method,
      paidAt: DateTime.now(),
      receiverName: 'Owner Idola',
    );
    final newPaid = order.paidAmount + amount;
    final updated = order.copyWith(
      paidAmount: newPaid,
      paymentStatus: newPaid >= order.totalPrice
          ? PreviewPaymentStatus.paid
          : PreviewPaymentStatus.partiallyPaid,
    );
    state = state.copyWith(
      orders: [
        for (final item in state.orders)
          if (item.id == orderId) updated else item,
      ],
      payments: [...state.payments, payment],
      cashTransactions: [
        PreviewCashTransaction(
          id: _uuid.v4(),
          referenceId: payment.id,
          referenceType: 'PAYMENT',
          type: 'IN',
          category: updated.paymentStatus == PreviewPaymentStatus.paid
              ? 'Pelunasan'
              : 'DP',
          description: 'Pembayaran ${order.orderNumber}',
          amount: amount,
          method: method,
          createdAt: payment.paidAt,
        ),
        ...state.cashTransactions,
      ],
    );
  }

  void updateOrderStatus(String orderId, PreviewOrderStatus status) {
    state = state.copyWith(
      orders: [
        for (final order in state.orders)
          if (order.id == orderId)
            order.copyWith(orderStatus: status)
          else
            order,
      ],
    );
  }

  void addInventoryItem({
    required String name,
    required double stock,
    required String unit,
    required double minStock,
    required int purchasePrice,
    required String note,
  }) {
    final item = PreviewInventoryItem(
      id: _uuid.v4(),
      name: name.trim(),
      stock: stock,
      unit: unit.trim(),
      minStock: minStock,
      purchasePrice: purchasePrice,
      note: note.trim(),
      isActive: true,
    );
    state = state.copyWith(inventory: [...state.inventory, item]);
  }

  void adjustStock({
    required String itemId,
    required double quantity,
    required String type,
    required String note,
  }) {
    final item = state.inventory.firstWhere((entry) => entry.id == itemId);
    final delta = type == 'OUT' || type == 'USAGE' ? -quantity : quantity;
    final nextStock = item.stock + delta;
    if (nextStock < 0) {
      throw StateError('Stok tidak boleh kurang dari nol.');
    }
    final movement = PreviewInventoryMovement(
      id: _uuid.v4(),
      itemId: item.id,
      itemName: item.name,
      type: type,
      quantity: quantity,
      note: note,
      createdAt: DateTime.now(),
    );
    state = state.copyWith(
      inventory: [
        for (final entry in state.inventory)
          if (entry.id == itemId) entry.copyWith(stock: nextStock) else entry,
      ],
      inventoryMovements: [movement, ...state.inventoryMovements],
    );
  }

  void addAttendance({
    required String employeeId,
    required String employeeName,
    required bool isCheckOut,
    required String photoPath,
  }) {
    final today = DateTime.now();
    final shift = _shiftFor(employeeId, today);
    final existing = state.attendance.where((entry) {
      return entry.employeeId == employeeId &&
          entry.date.year == today.year &&
          entry.date.month == today.month &&
          entry.date.day == today.day;
    }).toList();

    if (!isCheckOut) {
      final shiftStart = _timeOnDate(today, shift.startTime);
      final lastCheckIn = shiftStart.add(_lateTolerance);
      if (today.isBefore(shiftStart)) {
        throw StateError(
          'Absen masuk belum dibuka. Jadwal mulai ${_formatTime(shiftStart)}.',
        );
      }
      if (today.isAfter(lastCheckIn)) {
        throw StateError(
          'Maksimal terlambat 2 jam. Absen masuk ditutup ${_formatTime(lastCheckIn)}.',
        );
      }
      if (existing.isNotEmpty) {
        throw StateError('Karyawan sudah absen masuk hari ini.');
      }
      final attendance = PreviewAttendance(
        id: _uuid.v4(),
        employeeId: employeeId,
        employeeName: employeeName,
        date: today,
        checkInAt: today,
        status: 'HADIR',
        note:
            'Foto masuk: $photoPath. Shift ${shift.startTime}-${shift.endTime}.',
      );
      state = state.copyWith(attendance: [attendance, ...state.attendance]);
      return;
    }

    if (existing.isEmpty) {
      throw StateError('Absen masuk terlebih dahulu sebelum absen keluar.');
    }
    final current = existing.first;
    if (current.checkOutAt != null) {
      throw StateError('Karyawan sudah absen keluar hari ini.');
    }
    final shiftEnd = _timeOnDate(today, shift.endTime);
    if (today.isBefore(shiftEnd)) {
      throw StateError(
        'Belum waktunya absen keluar. Jadwal selesai ${_formatTime(shiftEnd)}.',
      );
    }
    state = state.copyWith(
      attendance: [
        for (final entry in state.attendance)
          if (entry.id == current.id)
            entry.copyWith(
              checkOutAt: today,
              note: '${entry.note} Foto keluar: $photoPath.',
            )
          else
            entry,
      ],
    );
  }

  PreviewShift _shiftFor(String employeeId, DateTime date) {
    final day = _indonesianDay(date);
    return state.shifts.firstWhere(
      (shift) => shift.employeeId == employeeId && shift.day == day,
      orElse: () => throw StateError('Jadwal hari ini belum dibuat.'),
    );
  }

  DateTime _timeOnDate(DateTime date, String value) {
    final parts = value.replaceAll(':', '.').split('.');
    final hour = int.tryParse(parts.first) ?? 0;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  String _formatTime(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour.$minute';
  }

  String _indonesianDay(DateTime date) {
    return switch (date.weekday) {
      DateTime.monday => 'Senin',
      DateTime.tuesday => 'Selasa',
      DateTime.wednesday => 'Rabu',
      DateTime.thursday => 'Kamis',
      DateTime.friday => 'Jumat',
      DateTime.saturday => 'Sabtu',
      DateTime.sunday => 'Minggu',
      _ => 'Senin',
    };
  }

  void addShift({
    required String employeeId,
    required String day,
    required String startTime,
    required String endTime,
  }) {
    final employee = state.employees.firstWhere(
      (item) => item.id == employeeId,
    );
    final exists = state.shifts.any(
      (shift) => shift.employeeId == employeeId && shift.day == day,
    );
    if (exists) {
      throw StateError('Karyawan sudah punya jadwal di hari $day.');
    }
    final shift = PreviewShift(
      id: _uuid.v4(),
      employeeId: employee.id,
      employeeName: employee.name,
      day: day,
      startTime: startTime,
      endTime: endTime,
      isDayOff: false,
    );
    state = state.copyWith(shifts: [...state.shifts, shift]);
  }

  void addEmployee({
    required String name,
    required String phone,
    required String position,
    bool isActive = true,
  }) {
    final employee = PreviewEmployee(
      id: _uuid.v4(),
      name: name.trim(),
      phone: phone.trim(),
      position: position.trim(),
      isActive: isActive,
    );
    state = state.copyWith(employees: [...state.employees, employee]);
  }

  void updateEmployee({
    required String id,
    required String name,
    required String phone,
    required String position,
    required bool isActive,
  }) {
    var found = false;
    final trimmedName = name.trim();
    final employees = state.employees.map((employee) {
      if (employee.id != id) {
        return employee;
      }
      found = true;
      return employee.copyWith(
        name: trimmedName,
        phone: phone.trim(),
        position: position.trim(),
        isActive: isActive,
      );
    }).toList();

    if (!found) {
      throw StateError('Karyawan tidak ditemukan.');
    }

    state = state.copyWith(
      employees: employees,
      attendance: [
        for (final entry in state.attendance)
          if (entry.employeeId == id)
            entry.copyWith(employeeName: trimmedName)
          else
            entry,
      ],
      shifts: [
        for (final shift in state.shifts)
          if (shift.employeeId == id)
            shift.copyWith(employeeName: trimmedName)
          else
            shift,
      ],
      requests: [
        for (final request in state.requests)
          if (request.employeeId == id)
            request.copyWith(employeeName: trimmedName)
          else
            request,
      ],
    );
  }

  void addRequest({
    required String type,
    required String reason,
    required int amount,
    String employeeId = 'employee-1',
  }) {
    final employee = state.employees.firstWhere(
      (item) => item.id == employeeId,
    );
    final request = PreviewEmployeeRequest(
      id: _uuid.v4(),
      employeeId: employee.id,
      employeeName: employee.name,
      type: type,
      reason: reason,
      amount: amount,
      status: PreviewRequestStatus.pending,
      createdAt: DateTime.now(),
    );
    state = state.copyWith(
      requests: [request, ...state.requests],
      notifications: [
        _notification(
          'Request baru',
          '${employee.name} mengajukan $type.',
          '/notifications',
        ),
        ...state.notifications,
      ],
    );
  }

  void reviewRequest(
    String id,
    PreviewRequestStatus status, {
    String reviewNote = '',
  }) {
    if (status != PreviewRequestStatus.approved &&
        status != PreviewRequestStatus.rejected) {
      throw StateError('Review hanya bisa menyetujui atau menolak request.');
    }
    final current = state.requests.firstWhere((request) => request.id == id);
    if (current.status != PreviewRequestStatus.pending) {
      throw StateError('Request ini sudah pernah ditinjau.');
    }
    final updated = current.copyWith(
      status: status,
      reviewNote: reviewNote.trim(),
    );
    state = state.copyWith(
      requests: [
        for (final request in state.requests)
          if (request.id == id) updated else request,
      ],
      notifications: [
        _notification(
          'Request ${status.label}',
          '${current.type} dari ${current.employeeName} ${status.label.toLowerCase()}.',
          '/notifications',
        ),
        ...state.notifications,
      ],
    );
  }

  void payEmployeeRequest({required String requestId, required String method}) {
    final current = state.requests.firstWhere(
      (request) => request.id == requestId,
    );
    if (current.status != PreviewRequestStatus.approved) {
      throw StateError('Setujui request sebelum mencatat pembayaran.');
    }
    if (current.amount <= 0) {
      throw StateError('Request ini tidak memiliki nominal untuk dibayar.');
    }
    final alreadyRecorded = state.cashTransactions.any(
      (cash) =>
          cash.referenceType == 'EMPLOYEE_REQUEST' &&
          cash.referenceId == requestId,
    );
    if (alreadyRecorded) {
      throw StateError('Pembayaran request ini sudah tercatat di Buku Kas.');
    }

    final now = DateTime.now();
    final transaction = PreviewCashTransaction(
      id: _uuid.v4(),
      referenceId: requestId,
      referenceType: 'EMPLOYEE_REQUEST',
      type: 'OUT',
      category: _requestCashCategory(current.type),
      description: '${current.type} - ${current.employeeName}',
      amount: current.amount,
      method: method,
      createdAt: now,
    );
    state = state.copyWith(
      requests: [
        for (final request in state.requests)
          if (request.id == requestId)
            request.copyWith(
              status: PreviewRequestStatus.paid,
              reviewNote: request.reviewNote.isEmpty
                  ? 'Dibayar via $method.'
                  : '${request.reviewNote} Dibayar via $method.',
            )
          else
            request,
      ],
      cashTransactions: [transaction, ...state.cashTransactions],
      notifications: [
        _notification(
          'Request dibayar',
          '${current.type} untuk ${current.employeeName} masuk Buku Kas.',
          '/cashbook',
        ),
        ...state.notifications,
      ],
    );
  }

  void completeRequest(String requestId) {
    final current = state.requests.firstWhere(
      (request) => request.id == requestId,
    );
    if (current.status == PreviewRequestStatus.pending) {
      throw StateError('Setujui request sebelum menandai selesai.');
    }
    if (current.status == PreviewRequestStatus.completed) {
      throw StateError('Request ini sudah selesai.');
    }
    state = state.copyWith(
      requests: [
        for (final request in state.requests)
          if (request.id == requestId)
            request.copyWith(
              status: PreviewRequestStatus.completed,
              reviewNote: request.reviewNote.isEmpty
                  ? 'Ditandai selesai.'
                  : '${request.reviewNote} Ditandai selesai.',
            )
          else
            request,
      ],
      notifications: [
        _notification(
          'Request selesai',
          '${current.type} untuk ${current.employeeName} selesai.',
          '/notifications',
        ),
        ...state.notifications,
      ],
    );
  }

  void payWeeklySalary({required String employeeId, required String method}) {
    final employee = state.employees.firstWhere(
      (item) => item.id == employeeId,
    );
    final periodStart = _startOfWeek(DateTime.now());
    final referenceId = 'PAYROLL-$employeeId-${_compactDate(periodStart)}';
    final alreadyRecorded = state.cashTransactions.any(
      (cash) =>
          cash.referenceType == 'PAYROLL' && cash.referenceId == referenceId,
    );
    if (alreadyRecorded) {
      throw StateError('Gaji minggu ini untuk ${employee.name} sudah dibayar.');
    }
    final now = DateTime.now();
    final transaction = PreviewCashTransaction(
      id: _uuid.v4(),
      referenceId: referenceId,
      referenceType: 'PAYROLL',
      type: 'OUT',
      category: 'Gaji',
      description: 'Gaji mingguan ${employee.name}',
      amount: state.weeklySalaryAmount,
      method: method,
      createdAt: now,
    );
    state = state.copyWith(
      cashTransactions: [transaction, ...state.cashTransactions],
      notifications: [
        _notification(
          'Gaji dibayar',
          'Gaji mingguan ${employee.name} sudah masuk Buku Kas.',
          '/cashbook',
        ),
        ...state.notifications,
      ],
    );
  }

  void addExpense({
    required String description,
    required String category,
    required int amount,
    required String method,
  }) {
    final expense = PreviewExpense(
      id: _uuid.v4(),
      description: description,
      category: category,
      amount: amount,
      method: method,
      createdAt: DateTime.now(),
    );
    state = state.copyWith(
      expenses: [expense, ...state.expenses],
      cashTransactions: [
        PreviewCashTransaction(
          id: _uuid.v4(),
          referenceId: expense.id,
          referenceType: 'EXPENSE',
          type: 'OUT',
          category: category,
          description: description,
          amount: amount,
          method: method,
          createdAt: expense.createdAt,
        ),
        ...state.cashTransactions,
      ],
    );
  }

  void markNotificationRead(String id) {
    state = state.copyWith(
      notifications: [
        for (final notification in state.notifications)
          if (notification.id == id)
            notification.copyWith(isRead: true)
          else
            notification,
      ],
    );
  }

  void markAllNotificationsRead() {
    state = state.copyWith(
      notifications: [
        for (final notification in state.notifications)
          notification.copyWith(isRead: true),
      ],
    );
  }

  void deleteNotification(String id) {
    state = state.copyWith(
      notifications: [
        for (final notification in state.notifications)
          if (notification.id != id) notification,
      ],
    );
  }

  void updateShopSettings({required String name, required String address}) {
    state = state.copyWith(shopName: name.trim(), shopAddress: address.trim());
  }

  void recordBackupExport(String format) {
    state = state.copyWith(
      lastBackupAt: DateTime.now(),
      notifications: [
        _notification(
          'Backup preview siap',
          'Export $format dibuat dari data lokal sesi ini.',
          '/backup',
        ),
        ...state.notifications,
      ],
    );
  }

  static String normalizeIndonesianPhone(String value) {
    var phone = value.replaceAll(RegExp(r'[^0-9+]'), '');
    if (phone.startsWith('+62')) {
      phone = phone.substring(1);
    } else if (phone.startsWith('0')) {
      phone = '62${phone.substring(1)}';
    }
    return phone;
  }

  PreviewNotification _notification(
    String title,
    String message,
    String route,
  ) {
    return PreviewNotification(
      id: _uuid.v4(),
      title: title,
      message: message,
      type: 'INFO',
      createdAt: DateTime.now(),
      isRead: false,
      actionRoute: route,
    );
  }

  static String _requestCashCategory(String type) {
    if (type.contains('Kasbon')) {
      return 'Kasbon';
    }
    if (type.contains('Insentif')) {
      return 'Insentif';
    }
    if (type.contains('Lembur')) {
      return 'Lembur';
    }
    return 'Request Karyawan';
  }

  static DateTime _startOfWeek(DateTime value) {
    final date = DateTime(value.year, value.month, value.day);
    return date.subtract(Duration(days: date.weekday - DateTime.monday));
  }

  static String _compactDate(DateTime value) {
    return '${value.year}${value.month.toString().padLeft(2, '0')}${value.day.toString().padLeft(2, '0')}';
  }

  static PreviewOrder _buildOrder({
    required int orderIndex,
    required PreviewCustomer customer,
    required PreviewService service,
    required double quantity,
    required int paidAmount,
    required String employeeId,
    required String note,
    required DateTime createdAt,
  }) {
    final total = (service.price * quantity).round();
    final orderNumber =
        'IDL-${createdAt.year}${createdAt.month.toString().padLeft(2, '0')}${createdAt.day.toString().padLeft(2, '0')}-${orderIndex.toString().padLeft(4, '0')}';
    return PreviewOrder(
      id: orderIndex == 1 ? 'order-1' : _uuid.v4(),
      orderNumber: orderNumber,
      customerId: customer.id,
      customerNameSnapshot: customer.name,
      customerPhoneSnapshot: customer.phone,
      items: [
        PreviewOrderItem(
          id: _uuid.v4(),
          serviceId: service.id,
          serviceNameSnapshot: service.name,
          unit: service.unit,
          quantity: quantity,
          price: service.price,
          total: total,
        ),
      ],
      totalPrice: total,
      paidAmount: paidAmount,
      paymentStatus: paidAmount == 0
          ? PreviewPaymentStatus.unpaid
          : paidAmount >= total
          ? PreviewPaymentStatus.paid
          : PreviewPaymentStatus.partiallyPaid,
      orderStatus: PreviewOrderStatus.received,
      receivedAt: createdAt,
      dueAt: createdAt.add(Duration(hours: service.estimatedHours)),
      assignedEmployeeId: employeeId,
      note: note,
    );
  }
}
