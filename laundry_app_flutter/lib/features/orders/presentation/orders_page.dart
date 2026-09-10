import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/extensions/currency_extensions.dart';
import '../../../core/extensions/date_time_extensions.dart';
import '../../../core/extensions/quantity_extensions.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/ui_action_queue.dart';
import '../../../core/widgets/app_bottom_sheet_body.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import '../../../core/widgets/responsive_page.dart';
import '../../../shared/preview_data.dart';
import '../../employees/presentation/employee_directory_controller.dart';
import 'order_controller.dart';
import 'order_whatsapp.dart';
import 'receipt_preview_sheet.dart';

enum _OrderFilter { all, active, completed }

class OrdersPage extends ConsumerStatefulWidget {
  const OrdersPage({super.key});

  @override
  ConsumerState<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends ConsumerState<OrdersPage>
    with WidgetsBindingObserver {
  String _query = '';
  _OrderFilter _filter = _OrderFilter.all;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshOnlineData());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshOnlineData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = ref.watch(
      previewDataProvider.select(
        (state) => (orders: state.orders, employees: state.employees),
      ),
    );
    final onlineOrders = ref.watch(orderControllerProvider);
    final onlineEmployees = ref.watch(employeeDirectoryProvider).value;
    final data = (
      orders: onlineOrders.value ?? preview.orders,
      employees: onlineEmployees ?? preview.employees,
    );
    final allOrders = data.orders;
    final strings = ref.strings;
    final orders = allOrders.where((order) {
      final queryMatch =
          '${order.orderNumber} ${order.customerNameSnapshot} ${order.customerPhoneSnapshot}'
              .toLowerCase()
              .contains(_query.toLowerCase());
      final statusMatch = switch (_filter) {
        _OrderFilter.all => true,
        _OrderFilter.active =>
          order.orderStatus == PreviewOrderStatus.received ||
              order.orderStatus == PreviewOrderStatus.processing,
        _OrderFilter.completed =>
          order.orderStatus == PreviewOrderStatus.ready ||
              order.orderStatus == PreviewOrderStatus.pickedUp,
      };
      return queryMatch && statusMatch;
    }).toList();

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(strings.orders),
        actions: [
          IconButton(
            tooltip: strings.isEnglish ? 'Sync orders' : 'Sinkronkan pesanan',
            onPressed: _refreshOnlineData,
            icon: const Icon(Icons.sync),
          ),
          IconButton(
            tooltip: strings.addOrder,
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
              label: Text(strings.orders),
            ),
      body: ResponsivePage(
        padding: EdgeInsets.fromLTRB(16, 8, 16, orders.isEmpty ? 24 : 96),
        child: Column(
          children: [
            TextField(
              decoration: InputDecoration(
                hintText: strings.searchOrders,
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final filter in _OrderFilter.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(switch (filter) {
                          _OrderFilter.all => strings.all,
                          _OrderFilter.active => 'Belum selesai',
                          _OrderFilter.completed => 'Selesai',
                        }, style: _filterChipTextStyle(_filter == filter)),
                        selected: _filter == filter,
                        selectedColor: AppColors.lightGold,
                        backgroundColor: AppColors.surface,
                        checkmarkColor: AppColors.primaryBlue,
                        side: const BorderSide(color: AppColors.outline),
                        onSelected: (_) => setState(() => _filter = filter),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (onlineOrders.hasError) ...[
              Card(
                color: AppColors.error.withValues(alpha: 0.08),
                child: ListTile(
                  leading: const Icon(
                    Icons.sync_problem,
                    color: AppColors.error,
                  ),
                  title: const Text('Pesanan belum tersinkron'),
                  subtitle: const Text(
                    'Data terakhir masih ditampilkan. Tekan Coba Lagi.',
                  ),
                  trailing: TextButton(
                    onPressed: _refreshOnlineData,
                    child: const Text('Coba Lagi'),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (onlineOrders.isLoading && !onlineOrders.hasValue)
              const LinearProgressIndicator(),
            Expanded(
              child: orders.isEmpty
                  ? RefreshIndicator(
                      onRefresh: _refresh,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          const SizedBox(height: 80),
                          AppStateView.empty(
                            title: strings.noOrdersTitle,
                            message: strings.noOrdersMessage,
                            actionLabel: strings.addOrder,
                            onAction: () => context.go(AppRoutes.orderCreate),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _refresh,
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
                            strings: strings,
                            onDetail: () => context.go('/orders/${order.id}'),
                            onWhatsApp: orderHasReadyPickupWhatsApp(order)
                                ? () => _sendReadyPickupWhatsApp(order)
                                : null,
                            onPayment: order.remainingAmount <= 0
                                ? null
                                : () => _showPaymentSheet(order),
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

  Future<void> _refreshOnlineData() async {
    if (!mounted) return;
    await Future.wait([
      ref.read(orderControllerProvider.notifier).refresh(),
      ref.read(employeeDirectoryProvider.notifier).refresh(),
    ]);
  }

  Future<void> _refresh() async {
    await _refreshOnlineData();
  }

  Future<void> _showPaymentSheet(PreviewOrder order) async {
    final strings = ref.read(appLanguageProvider) == AppLanguage.en
        ? const AppStrings(AppLanguage.en)
        : const AppStrings(AppLanguage.id);
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
                    strings.receivePayment,
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
                    decoration: InputDecoration(labelText: strings.amount),
                    validator: (value) {
                      final amount = int.tryParse(value ?? '') ?? 0;
                      if (amount <= 0) {
                        return strings.isEnglish
                            ? 'Amount cannot be zero.'
                            : 'Nominal tidak boleh nol.';
                      }
                      if (amount > order.remainingAmount) {
                        return strings.isEnglish
                            ? 'Amount exceeds remaining balance.'
                            : 'Nominal melebihi sisa tagihan.';
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
                    decoration: InputDecoration(labelText: strings.method),
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
                    label: Text(strings.savePayment),
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
      await ref
          .read(orderControllerProvider.notifier)
          .addPayment(
            orderId: order.id,
            amount: result.amount,
            method: result.method,
          );
      if (!mounted) {
        return;
      }
      showAppSnackBar(
        ref.read(appLanguageProvider) == AppLanguage.en
            ? const AppStrings(AppLanguage.en).paymentSaved
            : const AppStrings(AppLanguage.id).paymentSaved,
      );
      final updated = ref
          .read(orderControllerProvider)
          .value
          ?.where((entry) => entry.id == order.id)
          .firstOrNull;
      if (updated != null && updated.remainingAmount == 0 && mounted) {
        final data = ref.read(previewDataProvider);
        await showReceiptPreviewSheet(
          context: context,
          order: updated,
          payments: data.payments
              .where((payment) => payment.orderId == updated.id)
              .toList(),
          shopName: data.shopName,
          shopAddress: data.shopAddress,
          employeeName: updated.receivedByName.trim().isEmpty
              ? _employeeNameFor(data.employees, updated.assignedEmployeeId)
              : updated.receivedByName,
        );
      }
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
    if (selected == PreviewOrderStatus.pickedUp && order.remainingAmount > 0) {
      final payNow = await showConfirmationDialog(
        context,
        title: 'Bayar dulu',
        message:
            '${order.orderNumber} masih punya sisa tagihan ${order.remainingAmount.toRupiah()}. Pesanan belum boleh ditandai diambil sebelum lunas.',
        confirmLabel: 'Bayar Sekarang',
        cancelLabel: 'Nanti',
      );
      if (!payNow || !mounted) {
        return;
      }
      await _showPaymentSheet(order);
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
      await ref
          .read(orderControllerProvider.notifier)
          .updateStatus(order.id, selected);
      if (!mounted) {
        return;
      }
      if (selected == PreviewOrderStatus.ready) {
        await _sendReadyPickupWhatsApp(
          order.copyWith(orderStatus: PreviewOrderStatus.ready),
        );
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
          ? (ref.read(appLanguageProvider) == AppLanguage.en
                ? const AppStrings(AppLanguage.en).whatsappReady
                : const AppStrings(AppLanguage.id).whatsappReady)
          : (ref.read(appLanguageProvider) == AppLanguage.en
                ? const AppStrings(AppLanguage.en).whatsappUnavailable
                : const AppStrings(AppLanguage.id).whatsappUnavailable),
    );
  }

  PreviewOrderStatus? _nextStatusFor(PreviewOrder order) {
    return switch (order.orderStatus) {
      PreviewOrderStatus.received ||
      PreviewOrderStatus.processing => PreviewOrderStatus.ready,
      PreviewOrderStatus.ready ||
      PreviewOrderStatus.pickedUp ||
      PreviewOrderStatus.cancelled => null,
    };
  }

  String _employeeNameFor(List<PreviewEmployee> employees, String employeeId) {
    return employees
            .where((employee) => employee.id == employeeId)
            .map((employee) => employee.name)
            .firstOrNull ??
        (ref.read(appLanguageProvider) == AppLanguage.en
            ? const AppStrings(AppLanguage.en).unassigned
            : const AppStrings(AppLanguage.id).unassigned);
  }

  TextStyle _filterChipTextStyle(bool selected) {
    return TextStyle(
      color: selected ? AppColors.primaryBlue : AppColors.secondaryText,
      fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
    );
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
    required this.strings,
    required this.onDetail,
    required this.onStatus,
    this.onWhatsApp,
    this.onPayment,
  });

  final PreviewOrder order;
  final String employeeName;
  final AppStrings strings;
  final VoidCallback onDetail;
  final VoidCallback? onWhatsApp;
  final VoidCallback? onStatus;
  final VoidCallback? onPayment;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onDetail,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          order.orderNumber,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _StatusPill(
                        label: _statusLabel(order.orderStatus),
                        color: _statusColor(order.orderStatus),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    order.customerNameSnapshot,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Diterima oleh: ${order.receivedByName.trim().isEmpty ? 'Belum tercatat' : order.receivedByName}',
                    style: const TextStyle(
                      color: AppColors.secondaryText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_itemSummary(order)} · ${order.totalPrice.toRupiah()} · Sisa ${order.remainingAmount.toRupiah()}',
                    style: const TextStyle(color: AppColors.secondaryText),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Layanan: ${order.items.map((item) => item.serviceNameSnapshot).toSet().join(', ')}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.secondaryText),
                  ),
                  if (order.note.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Catatan: ${order.note.trim()}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    'Estimasi ${order.dueAt.toIndonesianDate()} ${order.dueAt.toIndonesianTime()} · Penanggung jawab: $employeeName',
                    style: const TextStyle(
                      color: AppColors.secondaryText,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'Ketuk kartu untuk detail',
                      style: TextStyle(
                        color: AppColors.primaryBlue,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (onWhatsApp != null || onStatus != null || onPayment != null) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (onStatus != null)
                    FilledButton.icon(
                      onPressed: onStatus,
                      icon: const Icon(Icons.task_alt),
                      label: const Text('Pesanan Selesai'),
                    ),
                  if (onWhatsApp != null)
                    OutlinedButton.icon(
                      onPressed: onWhatsApp,
                      icon: const Icon(Icons.chat_outlined),
                      label: const Text('WhatsApp Siap Diambil'),
                    ),
                  if (onPayment != null)
                    FilledButton.tonalIcon(
                      onPressed: onPayment,
                      icon: const Icon(Icons.payments_outlined),
                      label: Text(strings.receivePayment),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _statusLabel(PreviewOrderStatus status) {
    return switch (status) {
      PreviewOrderStatus.received ||
      PreviewOrderStatus.processing => 'Belum selesai',
      PreviewOrderStatus.ready ||
      PreviewOrderStatus.pickedUp => 'Pesanan selesai',
      PreviewOrderStatus.cancelled => strings.cancelled,
    };
  }

  Color _statusColor(PreviewOrderStatus status) => switch (status) {
    PreviewOrderStatus.ready ||
    PreviewOrderStatus.pickedUp => AppColors.success,
    PreviewOrderStatus.cancelled => AppColors.error,
    _ => AppColors.primaryBlue,
  };

  String _itemSummary(PreviewOrder order) {
    final units = <String, double>{};
    for (final item in order.items) {
      units[item.unit] = (units[item.unit] ?? 0) + item.quantity;
    }
    return units.entries
        .map((entry) => formatQuantityForUnit(entry.value, entry.key))
        .join(' + ');
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
