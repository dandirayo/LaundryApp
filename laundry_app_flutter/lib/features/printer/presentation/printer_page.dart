import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_snack_bar.dart';
import '../../../core/services/bluetooth_receipt_printer.dart';
import '../../../core/errors/failure.dart';
import '../../../core/widgets/responsive_page.dart';
import '../../../shared/preview_data.dart';
import '../../orders/presentation/receipt_preview_sheet.dart';

class PrinterPage extends ConsumerStatefulWidget {
  const PrinterPage({super.key});

  @override
  ConsumerState<PrinterPage> createState() => _PrinterPageState();
}

class _PrinterPageState extends ConsumerState<PrinterPage> {
  final _printer = BluetoothReceiptPrinter.instance;
  bool _busy = false;
  String? _name;
  String _status = 'Pilih printer untuk mulai mencetak.';

  @override
  void initState() {
    super.initState();
    _printer.selectedName().then((name) {
      if (mounted) setState(() => _name = name);
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      final message = error is Failure
          ? error.message
          : 'Koneksi gagal. Periksa Bluetooth dan coba lagi.';
      if (mounted) setState(() => _status = message);
      showAppSnackBar(message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _choose() async {
    final devices = await _printer.devices();
    if (!mounted) return;
    if (devices.isEmpty) {
      setState(
        () => _status =
            'Pasangkan printer melalui Pengaturan Bluetooth HP, lalu tekan Pilih Printer lagi.',
      );
      return;
    }
    final index = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Pilih printer thermal'),
        children: [
          for (var i = 0; i < devices.length; i++)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, i),
              child: Text('${devices[i].name}\n${devices[i].macAdress}'),
            ),
        ],
      ),
    );
    if (index == null) return;
    await _printer.select(devices[index]);
    if (mounted) {
      setState(() {
        _name = devices[index].name;
        _status = 'Terhubung. Gunakan Cetak Tes untuk memeriksa hasil cetak.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(previewDataProvider);
    final latestOrder = data.orders.firstOrNull;
    final latestPayments = latestOrder == null
        ? <PreviewPayment>[]
        : data.payments
              .where((payment) => payment.orderId == latestOrder.id)
              .toList();
    final employeeName = latestOrder == null
        ? '-'
        : data.employees
                  .where(
                    (employee) => employee.id == latestOrder.assignedEmployeeId,
                  )
                  .map((employee) => employee.name)
                  .firstOrNull ??
              'Belum ditugaskan';

    return Scaffold(
      appBar: AppBar(title: const Text('Printer')),
      body: ResponsivePage(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: ListView(
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.print_outlined),
                title: Text(_name ?? 'Printer thermal belum dipilih'),
                subtitle: Text(_status),
              ),
            ),
            const SizedBox(height: 12),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Nyalakan printer, lalu pasangkan melalui Pengaturan Bluetooth HP. Setelah dipasangkan, pilih printer di bawah. Mendukung printer struk Bluetooth ESC/POS.',
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _busy ? null : () => _run(_choose),
              icon: const Icon(Icons.bluetooth_searching),
              label: Text(_busy ? 'Mohon tunggu...' : 'Pilih Printer'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _busy || _name == null
                  ? null
                  : () => _run(() async {
                      await _printer.testConnection();
                      if (mounted) {
                        setState(
                          () => _status =
                              'Koneksi tersedia. Cetak Tes untuk memastikan printer merespons.',
                        );
                      }
                    }),
              icon: const Icon(Icons.bluetooth_connected),
              label: const Text('Test Koneksi'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _busy || _name == null
                  ? null
                  : () => _run(() async {
                      await _printer.printLines([
                        'IDOLA LAUNDRY',
                        'TES PRINTER THERMAL',
                        '------------------------------------------------',
                        'Koneksi Bluetooth berhasil.',
                        '0123456789',
                        'Terima kasih',
                      ], paperWidth: 80);
                      showAppSnackBar(
                        'Data tes dikirim. Periksa hasil pada printer.',
                      );
                    }),
              icon: const Icon(Icons.print),
              label: const Text('Cetak Tes'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: latestOrder == null
                  ? null
                  : () => showReceiptPreviewSheet(
                      context: context,
                      order: latestOrder,
                      payments: latestPayments,
                      shopName: data.shopName,
                      shopAddress: data.shopAddress,
                      employeeName: latestOrder.receivedByName.trim().isEmpty
                          ? employeeName
                          : latestOrder.receivedByName,
                    ),
              icon: const Icon(Icons.receipt_long_outlined),
              label: Text(
                latestOrder == null
                    ? 'Belum ada struk'
                    : 'Preview Struk Terakhir',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
