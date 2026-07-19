import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/extensions/currency_extensions.dart';
import '../../../core/extensions/date_time_extensions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../core/widgets/responsive_page.dart';
import '../../../shared/preview_data.dart';
import 'order_whatsapp.dart';
import 'receipt_preview_sheet.dart';

class OrderDetailPage extends ConsumerWidget {
  const OrderDetailPage({required this.orderId, super.key});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(
      previewDataProvider.select(
        (state) => (
          orders: state.orders,
          payments: state.payments,
          employees: state.employees,
          shopName: state.shopName,
          shopAddress: state.shopAddress,
        ),
      ),
    );
    final order = data.orders
        .where((entry) => entry.id == orderId)
        .cast<PreviewOrder?>()
        .firstOrNull;

    if (order == null) {
      return const Scaffold(
        body: AppStateView.error(
          title: 'Pesanan tidak ditemukan',
          message: 'Data pesanan tidak ada di sesi preview ini.',
        ),
      );
    }

    final payments = data.payments
        .where((payment) => payment.orderId == order.id)
        .toList();
    final employeeName =
        data.employees
            .where((employee) => employee.id == order.assignedEmployeeId)
            .map((employee) => employee.name)
            .firstOrNull ??
        'Belum ditugaskan';

    return Scaffold(
      appBar: AppBar(title: Text(order.orderNumber)),
      body: ResponsivePage(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: ListView(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.customerNameSnapshot,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(order.customerPhoneSnapshot),
                    const SizedBox(height: 6),
                    Text('Diproses oleh $employeeName'),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _Pill(order.orderStatus.label, AppColors.primaryBlue),
                        _Pill(order.paymentStatus.label, AppColors.success),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Item Pesanan',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    for (final item in order.items)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(item.serviceNameSnapshot),
                        subtitle: Text(
                          '${item.quantity.toStringAsFixed(1)} ${item.unit} x ${item.price.toRupiah()}',
                        ),
                        trailing: Text(
                          item.total.toRupiah(),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    const Divider(),
                    _AmountRow(label: 'Total', amount: order.totalPrice),
                    _AmountRow(label: 'Dibayar', amount: order.paidAmount),
                    _AmountRow(label: 'Sisa', amount: order.remainingAmount),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Waktu dan Catatan',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Masuk: ${order.receivedAt.toIndonesianDate()} ${order.receivedAt.toIndonesianTime()}',
                    ),
                    Text(
                      'Estimasi: ${order.dueAt.toIndonesianDate()} ${order.dueAt.toIndonesianTime()}',
                    ),
                    if (order.note.isNotEmpty) Text('Catatan: ${order.note}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Riwayat Pembayaran',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    if (payments.isEmpty)
                      const Text('Belum ada pembayaran.')
                    else
                      for (final payment in payments)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.payments_outlined),
                          title: Text(payment.amount.toRupiah()),
                          subtitle: Text(
                            '${payment.method} - ${payment.paidAt.toIndonesianDate()} ${payment.paidAt.toIndonesianTime()}',
                          ),
                        ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    final opened = await launchReadyPickupWhatsApp(order);
                    if (!context.mounted) {
                      return;
                    }
                    showAppSnackBar(
                      opened
                          ? 'WhatsApp dibuka dengan template siap ambil.'
                          : 'WhatsApp tidak bisa dibuka di perangkat ini.',
                    );
                  },
                  icon: const Icon(Icons.chat_outlined),
                  label: const Text('WhatsApp Siap Ambil'),
                ),
                OutlinedButton.icon(
                  onPressed: () => showReceiptPreviewSheet(
                    context: context,
                    order: order,
                    payments: payments,
                    shopName: data.shopName,
                    shopAddress: data.shopAddress,
                    employeeName: employeeName,
                  ),
                  icon: const Icon(Icons.print_outlined),
                  label: const Text('Preview Struk'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.label, this.color);

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          label,
          style: TextStyle(color: color, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({required this.label, required this.amount});

  final String label;
  final int amount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            amount.toRupiah(),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
