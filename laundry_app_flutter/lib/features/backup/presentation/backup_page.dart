import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/extensions/date_time_extensions.dart';
import '../../../core/widgets/responsive_page.dart';
import '../../../shared/preview_data.dart';

class BackupPage extends ConsumerWidget {
  const BackupPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(previewDataProvider);

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
          ],
        ),
      ),
    );
  }

  Future<void> _showExportSheet(BuildContext context, WidgetRef ref) async {
    final format = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
      ),
    );
    if (format == null || !context.mounted) {
      return;
    }
    ref.read(previewDataProvider.notifier).recordBackupExport(format);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Export $format preview berhasil disiapkan.')),
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
