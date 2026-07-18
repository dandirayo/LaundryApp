import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/extensions/currency_extensions.dart';
import '../../../core/widgets/responsive_page.dart';
import '../../../shared/preview_data.dart';

class ReportsPage extends ConsumerWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(previewDataProvider);
    final orderValue = data.orders.fold<int>(
      0,
      (sum, order) => sum + order.totalPrice,
    );
    final paid = data.orders.fold<int>(
      0,
      (sum, order) => sum + order.paidAmount,
    );
    final remaining = data.orders.fold<int>(
      0,
      (sum, order) => sum + order.remainingAmount,
    );
    final income = data.cashTransactions
        .where((entry) => entry.type == 'IN')
        .fold<int>(0, (sum, entry) => sum + entry.amount);
    final outcome = data.cashTransactions
        .where((entry) => entry.type == 'OUT')
        .fold<int>(0, (sum, entry) => sum + entry.amount);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Laporan'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Buku Pesanan'),
              Tab(text: 'Buku Kas'),
            ],
          ),
        ),
        body: ResponsivePage(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: TabBarView(
            children: [
              ListView(
                children: [
                  _Metric('Jumlah pesanan', '${data.orders.length}'),
                  _Metric('Pelanggan unik', '${data.customers.length}'),
                  _Metric(
                    'Total kilogram',
                    '${data.orders.fold<double>(0, (sum, order) => sum + order.totalQuantity).toStringAsFixed(1)} kg',
                  ),
                  _Metric('Nilai pesanan', orderValue.toRupiah()),
                  _Metric('Pembayaran diterima', paid.toRupiah()),
                  _Metric('Sisa tagihan', remaining.toRupiah()),
                  _Metric(
                    'Pesanan selesai',
                    '${data.orders.where((order) => order.orderStatus == PreviewOrderStatus.ready || order.orderStatus == PreviewOrderStatus.pickedUp).length}',
                  ),
                ],
              ),
              ListView(
                children: [
                  _Metric('Saldo awal', 0.toRupiah()),
                  _Metric('Total uang masuk', income.toRupiah()),
                  _Metric('Total uang keluar', outcome.toRupiah()),
                  _Metric('Saldo akhir', (income - outcome).toRupiah()),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      ref
                          .read(previewDataProvider.notifier)
                          .recordBackupExport('Laporan CSV/PDF');
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Export laporan preview disiapkan.'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.file_download_outlined),
                    label: const Text('Export CSV/PDF'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(label),
        trailing: Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}
