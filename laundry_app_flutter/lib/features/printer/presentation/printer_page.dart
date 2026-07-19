import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_snack_bar.dart';
import '../../../core/widgets/responsive_page.dart';
import '../../../shared/preview_data.dart';
import '../../orders/presentation/receipt_preview_sheet.dart';

class PrinterPage extends ConsumerWidget {
  const PrinterPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            const Card(
              child: ListTile(
                leading: Icon(Icons.print_outlined),
                title: Text('Printer thermal belum dipilih'),
                subtitle: Text(
                  'Aplikasi tetap bisa preview struk, simpan PDF, dan share ringkasan.',
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => showAppSnackBar(
                'Test koneksi printer akan aktif saat plugin Bluetooth dipasang.',
              ),
              icon: const Icon(Icons.bluetooth_searching),
              label: const Text('Test Koneksi'),
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
                      employeeName: employeeName,
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
