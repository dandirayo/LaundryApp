import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/extensions/currency_extensions.dart';
import '../../../core/extensions/date_time_extensions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../core/widgets/responsive_page.dart';
import '../../../shared/preview_data.dart';

class CashbookPage extends ConsumerWidget {
  const CashbookPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cash = ref.watch(previewDataProvider).cashTransactions;
    final income = cash
        .where((entry) => entry.type == 'IN')
        .fold<int>(0, (sum, entry) => sum + entry.amount);
    final outcome = cash
        .where((entry) => entry.type == 'OUT')
        .fold<int>(0, (sum, entry) => sum + entry.amount);

    return Scaffold(
      appBar: AppBar(title: const Text('Buku Kas')),
      body: ResponsivePage(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: ListView(
          children: [
            Row(
              children: [
                Expanded(
                  child: _TotalTile('Uang Masuk', income, AppColors.success),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TotalTile('Uang Keluar', outcome, AppColors.error),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _TotalTile('Saldo Akhir', income - outcome, AppColors.primaryNavy),
            const SizedBox(height: 16),
            if (cash.isEmpty)
              const AppStateView.empty(
                title: 'Transaksi kas belum ada',
                message:
                    'Pembayaran pesanan dan pengeluaran akan masuk ke sini.',
              )
            else
              for (final entry in cash) ...[
                Card(
                  child: ListTile(
                    leading: Icon(
                      entry.type == 'IN' ? Icons.south_west : Icons.north_east,
                      color: entry.type == 'IN'
                          ? AppColors.success
                          : AppColors.error,
                    ),
                    title: Text(entry.description),
                    subtitle: Text(
                      '${entry.category} - ${entry.method}\n${entry.createdAt.toIndonesianDate()} ${entry.createdAt.toIndonesianTime()}',
                    ),
                    isThreeLine: true,
                    trailing: Text(
                      entry.amount.toRupiah(),
                      style: TextStyle(
                        color: entry.type == 'IN'
                            ? AppColors.success
                            : AppColors.error,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
          ],
        ),
      ),
    );
  }
}

class _TotalTile extends StatelessWidget {
  const _TotalTile(this.label, this.amount, this.color);

  final String label;
  final int amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: AppColors.secondaryText)),
            const SizedBox(height: 6),
            Text(
              amount.toRupiah(),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
