enum RequestCategory {
  stock('Kebutuhan Stok'),
  schedule('Izin & Jadwal'),
  funds('Dana & Biaya');

  const RequestCategory(this.label);
  final String label;
}

enum RequestKind {
  stock('Request Stok', 'Kebutuhan Stok', RequestCategory.stock),
  leave('Request Izin', 'Izin', RequestCategory.schedule),
  shiftSwap('Request Tukar Shift', 'Tukar Shift', RequestCategory.schedule),
  overtime('Request Lembur', 'Lembur', RequestCategory.schedule),
  cashAdvance('Request Kasbon', 'Kasbon', RequestCategory.funds),
  expense('Request Pengeluaran', 'Biaya Operasional', RequestCategory.funds);

  const RequestKind(this.storageValue, this.label, this.category);
  final String storageValue;
  final String label;
  final RequestCategory category;

  bool get needsMoney => category == RequestCategory.funds;

  static RequestKind? fromStorage(String? value) {
    for (final kind in values) {
      if (kind.storageValue == value) return kind;
    }
    return null;
  }
}

const forgotAttendanceRequestType = 'Lupa Absen';

// Keep historical incentive requests readable/reviewable without offering new ones.
RequestCategory? requestCategory(String type) => switch (type) {
  'Request Insentif' => RequestCategory.funds,
  forgotAttendanceRequestType => RequestCategory.schedule,
  _ => RequestKind.fromStorage(type)?.category,
};

String requestLabel(String type) => type == 'Request Insentif'
    ? 'Insentif'
    : RequestKind.fromStorage(type)?.label ?? type;

class RequestSubmission {
  const RequestSubmission({
    required this.kind,
    required this.summary,
    required this.amount,
  });

  final RequestKind kind;

  // Human-readable details use the existing reason column so older clients and
  // the owner's review, notifications and cashbook retain the complete context.
  final String summary;
  final int amount;
}
