import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/extensions/currency_extensions.dart';
import '../../../core/extensions/date_time_extensions.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_bottom_sheet_body.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import '../../../core/widgets/responsive_page.dart';
import '../../../shared/preview_data.dart';

class OrdersPage extends ConsumerStatefulWidget {
  const OrdersPage({this.showMineOnly = false, super.key});

  final bool showMineOnly;

  @override
  ConsumerState<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends ConsumerState<OrdersPage> {
  String _query = '';
  PreviewOrderStatus? _status;

  @override
  Widget build(BuildContext context) {
    final allOrders = ref.watch(
      previewDataProvider.select((state) => state.orders),
    );
    final orders = allOrders.where((order) {
      final queryMatch =
          '${order.orderNumber} ${order.customerNameSnapshot} ${order.customerPhoneSnapshot}'
              .toLowerCase()
              .contains(_query.toLowerCase());
      final statusMatch = _status == null || order.orderStatus == _status;
      final mineMatch =
          !widget.showMineOnly ||
          order.assignedEmployeeId == 'employee-1' ||
          order.assignedEmployeeId.isEmpty;
      return queryMatch && statusMatch && mineMatch;
    }).toList();

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(widget.showMineOnly ? 'Pesanan Saya' : 'Pesanan'),
        actions: [
          IconButton(
            tooltip: 'Tambah pesanan',
            onPressed: () => context.go(AppRoutes.orderCreate),
            icon: const Icon(Icons.add_business_outlined),
          ),
        ],
      ),
      floatingActionButton: orders.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.go(AppRoutes.orderCreate),
              icon: const Icon(Icons.add),
              label: const Text('Pesanan'),
            ),
      body: ResponsivePage(
        padding: EdgeInsets.fromLTRB(16, 8, 16, orders.isEmpty ? 24 : 96),
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                hintText: 'Cari nomor pesanan atau pelanggan',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: const Text('Semua'),
                      selected: _status == null,
                      onSelected: (_) => setState(() => _status = null),
                    ),
                  ),
                  for (final status in PreviewOrderStatus.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(status.label),
                        selected: _status == status,
                        onSelected: (_) => setState(() => _status = status),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: orders.isEmpty
                  ? AppStateView.empty(
                      title: 'Pesanan belum ada',
                      message:
                          'Buat pesanan baru lewat aksi cepat. Data preview tersimpan selama aplikasi berjalan.',
                      actionLabel: 'Tambah pesanan',
                      onAction: () => context.go(AppRoutes.orderCreate),
                    )
                  : RefreshIndicator(
                      onRefresh: () async {},
                      child: ListView.separated(
                        padding: const EdgeInsets.only(bottom: 24),
                        itemCount: orders.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final order = orders[index];
                          return _OrderCard(
                            order: order,
                            onDetail: () => context.go('/orders/${order.id}'),
                            onPayment: order.remainingAmount <= 0
                                ? null
                                : () => _showPaymentSheet(order),
                            onStatus: () => _showStatusDialog(order),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPaymentSheet(PreviewOrder order) async {
    final amountController = TextEditingController(
      text: order.remainingAmount.toString(),
    );
    var method = 'Tunai';
    final formKey = GlobalKey<FormState>();
    final result = await showModalBottomSheet<_PaymentInput>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Form(
              key: formKey,
              child: AppBottomSheetBody(
                children: [
                  Text(
                    'Terima Pembayaran',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${order.orderNumber} - Sisa ${order.remainingAmount.toRupiah()}',
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Nominal'),
                    validator: (value) {
                      final amount = int.tryParse(value ?? '') ?? 0;
                      if (amount <= 0) {
                        return 'Nominal tidak boleh nol.';
                      }
                      if (amount > order.remainingAmount) {
                        return 'Nominal melebihi sisa tagihan.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: method,
                    items: const [
                      DropdownMenuItem(value: 'Tunai', child: Text('Tunai')),
                      DropdownMenuItem(
                        value: 'Transfer',
                        child: Text('Transfer'),
                      ),
                      DropdownMenuItem(value: 'QRIS', child: Text('QRIS')),
                    ],
                    onChanged: (value) =>
                        setModalState(() => method = value ?? method),
                    decoration: const InputDecoration(labelText: 'Metode'),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () {
                      if (!formKey.currentState!.validate()) {
                        return;
                      }
                      Navigator.of(context).pop(
                        _PaymentInput(
                          amount: int.parse(amountController.text),
                          method: method,
                        ),
                      );
                    },
                    icon: const Icon(Icons.point_of_sale),
                    label: const Text('Simpan Pembayaran'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    amountController.dispose();

    if (result == null || !mounted) {
      return;
    }
    try {
      ref
          .read(previewDataProvider.notifier)
          .addPayment(
            orderId: order.id,
            amount: result.amount,
            method: result.method,
          );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pembayaran masuk Buku Kas.')),
      );
    } on StateError catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _showStatusDialog(PreviewOrder order) async {
    final selected = await showDialog<PreviewOrderStatus>(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: const Text('Ubah Status Pesanan'),
          children: [
            for (final status in PreviewOrderStatus.values)
              SimpleDialogOption(
                onPressed: () => Navigator.of(context).pop(status),
                child: Text(status.label),
              ),
          ],
        );
      },
    );
    if (selected == null || selected == order.orderStatus) {
      return;
    }
    if (!mounted) {
      return;
    }
    final confirmed = await showConfirmationDialog(
      context,
      title: 'Ubah status?',
      message:
          '${order.orderNumber} akan diubah dari ${order.orderStatus.label} ke ${selected.label}.',
      confirmLabel: 'Ubah',
    );
    if (confirmed) {
      ref
          .read(previewDataProvider.notifier)
          .updateOrderStatus(order.id, selected);
    }
  }
}

class _PaymentInput {
  const _PaymentInput({required this.amount, required this.method});

  final int amount;
  final String method;
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.onDetail,
    required this.onStatus,
    this.onPayment,
  });

  final PreviewOrder order;
  final VoidCallback onDetail;
  final VoidCallback onStatus;
  final VoidCallback? onPayment;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    order.orderNumber,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _StatusPill(
                  label: order.orderStatus.label,
                  color: order.orderStatus == PreviewOrderStatus.ready
                      ? AppColors.success
                      : AppColors.primaryBlue,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              order.customerNameSnapshot,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              '${order.totalQuantity.toStringAsFixed(1)} ${order.items.first.unit} - ${order.totalPrice.toRupiah()} - Sisa ${order.remainingAmount.toRupiah()}',
              style: const TextStyle(color: AppColors.secondaryText),
            ),
            const SizedBox(height: 4),
            Text(
              'Estimasi ${order.dueAt.toIndonesianDate()} ${order.dueAt.toIndonesianTime()}',
              style: const TextStyle(color: AppColors.secondaryText),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Telepon siap dihubungkan ke url_launcher.',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.call_outlined),
                  label: const Text('Telepon'),
                ),
                OutlinedButton.icon(
                  onPressed: onDetail,
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Detail'),
                ),
                OutlinedButton.icon(
                  onPressed: onStatus,
                  icon: const Icon(Icons.sync_alt),
                  label: const Text('Status'),
                ),
                FilledButton.icon(
                  onPressed: onPayment,
                  icon: const Icon(Icons.payments_outlined),
                  label: const Text('Bayar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

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
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
