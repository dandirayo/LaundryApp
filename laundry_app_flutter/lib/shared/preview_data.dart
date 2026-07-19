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

enum PreviewAttendanceStatus {
  onTime('Tepat Waktu'),
  late('Terlambat'),
  severelyLate('Terlambat Berat'),
  absent('Tidak Hadir'),
  leave('Izin'),
  sick('Sakit'),
  permission('Izin Disetujui');

  const PreviewAttendanceStatus(this.label);

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
    required this.legacyMonthlySummaries,
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
  final List<PreviewLegacyMonthlySummary> legacyMonthlySummaries;
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
    List<PreviewLegacyMonthlySummary>? legacyMonthlySummaries,
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
      legacyMonthlySummaries:
          legacyMonthlySummaries ?? this.legacyMonthlySummaries,
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
    this.groupName = '',
    this.categoryName = '',
    this.itemName = '',
    this.variantName = '',
    this.sortOrder = 0,
  });

  final String id;
  final String name;
  final String category;
  final String unit;
  final int price;
  final int estimatedHours;
  final bool isExpress;
  final bool isActive;
  final String groupName;
  final String categoryName;
  final String itemName;
  final String variantName;
  final int sortOrder;

  String get effectiveGroup {
    if (groupName.isNotEmpty) {
      return groupName;
    }
    if (unit.toUpperCase() == 'KG') {
      return 'Kiloan';
    }
    if (category.toLowerCase().contains('sepatu')) {
      return 'Sepatu';
    }
    if (category.toLowerCase().contains('helm')) {
      return 'Helm';
    }
    return 'Satuan';
  }

  String get effectiveCategory =>
      categoryName.isNotEmpty ? categoryName : category;

  String get effectiveItem => itemName.isNotEmpty ? itemName : name;

  String get effectiveVariant => variantName;

  String get breadcrumb {
    final parts = [
      effectiveGroup,
      effectiveCategory,
      effectiveItem,
      if (effectiveVariant.isNotEmpty) effectiveVariant,
    ].where((part) => part.trim().isNotEmpty).toList();
    return parts.join(' > ');
  }
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

  double quantityForUnit(String unit) {
    final normalized = unit.toUpperCase();
    return items
        .where((item) => item.unit.toUpperCase() == normalized)
        .fold(0, (previous, item) => previous + item.quantity);
  }

  double get laundryWeightKg => quantityForUnit('KG');

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
    this.attendanceStatus = PreviewAttendanceStatus.onTime,
    this.scheduledStart,
    this.scheduledEnd,
    this.lateMinutes = 0,
    this.earlyLeaveMinutes = 0,
    this.shiftLabel = '',
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
  final PreviewAttendanceStatus attendanceStatus;
  final DateTime? scheduledStart;
  final DateTime? scheduledEnd;
  final int lateMinutes;
  final int earlyLeaveMinutes;
  final String shiftLabel;
  final String note;

  PreviewAttendance copyWith({
    DateTime? checkOutAt,
    String? status,
    PreviewAttendanceStatus? attendanceStatus,
    String? employeeName,
    int? earlyLeaveMinutes,
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
      attendanceStatus: attendanceStatus ?? this.attendanceStatus,
      scheduledStart: scheduledStart,
      scheduledEnd: scheduledEnd,
      lateMinutes: lateMinutes,
      earlyLeaveMinutes: earlyLeaveMinutes ?? this.earlyLeaveMinutes,
      shiftLabel: shiftLabel,
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

class PreviewLegacyMonthlySummary {
  const PreviewLegacyMonthlySummary({
    required this.month,
    required this.label,
    required this.income,
    required this.expense,
    required this.profit,
    required this.openingBalance,
    required this.closingBalance,
  });

  final DateTime month;
  final String label;
  final int income;
  final int expense;
  final int profit;
  final int openingBalance;
  final int closingBalance;
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
  static final _legacyMonthlySummaries = [
    PreviewLegacyMonthlySummary(
      month: DateTime(2025, 5),
      label: 'Mei 2025',
      income: 4200000,
      expense: 5330000,
      profit: -1130000,
      openingBalance: 0,
      closingBalance: -1130000,
    ),
    PreviewLegacyMonthlySummary(
      month: DateTime(2025, 6),
      label: 'Juni 2025',
      income: 5700000,
      expense: 8025000,
      profit: -2325000,
      openingBalance: -1130000,
      closingBalance: -3455000,
    ),
    PreviewLegacyMonthlySummary(
      month: DateTime(2025, 7),
      label: 'Juli 2025',
      income: 8552000,
      expense: 7540000,
      profit: 1012000,
      openingBalance: -3455000,
      closingBalance: -2443000,
    ),
    PreviewLegacyMonthlySummary(
      month: DateTime(2025, 8),
      label: 'Agustus 2025',
      income: 8342000,
      expense: 7373000,
      profit: 969000,
      openingBalance: -2443000,
      closingBalance: -1474000,
    ),
    PreviewLegacyMonthlySummary(
      month: DateTime(2025, 9),
      label: 'September 2025',
      income: 13145000,
      expense: 8780000,
      profit: 4365000,
      openingBalance: -1474000,
      closingBalance: 2891000,
    ),
    PreviewLegacyMonthlySummary(
      month: DateTime(2025, 10),
      label: 'Oktober 2025',
      income: 13777500,
      expense: 7950000,
      profit: 5827500,
      openingBalance: 2891000,
      closingBalance: 8718500,
    ),
    PreviewLegacyMonthlySummary(
      month: DateTime(2025, 11),
      label: 'November 2025',
      income: 10875000,
      expense: 7205500,
      profit: 3669500,
      openingBalance: 8718500,
      closingBalance: 12388000,
    ),
    PreviewLegacyMonthlySummary(
      month: DateTime(2025, 12),
      label: 'Desember 2025',
      income: 13838000,
      expense: 9317000,
      profit: 4521000,
      openingBalance: 12388000,
      closingBalance: 16909000,
    ),
    PreviewLegacyMonthlySummary(
      month: DateTime(2026, 1),
      label: 'Januari 2026',
      income: 9985500,
      expense: 5700000,
      profit: 4285500,
      openingBalance: 16909000,
      closingBalance: 21194500,
    ),
    PreviewLegacyMonthlySummary(
      month: DateTime(2026, 2),
      label: 'Februari 2026',
      income: 9985500,
      expense: 5700000,
      profit: 4285500,
      openingBalance: 21194500,
      closingBalance: 25480000,
    ),
    PreviewLegacyMonthlySummary(
      month: DateTime(2026, 3),
      label: 'Maret 2026',
      income: 17921500,
      expense: 8687500,
      profit: 9234000,
      openingBalance: 25480000,
      closingBalance: 34714000,
    ),
    PreviewLegacyMonthlySummary(
      month: DateTime(2026, 4),
      label: 'April 2026',
      income: 6257500,
      expense: 8687500,
      profit: -2430000,
      openingBalance: 34714000,
      closingBalance: 32284000,
    ),
  ];
  static const _defaultServices = [
    PreviewService(
      id: 'service-cs-reguler',
      name: 'Cuci Setrika Reguler',
      category: 'Cuci Setrika',
      unit: 'KG',
      price: 7000,
      estimatedHours: 72,
      isExpress: false,
      isActive: true,
      groupName: 'Kiloan',
      categoryName: 'Cuci Setrika',
      itemName: 'Cuci Setrika',
      variantName: 'Reguler',
      sortOrder: 10,
    ),
    PreviewService(
      id: 'service-cs-express',
      name: 'Cuci Setrika Express',
      category: 'Cuci Setrika',
      unit: 'KG',
      price: 9000,
      estimatedHours: 24,
      isExpress: true,
      isActive: true,
      groupName: 'Kiloan',
      categoryName: 'Cuci Setrika',
      itemName: 'Cuci Setrika',
      variantName: 'Express',
      sortOrder: 11,
    ),
    PreviewService(
      id: 'service-cs-kilat',
      name: 'Cuci Setrika Kilat',
      category: 'Cuci Setrika',
      unit: 'KG',
      price: 12000,
      estimatedHours: 8,
      isExpress: true,
      isActive: true,
      groupName: 'Kiloan',
      categoryName: 'Cuci Setrika',
      itemName: 'Cuci Setrika',
      variantName: 'Kilat',
      sortOrder: 12,
    ),
    PreviewService(
      id: 'service-ckl-reguler',
      name: 'Cuci Lipat Reguler',
      category: 'Cuci Lipat',
      unit: 'KG',
      price: 4000,
      estimatedHours: 72,
      isExpress: false,
      isActive: true,
      groupName: 'Kiloan',
      categoryName: 'Cuci Lipat',
      itemName: 'Cuci Lipat',
      variantName: 'Reguler',
      sortOrder: 20,
    ),
    PreviewService(
      id: 'service-ckl-express',
      name: 'Cuci Lipat Express',
      category: 'Cuci Lipat',
      unit: 'KG',
      price: 6000,
      estimatedHours: 24,
      isExpress: true,
      isActive: true,
      groupName: 'Kiloan',
      categoryName: 'Cuci Lipat',
      itemName: 'Cuci Lipat',
      variantName: 'Express',
      sortOrder: 21,
    ),
    PreviewService(
      id: 'service-ckl-kilat',
      name: 'Cuci Lipat Kilat',
      category: 'Cuci Lipat',
      unit: 'KG',
      price: 9000,
      estimatedHours: 8,
      isExpress: true,
      isActive: true,
      groupName: 'Kiloan',
      categoryName: 'Cuci Lipat',
      itemName: 'Cuci Lipat',
      variantName: 'Kilat',
      sortOrder: 22,
    ),
    PreviewService(
      id: 'service-sl-reguler',
      name: 'Setrika Lipat Reguler',
      category: 'Setrika Lipat',
      unit: 'KG',
      price: 5000,
      estimatedHours: 72,
      isExpress: false,
      isActive: true,
      groupName: 'Kiloan',
      categoryName: 'Setrika Lipat',
      itemName: 'Setrika Lipat',
      variantName: 'Reguler',
      sortOrder: 30,
    ),
    PreviewService(
      id: 'service-sl-express',
      name: 'Setrika Lipat Express',
      category: 'Setrika Lipat',
      unit: 'KG',
      price: 7000,
      estimatedHours: 24,
      isExpress: true,
      isActive: true,
      groupName: 'Kiloan',
      categoryName: 'Setrika Lipat',
      itemName: 'Setrika Lipat',
      variantName: 'Express',
      sortOrder: 31,
    ),
    PreviewService(
      id: 'service-sl-kilat',
      name: 'Setrika Lipat Kilat',
      category: 'Setrika Lipat',
      unit: 'KG',
      price: 10000,
      estimatedHours: 8,
      isExpress: true,
      isActive: true,
      groupName: 'Kiloan',
      categoryName: 'Setrika Lipat',
      itemName: 'Setrika Lipat',
      variantName: 'Kilat',
      sortOrder: 32,
    ),
    PreviewService(
      id: 'service-satuan-kaos',
      name: 'Kaos',
      category: 'Pakaian',
      unit: 'PIECE',
      price: 5000,
      estimatedHours: 72,
      isExpress: false,
      isActive: true,
      groupName: 'Satuan',
      categoryName: 'Pakaian',
      itemName: 'Kaos',
      variantName: 'Reguler',
      sortOrder: 100,
    ),
    PreviewService(
      id: 'service-satuan-polo-shirt',
      name: 'Polo Shirt',
      category: 'Pakaian',
      unit: 'PIECE',
      price: 5000,
      estimatedHours: 72,
      isExpress: false,
      isActive: true,
      groupName: 'Satuan',
      categoryName: 'Pakaian',
      itemName: 'Polo Shirt',
      variantName: 'Reguler',
      sortOrder: 101,
    ),
    PreviewService(
      id: 'service-satuan-singlet',
      name: 'Singlet',
      category: 'Pakaian',
      unit: 'PIECE',
      price: 5000,
      estimatedHours: 72,
      isExpress: false,
      isActive: true,
      groupName: 'Satuan',
      categoryName: 'Pakaian',
      itemName: 'Singlet',
      variantName: 'Reguler',
      sortOrder: 102,
    ),
    PreviewService(
      id: 'service-satuan-kemeja-pendek',
      name: 'Kemeja Pendek',
      category: 'Pakaian',
      unit: 'PIECE',
      price: 6000,
      estimatedHours: 72,
      isExpress: false,
      isActive: true,
      groupName: 'Satuan',
      categoryName: 'Pakaian',
      itemName: 'Kemeja',
      variantName: 'Pendek',
      sortOrder: 110,
    ),
    PreviewService(
      id: 'service-satuan-kemeja-panjang',
      name: 'Kemeja Panjang',
      category: 'Pakaian',
      unit: 'PIECE',
      price: 6000,
      estimatedHours: 72,
      isExpress: false,
      isActive: true,
      groupName: 'Satuan',
      categoryName: 'Pakaian',
      itemName: 'Kemeja',
      variantName: 'Panjang',
      sortOrder: 111,
    ),
    PreviewService(
      id: 'service-satuan-celana-chino',
      name: 'Celana Chino',
      category: 'Pakaian',
      unit: 'PIECE',
      price: 7000,
      estimatedHours: 72,
      isExpress: false,
      isActive: true,
      groupName: 'Satuan',
      categoryName: 'Pakaian',
      itemName: 'Celana',
      variantName: 'Chino',
      sortOrder: 120,
    ),
    PreviewService(
      id: 'service-satuan-jaket',
      name: 'Jaket',
      category: 'Pakaian',
      unit: 'PIECE',
      price: 10000,
      estimatedHours: 72,
      isExpress: false,
      isActive: true,
      groupName: 'Satuan',
      categoryName: 'Pakaian',
      itemName: 'Jaket',
      variantName: 'Reguler',
      sortOrder: 130,
    ),
    PreviewService(
      id: 'service-satuan-hoodie',
      name: 'Hoodie',
      category: 'Pakaian',
      unit: 'PIECE',
      price: 10000,
      estimatedHours: 72,
      isExpress: false,
      isActive: true,
      groupName: 'Satuan',
      categoryName: 'Pakaian',
      itemName: 'Hoodie',
      variantName: 'Reguler',
      sortOrder: 131,
    ),
    PreviewService(
      id: 'service-satuan-dress',
      name: 'Dress',
      category: 'Pakaian',
      unit: 'PIECE',
      price: 10000,
      estimatedHours: 72,
      isExpress: false,
      isActive: true,
      groupName: 'Satuan',
      categoryName: 'Pakaian',
      itemName: 'Dress',
      variantName: 'Pendek',
      sortOrder: 140,
    ),
    PreviewService(
      id: 'service-satuan-sprei-single',
      name: 'Sprei Single',
      category: 'Alat Tidur',
      unit: 'PIECE',
      price: 10000,
      estimatedHours: 72,
      isExpress: false,
      isActive: true,
      groupName: 'Satuan',
      categoryName: 'Alat Tidur',
      itemName: 'Sprei',
      variantName: 'Single',
      sortOrder: 200,
    ),
    PreviewService(
      id: 'service-satuan-sprei-double',
      name: 'Sprei Double',
      category: 'Alat Tidur',
      unit: 'PIECE',
      price: 15000,
      estimatedHours: 72,
      isExpress: false,
      isActive: true,
      groupName: 'Satuan',
      categoryName: 'Alat Tidur',
      itemName: 'Sprei',
      variantName: 'Double',
      sortOrder: 201,
    ),
    PreviewService(
      id: 'service-satuan-bedcover-single',
      name: 'Bedcover Single',
      category: 'Alat Tidur',
      unit: 'PIECE',
      price: 20000,
      estimatedHours: 72,
      isExpress: false,
      isActive: true,
      groupName: 'Satuan',
      categoryName: 'Alat Tidur',
      itemName: 'Bedcover',
      variantName: 'Single',
      sortOrder: 210,
    ),
    PreviewService(
      id: 'service-satuan-bedcover-double',
      name: 'Bedcover Double',
      category: 'Alat Tidur',
      unit: 'PIECE',
      price: 30000,
      estimatedHours: 72,
      isExpress: false,
      isActive: true,
      groupName: 'Satuan',
      categoryName: 'Alat Tidur',
      itemName: 'Bedcover',
      variantName: 'Double',
      sortOrder: 211,
    ),
    PreviewService(
      id: 'service-satuan-bedcover-king',
      name: 'Bedcover King Size',
      category: 'Alat Tidur',
      unit: 'PIECE',
      price: 40000,
      estimatedHours: 72,
      isExpress: false,
      isActive: true,
      groupName: 'Satuan',
      categoryName: 'Alat Tidur',
      itemName: 'Bedcover',
      variantName: 'King Size',
      sortOrder: 212,
    ),
    PreviewService(
      id: 'service-satuan-sarung-bantal',
      name: 'Sarung Bantal',
      category: 'Alat Tidur',
      unit: 'PIECE',
      price: 2000,
      estimatedHours: 72,
      isExpress: false,
      isActive: true,
      groupName: 'Satuan',
      categoryName: 'Alat Tidur',
      itemName: 'Sarung',
      variantName: 'Bantal',
      sortOrder: 220,
    ),
    PreviewService(
      id: 'service-satuan-sarung-guling',
      name: 'Sarung Guling',
      category: 'Alat Tidur',
      unit: 'PIECE',
      price: 3000,
      estimatedHours: 72,
      isExpress: false,
      isActive: true,
      groupName: 'Satuan',
      categoryName: 'Alat Tidur',
      itemName: 'Sarung',
      variantName: 'Guling',
      sortOrder: 221,
    ),
    PreviewService(
      id: 'service-satuan-boneka-sedang',
      name: 'Boneka Sedang',
      category: 'Lainnya',
      unit: 'PIECE',
      price: 15000,
      estimatedHours: 72,
      isExpress: false,
      isActive: true,
      groupName: 'Satuan',
      categoryName: 'Lainnya',
      itemName: 'Boneka',
      variantName: 'Sedang',
      sortOrder: 300,
    ),
    PreviewService(
      id: 'service-sepatu-reguler',
      name: 'Cuci Sepatu Reguler',
      category: 'Sepatu',
      unit: 'PAIR',
      price: 25000,
      estimatedHours: 72,
      isExpress: false,
      isActive: true,
      groupName: 'Sepatu',
      categoryName: 'Sepatu',
      itemName: 'Cuci Sepatu',
      variantName: 'Reguler',
      sortOrder: 400,
    ),
    PreviewService(
      id: 'service-helm-reguler',
      name: 'Cuci Helm Reguler',
      category: 'Helm',
      unit: 'ITEM',
      price: 20000,
      estimatedHours: 72,
      isExpress: false,
      isActive: true,
      groupName: 'Helm',
      categoryName: 'Helm',
      itemName: 'Cuci Helm',
      variantName: 'Reguler',
      sortOrder: 500,
    ),
    PreviewService(
      id: 'service-extra-express',
      name: 'Express',
      category: 'Layanan Tambahan',
      unit: 'ITEM',
      price: 5000,
      estimatedHours: 24,
      isExpress: true,
      isActive: true,
      groupName: 'Layanan Tambahan',
      categoryName: 'Tambahan Waktu',
      itemName: 'Express',
      variantName: 'Tambahan',
      sortOrder: 600,
    ),
    PreviewService(
      id: 'service-extra-noda-berat',
      name: 'Noda Berat',
      category: 'Layanan Tambahan',
      unit: 'ITEM',
      price: 5000,
      estimatedHours: 72,
      isExpress: false,
      isActive: true,
      groupName: 'Layanan Tambahan',
      categoryName: 'Treatment',
      itemName: 'Noda Berat',
      variantName: 'Tambahan',
      sortOrder: 610,
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
    return PreviewDataState(
      customers: [customer, ...importedCustomers],
      services: _defaultServices,
      orders: const [],
      payments: const [],
      cashTransactions: const [],
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
      legacyMonthlySummaries: _legacyMonthlySummaries,
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
      category: category.trim(),
      unit: unit.trim().toUpperCase(),
      price: price,
      estimatedHours: estimatedHours,
      isExpress: isExpress,
      isActive: true,
      groupName: unit.trim().toUpperCase() == 'KG' ? 'Kiloan' : 'Satuan',
      categoryName: category.trim(),
      itemName: name.trim(),
      variantName: 'Manual',
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
    final servicesById = {
      for (final service in state.services) service.id: service,
    };
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
    final currentOrder = state.orders.firstWhere(
      (order) => order.id == orderId,
    );
    if (status == PreviewOrderStatus.pickedUp &&
        currentOrder.remainingAmount > 0) {
      throw StateError('Pesanan belum lunas. Bayar dulu sebelum diambil.');
    }
    final nextOrder = currentOrder.copyWith(orderStatus: status);
    final nextCash = [...state.cashTransactions];
    final nextExpenses = [...state.expenses];
    if (status == PreviewOrderStatus.ready) {
      _appendShoeIncentiveIfNeeded(nextOrder, nextCash, nextExpenses);
    }
    state = state.copyWith(
      orders: [
        for (final order in state.orders)
          if (order.id == orderId) nextOrder else order,
      ],
      cashTransactions: nextCash,
      expenses: nextExpenses,
    );
  }

  void updateOrderDetails({
    required String orderId,
    required PreviewOrderStatus status,
    required String employeeId,
    required String note,
  }) {
    final currentOrder = state.orders.firstWhere(
      (order) => order.id == orderId,
    );
    if (status == PreviewOrderStatus.pickedUp &&
        currentOrder.remainingAmount > 0) {
      throw StateError('Pesanan belum lunas. Bayar dulu sebelum diambil.');
    }
    final updatedOrder = currentOrder.copyWith(
      orderStatus: status,
      assignedEmployeeId: employeeId,
      note: note.trim(),
    );
    final nextCash = [...state.cashTransactions];
    final nextExpenses = [...state.expenses];
    if (status == PreviewOrderStatus.ready) {
      _appendShoeIncentiveIfNeeded(updatedOrder, nextCash, nextExpenses);
    }
    state = state.copyWith(
      orders: [
        for (final order in state.orders)
          if (order.id == orderId) updatedOrder else order,
      ],
      cashTransactions: nextCash,
      expenses: nextExpenses,
    );
  }

  void deleteOrder(String orderId) {
    final paymentIds = state.payments
        .where((payment) => payment.orderId == orderId)
        .map((payment) => payment.id)
        .toSet();
    final incentiveReferenceId = 'SHOE-INCENTIVE-$orderId';
    state = state.copyWith(
      orders: [
        for (final order in state.orders)
          if (order.id != orderId) order,
      ],
      payments: [
        for (final payment in state.payments)
          if (payment.orderId != orderId) payment,
      ],
      cashTransactions: [
        for (final cash in state.cashTransactions)
          if (!paymentIds.contains(cash.referenceId) &&
              cash.referenceId != incentiveReferenceId)
            cash,
      ],
      expenses: [
        for (final expense in state.expenses)
          if (expense.id != incentiveReferenceId) expense,
      ],
    );
  }

  void _appendShoeIncentiveIfNeeded(
    PreviewOrder order,
    List<PreviewCashTransaction> cash,
    List<PreviewExpense> expenses,
  ) {
    final shoePairs = order.items
        .where((item) {
          final text = '${item.serviceNameSnapshot} ${item.unit}'.toLowerCase();
          return text.contains('sepatu') || text.contains('pasang');
        })
        .fold<double>(0, (sum, item) => sum + item.quantity);
    if (shoePairs <= 0) {
      return;
    }
    final referenceId = 'SHOE-INCENTIVE-${order.id}';
    final alreadyRecorded = cash.any(
      (entry) =>
          entry.referenceType == 'EMPLOYEE_INCENTIVE' &&
          entry.referenceId == referenceId,
    );
    if (alreadyRecorded) {
      return;
    }
    final employeeName =
        state.employees
            .where((employee) => employee.id == order.assignedEmployeeId)
            .map((employee) => employee.name)
            .firstOrNull ??
        'Karyawan';
    final amount = (shoePairs * 10000).round();
    final description =
        'Insentif cuci ${shoePairs.toStringAsFixed(0)} pasang sepatu untuk $employeeName, Nota ${order.orderNumber}';
    final now = DateTime.now();
    cash.insert(
      0,
      PreviewCashTransaction(
        id: _uuid.v4(),
        referenceId: referenceId,
        referenceType: 'EMPLOYEE_INCENTIVE',
        type: 'OUT',
        category: 'Gaji dan Insentif Karyawan',
        description: description,
        amount: amount,
        method: 'Tunai',
        createdAt: now,
      ),
    );
    expenses.insert(
      0,
      PreviewExpense(
        id: referenceId,
        description: description,
        category: 'Insentif Cuci Sepatu',
        amount: amount,
        method: 'Tunai',
        createdAt: now,
      ),
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
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    final shift = _shiftFor(employeeId, today);
    final existing = state.attendance.where((entry) {
      return entry.employeeId == employeeId &&
          entry.date.year == today.year &&
          entry.date.month == today.month &&
          entry.date.day == today.day;
    }).toList();

    if (!isCheckOut) {
      final shiftStart = _timeOnDate(today, shift.startTime);
      if (today.isBefore(shiftStart)) {
        throw StateError(
          'Absen masuk belum dibuka. Jadwal mulai ${_formatTime(shiftStart)}.',
        );
      }
      if (existing.isNotEmpty) {
        throw StateError('Karyawan sudah absen masuk hari ini.');
      }
      final shiftEnd = _timeOnDate(today, shift.endTime);
      final lateMinutes = today.isAfter(shiftStart)
          ? today.difference(shiftStart).inMinutes
          : 0;
      final attendanceStatus = lateMinutes == 0
          ? PreviewAttendanceStatus.onTime
          : lateMinutes <= _lateTolerance.inMinutes
          ? PreviewAttendanceStatus.late
          : PreviewAttendanceStatus.severelyLate;
      final warningMessage = lateMinutes == 0
          ? null
          : lateMinutes <= _lateTolerance.inMinutes
          ? '$employeeName terlambat $lateMinutes menit untuk shift ${shift.startTime}-${shift.endTime}.'
          : '$employeeName terlambat lebih dari 2 jam untuk shift ${shift.startTime}-${shift.endTime}.';
      final attendance = PreviewAttendance(
        id: _uuid.v4(),
        employeeId: employeeId,
        employeeName: employeeName,
        date: today,
        checkInAt: today,
        status: attendanceStatus.label,
        attendanceStatus: attendanceStatus,
        scheduledStart: shiftStart,
        scheduledEnd: shiftEnd,
        lateMinutes: lateMinutes,
        shiftLabel: '${shift.startTime}-${shift.endTime}',
        note:
            'Foto masuk: $photoPath. Shift ${shift.startTime}-${shift.endTime}.',
      );
      state = state.copyWith(
        attendance: [attendance, ...state.attendance],
        notifications: [
          if (warningMessage != null)
            _notification('Perhatian absensi', warningMessage, '/attendance'),
          ...state.notifications,
        ],
      );
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
    final earlyLeaveMinutes = today.isBefore(shiftEnd)
        ? shiftEnd.difference(today).inMinutes
        : 0;
    state = state.copyWith(
      attendance: [
        for (final entry in state.attendance)
          if (entry.id == current.id)
            entry.copyWith(
              checkOutAt: today,
              earlyLeaveMinutes: earlyLeaveMinutes,
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
