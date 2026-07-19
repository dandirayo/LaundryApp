import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/extensions/currency_extensions.dart';
import '../../../core/extensions/date_time_extensions.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/ui_action_queue.dart';
import '../../../core/widgets/app_bottom_sheet_body.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import '../../../core/widgets/responsive_page.dart';
import '../../../shared/preview_data.dart';
import 'order_whatsapp.dart';

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
    final data = ref.watch(
      previewDataProvider.select(
        (state) => (orders: state.orders, employees: state.employees),
      ),
    );
    final allOrders = data.orders;
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
                          final nextStatus = _nextStatusFor(order);
                          return _OrderCard(
                            order: order,
                            employeeName: _employeeNameFor(
                              data.employees,
                              order.assignedEmployeeId,
                            ),
                            onDetail: () => context.go('/orders/${order.id}'),
                            onWhatsApp: () => _sendReadyPickupWhatsApp(order),
                            onPayment: order.remainingAmount <= 0
                                ? null
                                : () => _showPaymentSheet(order),
                            statusActionLabel: _statusActionLabel(order),
                            onStatus: nextStatus == null
                                ? null
                                : () => _confirmStatusChange(order, nextStatus),
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
    final result = await showAppModalBottomSheet<_PaymentInput>(
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
    await waitForTransientUiDismissal();
    if (!mounted) {
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
      showAppSnackBar('Pembayaran masuk Buku Kas.');
    } on StateError catch (error) {
      if (!mounted) {
        return;
      }
      showAppSnackBar(error.message);
    }
  }

  Future<void> _confirmStatusChange(
    PreviewOrder order,
    PreviewOrderStatus selected,
  ) async {
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
      await waitForTransientUiDismissal();
      if (!mounted) {
        return;
      }
      ref
          .read(previewDataProvider.notifier)
          .updateOrderStatus(order.id, selected);
      if (!mounted) {
        return;
      }
      showAppSnackBar('Status menjadi ${selected.label}.');
    }
  }

  Future<void> _sendReadyPickupWhatsApp(PreviewOrder order) async {
    final opened = await launchReadyPickupWhatsApp(order);
    if (!mounted) {
      return;
    }
    showAppSnackBar(
      opened
          ? 'WhatsApp dibuka dengan template siap ambil.'
          : 'WhatsApp tidak bisa dibuka di perangkat ini.',
    );
  }

  PreviewOrderStatus? _nextStatusFor(PreviewOrder order) {
    return switch (order.orderStatus) {
      PreviewOrderStatus.received => PreviewOrderStatus.processing,
      PreviewOrderStatus.processing => PreviewOrderStatus.ready,
      PreviewOrderStatus.ready => PreviewOrderStatus.pickedUp,
      PreviewOrderStatus.pickedUp || PreviewOrderStatus.cancelled => null,
    };
  }

  String? _statusActionLabel(PreviewOrder order) {
    return switch (order.orderStatus) {
      PreviewOrderStatus.received => 'Mulai Proses',
      PreviewOrderStatus.processing => 'Tandai Selesai',
      PreviewOrderStatus.ready => 'Sudah Diambil',
      PreviewOrderStatus.pickedUp => 'Sudah Selesai',
      PreviewOrderStatus.cancelled => 'Dibatalkan',
    };
  }

  String _employeeNameFor(List<PreviewEmployee> employees, String employeeId) {
    return employees
            .where((employee) => employee.id == employeeId)
            .map((employee) => employee.name)
            .firstOrNull ??
        'Belum ditugaskan';
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
    required this.employeeName,
    required this.onDetail,
    required this.onWhatsApp,
    required this.onStatus,
    this.statusActionLabel,
    this.onPayment,
  });

  final PreviewOrder order;
  final String employeeName;
  final VoidCallback onDetail;
  final VoidCallback onWhatsApp;
  final VoidCallback? onStatus;
  final String? statusActionLabel;
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
            const SizedBox(height: 4),
            Text(
              'Diproses oleh $employeeName',
              style: const TextStyle(
                color: AppColors.secondaryText,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: onWhatsApp,
                  icon: const Icon(Icons.chat_outlined),
                  label: const Text('WhatsApp'),
                ),
                OutlinedButton.icon(
                  onPressed: onDetail,
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Detail'),
                ),
                OutlinedButton.icon(
                  onPressed: onStatus,
                  icon: Icon(_statusActionIcon(order.orderStatus)),
                  label: Text(statusActionLabel ?? 'Status Selesai'),
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

  IconData _statusActionIcon(PreviewOrderStatus status) {
    return switch (status) {
      PreviewOrderStatus.received => Icons.play_arrow_outlined,
      PreviewOrderStatus.processing => Icons.done_all_outlined,
      PreviewOrderStatus.ready => Icons.shopping_bag_outlined,
      PreviewOrderStatus.pickedUp => Icons.task_alt,
      PreviewOrderStatus.cancelled => Icons.block,
    };
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
