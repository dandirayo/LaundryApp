import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/extensions/currency_extensions.dart';
import '../../../core/extensions/date_time_extensions.dart';
import '../../../core/extensions/quantity_extensions.dart';
import '../../../core/errors/user_error_message.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/ui_action_queue.dart';
import '../../../core/widgets/app_bottom_sheet_body.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../core/widgets/responsive_page.dart';
import '../../../shared/preview_data.dart';
import '../../auth/domain/user_role.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../employees/presentation/employee_directory_controller.dart';
import '../../services/presentation/service_controller.dart';
import 'order_controller.dart';
import 'order_whatsapp.dart';
import 'receipt_preview_sheet.dart';

String _displayStatus(PreviewOrderStatus status) => switch (status) {
  PreviewOrderStatus.received ||
  PreviewOrderStatus.processing => 'Belum selesai',
  PreviewOrderStatus.ready => 'Pesanan selesai',
  PreviewOrderStatus.pickedUp => 'Sudah diambil',
  PreviewOrderStatus.cancelled => 'Dibatalkan',
};

class OrderDetailPage extends ConsumerWidget {
  const OrderDetailPage({required this.orderId, super.key});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(authControllerProvider).value?.user?.role;
    final isOwner = role == UserRole.owner;
    final data = ref.watch(
      previewDataProvider.select(
        (state) => (
          orders: state.orders,
          payments: state.payments,
          employees: state.employees,
          services: state.services,
          shopName: state.shopName,
          shopAddress: state.shopAddress,
        ),
      ),
    );
    final orders = ref.watch(orderControllerProvider).value ?? data.orders;
    final allPayments =
        ref.watch(orderPaymentControllerProvider).value ?? data.payments;
    final employees =
        ref.watch(employeeDirectoryProvider).value ?? data.employees;
    final services =
        ref.watch(serviceControllerProvider).value ?? data.services;
    final order = orders
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

    final payments = allPayments
        .where((payment) => payment.orderId == order.id)
        .toList();
    final canSendWhatsApp = orderHasReadyPickupWhatsApp(order);
    final employeeName =
        employees
            .where((employee) => employee.id == order.assignedEmployeeId)
            .map((employee) => employee.name)
            .firstOrNull ??
        'Belum ditugaskan';

    return Scaffold(
      appBar: AppBar(
        title: Text(order.orderNumber),
        actions: [
          if (isOwner) ...[
            IconButton(
              tooltip: 'Edit pesanan',
              onPressed: () =>
                  _showEditOrderSheet(context, ref, order, employees, services),
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: 'Hapus pesanan',
              onPressed: () => _confirmDeleteOrder(context, ref, order),
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ],
      ),
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
                    Text(
                      'Diterima oleh: ${order.receivedByName.trim().isEmpty ? 'Belum tercatat' : order.receivedByName}',
                    ),
                    const SizedBox(height: 6),
                    Text('Penanggung jawab: $employeeName'),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _Pill(
                          _displayStatus(order.orderStatus),
                          order.orderStatus == PreviewOrderStatus.ready ||
                                  order.orderStatus ==
                                      PreviewOrderStatus.pickedUp
                              ? AppColors.success
                              : AppColors.primaryBlue,
                        ),
                        _Pill(order.paymentStatus.label, AppColors.success),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            _OrderProgressCard(status: order.orderStatus),
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
                          '${formatQuantityForUnit(item.quantity, item.unit)} x ${item.price.toRupiah()}',
                        ),
                        trailing: Text(
                          item.total.toRupiah(),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    const Divider(),
                    if (order.roundingAdjustment != 0) ...[
                      _AmountRow(label: 'Subtotal', amount: order.itemSubtotal),
                      _AmountRow(
                        label: 'Pembulatan',
                        amount: order.roundingAdjustment,
                      ),
                    ],
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
                          trailing: isOwner
                              ? IconButton(
                                  key: ValueKey(
                                    'edit-payment-date-${payment.id}',
                                  ),
                                  tooltip: 'Edit tanggal pembayaran',
                                  onPressed: () =>
                                      _editPaymentDate(context, ref, payment),
                                  icon: const Icon(
                                    Icons.edit_calendar_outlined,
                                  ),
                                )
                              : null,
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
                  onPressed: canSendWhatsApp
                      ? () async {
                          final opened = await launchReadyPickupWhatsApp(order);
                          if (!context.mounted) {
                            return;
                          }
                          showAppSnackBar(
                            opened
                                ? 'WhatsApp dibuka dengan template siap ambil.'
                                : 'WhatsApp tidak bisa dibuka di perangkat ini.',
                          );
                        }
                      : null,
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
                    employeeName: order.receivedByName.trim().isEmpty
                        ? employeeName
                        : order.receivedByName,
                    copies: order.orderStatus == PreviewOrderStatus.pickedUp
                        ? ReceiptCopyType.values
                        : const [
                            ReceiptCopyType.customer,
                            ReceiptCopyType.laundryLabel,
                          ],
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

  Future<void> _editPaymentDate(
    BuildContext context,
    WidgetRef ref,
    PreviewPayment payment,
  ) async {
    final now = DateTime.now();
    final initialDate = payment.paidAt.isAfter(now) ? now : payment.paidAt;
    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: now,
      helpText: 'Pilih tanggal pembayaran',
      cancelText: 'Batal',
      confirmText: 'Lanjut',
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(payment.paidAt),
      helpText: 'Pilih jam pembayaran',
      cancelText: 'Batal',
      confirmText: 'Simpan',
    );
    if (time == null || !context.mounted) return;
    final paidAt = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    if (paidAt.isAfter(DateTime.now())) {
      showAppSnackBar('Tanggal pembayaran tidak boleh di masa depan.');
      return;
    }
    try {
      await ref
          .read(orderPaymentControllerProvider.notifier)
          .updatePaidAt(paymentId: payment.id, paidAt: paidAt);
      if (context.mounted) {
        showAppSnackBar('Tanggal pembayaran berhasil diperbarui.');
      }
    } catch (error) {
      if (!context.mounted) return;
      showAppSnackBar(
        userErrorMessage(
          error,
          fallback: 'Tanggal pembayaran belum dapat diperbarui.',
        ),
      );
    }
  }

  Future<void> _showEditOrderSheet(
    BuildContext context,
    WidgetRef ref,
    PreviewOrder order,
    List<PreviewEmployee> employees,
    List<PreviewService> services,
  ) async {
    var status = order.orderStatus == PreviewOrderStatus.processing
        ? PreviewOrderStatus.received
        : order.orderStatus;
    var employeeId =
        employees.any((employee) => employee.id == order.assignedEmployeeId)
        ? order.assignedEmployeeId
        : employees.firstOrNull?.id ?? '';
    final kiloServices = services
        .where(
          (service) =>
              service.isActive && service.unit.trim().toUpperCase() == 'KG',
        )
        .toList();
    final kiloItems = order.items
        .where((item) => item.unit.trim().toUpperCase() == 'KG')
        .toList();
    final selectedServices = <String, String?>{
      for (final item in kiloItems)
        item.id: kiloServices.any((service) => service.id == item.serviceId)
            ? item.serviceId
            : null,
    };
    final noteController = TextEditingController(text: order.note);
    final result = await showAppModalBottomSheet<_OrderEditInput>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AppBottomSheetBody(
              children: [
                Text(
                  'Edit Pesanan',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text('${order.orderNumber} - ${order.customerNameSnapshot}'),
                const SizedBox(height: 16),
                DropdownButtonFormField<PreviewOrderStatus>(
                  initialValue: status,
                  items: [
                    for (final item in const [
                      PreviewOrderStatus.received,
                      PreviewOrderStatus.ready,
                      PreviewOrderStatus.pickedUp,
                      PreviewOrderStatus.cancelled,
                    ])
                      DropdownMenuItem(
                        value: item,
                        child: Text(_displayStatus(item)),
                      ),
                  ],
                  onChanged: (value) =>
                      setModalState(() => status = value ?? status),
                  decoration: const InputDecoration(labelText: 'Status'),
                ),
                const SizedBox(height: 12),
                if (kiloItems.isNotEmpty) ...[
                  Text(
                    'Layanan Kiloan',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Berat tetap sama. Harga, total, dan estimasi akan dihitung ulang.',
                  ),
                  const SizedBox(height: 12),
                  for (final item in kiloItems) ...[
                    DropdownButtonFormField<String>(
                      key: ValueKey('kilo-service-${item.id}'),
                      initialValue: selectedServices[item.id],
                      isExpanded: true,
                      items: [
                        for (final service in kiloServices)
                          DropdownMenuItem(
                            value: service.id,
                            child: Text(
                              '${service.name} · ${service.price.toRupiah()}/KG',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: kiloServices.isEmpty
                          ? null
                          : (value) => setModalState(
                              () => selectedServices[item.id] = value,
                            ),
                      decoration: InputDecoration(
                        labelText:
                            '${formatQuantityForUnit(item.quantity, item.unit)} · ${item.serviceNameSnapshot}',
                        helperText: kiloServices.isEmpty
                            ? 'Belum ada layanan kiloan aktif.'
                            : null,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
                DropdownButtonFormField<String>(
                  initialValue: employeeId.isEmpty ? null : employeeId,
                  items: [
                    for (final employee in employees)
                      DropdownMenuItem(
                        value: employee.id,
                        child: Text(employee.name),
                      ),
                  ],
                  onChanged: employees.isEmpty
                      ? null
                      : (value) => setModalState(
                          () => employeeId = value ?? employeeId,
                        ),
                  decoration: InputDecoration(
                    labelText: 'Petugas',
                    helperText: employees.isEmpty
                        ? 'Belum ada karyawan aktif.'
                        : null,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteController,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Catatan'),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop(
                      _OrderEditInput(
                        status: status,
                        employeeId: employeeId,
                        note: noteController.text,
                        serviceReplacements: {
                          for (final item in kiloItems)
                            if (selectedServices[item.id] case final serviceId?
                                when serviceId != item.serviceId)
                              item.id: serviceId,
                        },
                      ),
                    );
                  },
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Simpan Perubahan'),
                ),
              ],
            );
          },
        );
      },
    );
    noteController.dispose();
    if (result == null || !context.mounted) {
      return;
    }
    await waitForTransientUiDismissal();
    if (!context.mounted) {
      return;
    }
    try {
      await ref
          .read(orderControllerProvider.notifier)
          .updateOrderDetails(
            orderId: order.id,
            status: result.status,
            employeeId: result.employeeId,
            note: result.note,
            serviceReplacements: result.serviceReplacements,
          );
      showAppSnackBar('Pesanan berhasil diperbarui.');
    } catch (error) {
      final message = error is StateError
          ? error.message
          : userErrorMessage(
              error,
              fallback: 'Pesanan belum dapat diperbarui. Coba lagi.',
            );
      showAppSnackBar(message);
    }
  }

  Future<void> _confirmDeleteOrder(
    BuildContext context,
    WidgetRef ref,
    PreviewOrder order,
  ) async {
    final confirmed = await _showDeleteCountdownDialog(context, order);
    if (!confirmed || !context.mounted) {
      return;
    }
    try {
      await ref.read(orderControllerProvider.notifier).delete(order.id);
      if (!context.mounted) {
        return;
      }
      showAppSnackBar('${order.orderNumber} dihapus.');
      context.go('/orders');
    } catch (error) {
      showAppSnackBar('Gagal menghapus pesanan: $error');
    }
  }

  Future<bool> _showDeleteCountdownDialog(
    BuildContext context,
    PreviewOrder order,
  ) async {
    var remaining = 5;
    Timer? timer;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            timer ??= Timer.periodic(const Duration(seconds: 1), (timer) {
              if (remaining <= 1) {
                timer.cancel();
                setDialogState(() => remaining = 0);
                return;
              }
              setDialogState(() => remaining -= 1);
            });
            return AlertDialog(
              title: const Text('Hapus pesanan?'),
              content: Text(
                'Pesanan ${order.orderNumber} akan dihapus beserta pembayaran dan transaksi kas terkait. Tombol hapus aktif dalam $remaining detik.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Batal'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.error,
                  ),
                  onPressed: remaining > 0
                      ? null
                      : () => Navigator.of(dialogContext).pop(true),
                  child: Text(remaining > 0 ? 'Hapus ($remaining)' : 'Hapus'),
                ),
              ],
            );
          },
        );
      },
    );
    timer?.cancel();
    await waitForTransientUiDismissal();
    return result ?? false;
  }
}

class _OrderEditInput {
  const _OrderEditInput({
    required this.status,
    required this.employeeId,
    required this.note,
    required this.serviceReplacements,
  });

  final PreviewOrderStatus status;
  final String employeeId;
  final String note;
  final Map<String, String> serviceReplacements;
}

class _OrderProgressCard extends StatelessWidget {
  const _OrderProgressCard({required this.status});

  final PreviewOrderStatus status;

  @override
  Widget build(BuildContext context) {
    if (status == PreviewOrderStatus.cancelled) {
      return Card(
        color: AppColors.error.withValues(alpha: 0.08),
        child: const ListTile(
          leading: Icon(Icons.cancel_outlined, color: AppColors.error),
          title: Text(
            'Pesanan dibatalkan',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text('Pesanan ini tidak dilanjutkan ke proses berikutnya.'),
        ),
      );
    }
    final current = switch (status) {
      PreviewOrderStatus.received => 0,
      PreviewOrderStatus.processing => 1,
      PreviewOrderStatus.ready => 2,
      PreviewOrderStatus.pickedUp => 3,
      PreviewOrderStatus.cancelled => 0,
    };
    const labels = ['Diterima', 'Diproses', 'Siap ambil', 'Diambil'];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Progres Pesanan',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                for (var index = 0; index < labels.length; index++) ...[
                  Expanded(
                    child: Column(
                      children: [
                        Icon(
                          index <= current
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color: index <= current
                              ? AppColors.success
                              : AppColors.outline,
                          size: 22,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          labels[index],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: index == current
                                ? FontWeight.w900
                                : FontWeight.w600,
                            color: index <= current
                                ? AppColors.mainText
                                : AppColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (index < labels.length - 1)
                    Expanded(
                      child: Divider(
                        color: index < current
                            ? AppColors.success
                            : AppColors.outline,
                        thickness: 2,
                      ),
                    ),
                ],
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
