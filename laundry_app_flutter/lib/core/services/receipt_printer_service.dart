import '../errors/failure.dart';

abstract interface class ReceiptPrinterService {
  Future<PrinterStatus> status();

  Future<void> testConnection();

  Future<void> testPrint();
}

class PrinterStatus {
  const PrinterStatus({required this.isAvailable, required this.message});

  final bool isAvailable;
  final String message;
}

class UnavailableReceiptPrinterService implements ReceiptPrinterService {
  const UnavailableReceiptPrinterService();

  @override
  Future<PrinterStatus> status() async {
    return const PrinterStatus(
      isAvailable: false,
      message: 'Printer belum dipilih. Preview dan PDF tetap tersedia.',
    );
  }

  @override
  Future<void> testConnection() async {
    throw const Failure(
      code: 'printer-not-configured',
      message: 'Printer thermal belum dikonfigurasi pada perangkat ini.',
    );
  }

  @override
  Future<void> testPrint() async {
    throw const Failure(
      code: 'printer-not-configured',
      message: 'Hubungkan printer terlebih dahulu sebelum test print.',
    );
  }
}
