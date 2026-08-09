import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/extensions/date_time_extensions.dart';
import '../../../core/utils/ui_action_queue.dart';
import '../../../core/widgets/app_bottom_sheet_body.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../core/widgets/responsive_page.dart';
import '../../../shared/preview_data.dart';

class BackupPage extends ConsumerWidget {
  const BackupPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(
      previewDataProvider.select(
        (state) => (
          customers: state.customers,
          services: state.services,
          orders: state.orders,
          payments: state.payments,
          cashTransactions: state.cashTransactions,
          inventory: state.inventory,
          employees: state.employees,
          lastBackupAt: state.lastBackupAt,
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Backup Data')),
      body: ResponsivePage(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: ListView(
          children: [
            _BackupTile('Pelanggan', data.customers.length),
            _BackupTile('Layanan', data.services.length),
            _BackupTile('Pesanan', data.orders.length),
            _BackupTile('Pembayaran', data.payments.length),
            _BackupTile('Buku Kas', data.cashTransactions.length),
            _BackupTile('Stok', data.inventory.length),
            _BackupTile('Karyawan', data.employees.length),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.schedule_outlined),
                title: const Text('Backup terakhir'),
                subtitle: Text(
                  data.lastBackupAt == null
                      ? 'Belum pernah export di sesi ini.'
                      : '${data.lastBackupAt!.toIndonesianDate()} ${data.lastBackupAt!.toIndonesianTime()}',
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _showExportSheet(context, ref),
              icon: const Icon(Icons.file_download_outlined),
              label: const Text('Export JSON/CSV'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _showImportGuide(context),
              icon: const Icon(Icons.upload_file_outlined),
              label: const Text('Format Import Universal'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showExportSheet(BuildContext context, WidgetRef ref) async {
    final format = await showAppModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => AppBottomSheetBody(
        children: [
          const Text(
            'Pilih Format Export',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop('JSON'),
            icon: const Icon(Icons.data_object),
            label: const Text('JSON'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).pop('CSV'),
            icon: const Icon(Icons.table_chart_outlined),
            label: const Text('CSV'),
          ),
        ],
      ),
    );
    if (format == null || !context.mounted) {
      return;
    }
    await waitForTransientUiDismissal();
    if (!context.mounted) {
      return;
    }
    ref.read(previewDataProvider.notifier).recordBackupExport(format);
    showAppSnackBar('Export $format preview berhasil disiapkan.');
  }

  Future<void> _showImportGuide(BuildContext context) {
    return showAppModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => AppBottomSheetBody(
        children: const [
          Text(
            'Format Import Universal',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          SizedBox(height: 12),
          Text(
            'Untuk Excel/CSV, pakai header berikut agar data mudah dibaca otomatis:',
          ),
          SizedBox(height: 12),
          _ImportFormatTile(
            title: 'Pelanggan',
            columns: 'nama, whatsapp, alamat, catatan',
          ),
          _ImportFormatTile(
            title: 'Layanan / Harga',
            columns:
                'kategori, nama_layanan, nama_item, varian, satuan, harga, estimasi_jam',
          ),
          _ImportFormatTile(
            title: 'Nota / Pesanan',
            columns:
                'nomor_nota, tanggal, pelanggan, whatsapp, layanan, jumlah, satuan, harga, total, dibayar, status',
          ),
          SizedBox(height: 8),
          Text(
            'Import file langsung akan aktif setelah modul file picker dan parser Excel dipasang. Sementara format ini jadi patokan agar data lama bisa masuk rapi.',
          ),
        ],
      ),
    );
  }
}

class _BackupTile extends StatelessWidget {
  const _BackupTile(this.label, this.count);

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.dataset_outlined),
        title: Text(label),
        trailing: Text(
          '$count data',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _ImportFormatTile extends StatelessWidget {
  const _ImportFormatTile({required this.title, required this.columns});

  final String title;
  final String columns;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.table_chart_outlined),
        title: Text(title),
        subtitle: Text(columns),
      ),
    );
  }
}
