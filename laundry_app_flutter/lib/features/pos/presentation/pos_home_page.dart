import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/extensions/currency_extensions.dart';
import '../../../core/extensions/date_time_extensions.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../core/widgets/responsive_page.dart';
import '../../businesses/presentation/business_controller.dart';
import 'pos_controller.dart';

class PosHomePage extends ConsumerWidget {
  const PosHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final business = ref
        .watch(businessControllerProvider)
        .value
        ?.selectedBusiness;
    final pos = ref.watch(posControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(business?.name ?? 'POS'),
        actions: [
          IconButton(
            tooltip: 'Ganti usaha',
            onPressed: () {
              ref.read(businessControllerProvider.notifier).clearSelection();
              context.go(AppRoutes.businessSelector);
            },
            icon: const Icon(Icons.swap_horiz),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(posControllerProvider.notifier).refresh(),
        child: ResponsivePage(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: pos.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => AppStateView.error(
              title: 'POS gagal dimuat',
              message: '$error',
              actionLabel: 'Coba lagi',
              onAction: () =>
                  ref.read(posControllerProvider.notifier).refresh(),
            ),
            data: (data) => ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                Card(
                  color: data.isOpenToday
                      ? const Color(0xFFE5F5ED)
                      : const Color(0xFFF3F4F6),
                  child: SwitchListTile(
                    value: data.isOpenToday,
                    onChanged: (value) => _setOpen(context, ref, value),
                    secondary: Icon(
                      data.isOpenToday
                          ? Icons.storefront
                          : Icons.storefront_outlined,
                      color: data.isOpenToday
                          ? const Color(0xFF16794A)
                          : AppColors.secondaryText,
                    ),
                    title: Text(
                      data.isOpenToday
                          ? 'Hari ini berjualan'
                          : 'Hari ini tidak berjualan',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    subtitle: const Text(
                      'Ini menggantikan absensi yang rumit untuk usaha ini.',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _MetricCard(
                        label: 'Transaksi hari ini',
                        value: '${data.todaySales.length}',
                        icon: Icons.receipt_long_outlined,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MetricCard(
                        label: 'Omzet hari ini',
                        value: data.todayRevenue.toRupiah(),
                        icon: Icons.payments_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: data.isOpenToday
                      ? () => context.go(AppRoutes.posCashier)
                      : null,
                  icon: const Icon(Icons.point_of_sale),
                  label: const Text('Buka Kasir'),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Transaksi Terbaru',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
                ),
                const SizedBox(height: 8),
                if (data.todaySales.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'Belum ada penjualan hari ini.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.secondaryText),
                      ),
                    ),
                  )
                else
                  for (final sale in data.todaySales.take(8))
                    Card(
                      margin: const EdgeInsets.only(bottom: 7),
                      child: ListTile(
                        dense: true,
                        leading: const Icon(Icons.local_cafe_outlined),
                        title: Text(
                          sale.total.toRupiah(),
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        subtitle: Text(
                          '${sale.paymentMethod} · ${sale.createdAt.toIndonesianTime()}',
                        ),
                      ),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _setOpen(BuildContext context, WidgetRef ref, bool value) async {
    try {
      await ref.read(posControllerProvider.notifier).setOpenToday(value);
      if (context.mounted) {
        showAppSnackBar(
          value
              ? 'Usaha ditandai berjualan hari ini.'
              : 'Usaha ditandai tutup.',
        );
      }
    } catch (error) {
      if (context.mounted) {
        showAppSnackBar('Status jualan gagal disimpan: $error');
      }
    }
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primaryBlue),
          const SizedBox(height: 12),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
          ),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.secondaryText,
              fontSize: 12,
            ),
          ),
        ],
      ),
    ),
  );
}
