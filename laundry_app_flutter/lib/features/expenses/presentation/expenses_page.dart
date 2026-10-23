import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/user_error_message.dart';
import '../../../core/extensions/currency_extensions.dart';
import '../../../core/extensions/date_time_extensions.dart';
import '../../../core/router/app_navigation.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/ui_action_queue.dart';
import '../../../core/widgets/app_bottom_sheet_body.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../core/widgets/responsive_page.dart';
import '../../../shared/preview_data.dart';
import '../../auth/domain/user_role.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../cashbook/presentation/cashbook_controller.dart';
import '../../inventory/presentation/inventory_controller.dart';
import 'expense_controller.dart';

class ExpensesPage extends ConsumerStatefulWidget {
  const ExpensesPage({super.key});

  @override
  ConsumerState<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends ConsumerState<ExpensesPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this)..addListener(_rebuild);
  }

  @override
  void dispose() {
    _tabs.removeListener(_rebuild);
    _tabs.dispose();
    super.dispose();
  }

  void _rebuild() {
    if (!_tabs.indexIsChanging && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final preview = ref.watch(previewDataProvider);
    final expenses =
        ref.watch(expenseControllerProvider).value?.expenses ??
        preview.expenses;
    final inventory =
        ref.watch(inventoryControllerProvider).value?.items ??
        preview.inventory;
    final procurement = expenses
        .where((item) => item.category == 'Stok')
        .toList();
    final operational = expenses
        .where((item) => item.category != 'Stok')
        .toList();
    final isOwner =
        ref.watch(authControllerProvider).value?.user?.role == UserRole.owner;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stok & Pengeluaran'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Pengadaan'),
            Tab(text: 'Pengeluaran'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Sinkronkan data',
            onPressed: () async {
              await Future.wait([
                ref.read(expenseControllerProvider.notifier).refresh(),
                ref.read(inventoryControllerProvider.notifier).refresh(),
              ]);
            },
            icon: const Icon(Icons.sync),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _tabs.index == 0
            ? _showProcurementSheet(context)
            : _showExpenseSheet(context),
        icon: const Icon(Icons.add),
        label: Text(_tabs.index == 0 ? 'Beli Stok' : 'Pengeluaran'),
      ),
      body: ResponsivePage(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        child: TabBarView(
          controller: _tabs,
          children: [
            _ProcurementView(
              stock: inventory.where((item) => item.isActive).toList(),
              procurement: procurement,
              isOwner: isOwner,
              onManageStock: () =>
                  AppNavigation.open(context, AppRoutes.inventory),
              onUseStock: (item) => _showUsageSheet(context, item),
            ),
            _ExpenseList(
              items: operational,
              emptyTitle: 'Pengeluaran belum ada',
              emptyMessage: 'Catat biaya operasional selain pengadaan stok.',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showProcurementSheet(BuildContext context) async {
    final stock = ref.read(inventoryControllerProvider).value?.items ??
        ref.read(previewDataProvider).inventory;
    final items = stock.where((item) => item.isActive).toList();
    if (items.isEmpty) {
      showAppSnackBar('Belum ada barang Live Stock. Minta Owner menambahkan barang dulu.');
      return;
    }
    var item = items.first;
    var method = 'Tunai';
    final quantity = TextEditingController();
    final amount = TextEditingController();
    final note = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final result = await showAppModalBottomSheet<_InventoryPurchaseInput>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Form(
          key: formKey,
          child: AppBottomSheetBody(
            children: [
              const Text(
                'Beli Stok',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
              ),
              const SizedBox(height: 6),
              const Text('Satu kali simpan akan menambah Live Stock dan mencatat uang keluar di Buku Kas.'),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: item.id,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Barang / varian'),
                items: [
                  for (final row in items)
                    DropdownMenuItem(value: row.id, child: Text('${row.name} (${row.unit})')),
                ],
                onChanged: (id) => setModalState(() =>
                    item = items.firstWhere((row) => row.id == id)),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: quantity,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: 'Jumlah dibeli (${item.unit})'),
                validator: (value) => (double.tryParse((value ?? '').replaceAll(',', '.')) ?? 0) <= 0
                    ? 'Jumlah harus lebih dari nol.' : null,
              ),
              const SizedBox(height: 12),
              _AmountField(controller: amount),
              const SizedBox(height: 12),
              _MethodField(
                value: method,
                onChanged: (value) => setModalState(() => method = value),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: note,
                decoration: const InputDecoration(
                  labelText: 'Catatan (opsional)',
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  if (!formKey.currentState!.validate()) return;
                  Navigator.of(context).pop(
                    _InventoryPurchaseInput(
                      itemId: item.id,
                      quantity: double.parse(quantity.text.replaceAll(',', '.')),
                      amount: int.parse(amount.text),
                      method: method,
                      note: note.text.trim(),
                    ),
                  );
                },
                icon: const Icon(Icons.save_outlined),
                label: const Text('Simpan Pembelian & Stok'),
              ),
            ],
          ),
        ),
      ),
    );
    quantity.dispose();
    amount.dispose();
    note.dispose();
    if (result == null || !mounted) return;
    await waitForTransientUiDismissal();
    if (!mounted) return;
    try {
      await ref.read(inventoryControllerProvider.notifier).recordPurchase(
        itemId: result.itemId,
        quantity: result.quantity,
        amount: result.amount,
        method: result.method,
        note: result.note,
      );
      await Future.wait([
        ref.read(expenseControllerProvider.notifier).refresh(),
        ref.read(cashbookControllerProvider.notifier).refresh(),
      ]);
      if (mounted) showAppSnackBar('Stok bertambah dan biaya masuk Buku Kas.');
    } catch (error) {
      if (mounted) showAppSnackBar(userErrorMessage(error, fallback: 'Pembelian belum tersimpan. Coba lagi.'));
    }
  }

  Future<void> _showUsageSheet(BuildContext context, PreviewInventoryItem item) async {
    final quantity = TextEditingController();
    final note = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final result = await showAppModalBottomSheet<_StockUsageInput>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Form(
        key: formKey,
        child: AppBottomSheetBody(children: [
          Text('Pakai ${item.name}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          Text('Tersedia ${item.stock} ${item.unit}. Pemakaian hanya mengurangi stok; biaya sudah tercatat saat dibeli.'),
          const SizedBox(height: 16),
          TextFormField(
            controller: quantity,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: 'Jumlah dipakai (${item.unit})'),
            validator: (value) {
              final parsed = double.tryParse((value ?? '').replaceAll(',', '.')) ?? 0;
              if (parsed <= 0) return 'Jumlah harus lebih dari nol.';
              if (parsed > item.stock) return 'Jumlah melebihi stok tersedia.';
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(controller: note, decoration: const InputDecoration(labelText: 'Untuk apa? (opsional)')),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(context, _StockUsageInput(double.parse(quantity.text.replaceAll(',', '.')), note.text.trim()));
            },
            icon: const Icon(Icons.remove_circle_outline),
            label: const Text('Catat Pemakaian'),
          ),
        ]),
      ),
    );
    quantity.dispose();
    note.dispose();
    if (result == null || !mounted) return;
    await waitForTransientUiDismissal();
    if (!mounted) return;
    try {
      await ref.read(inventoryControllerProvider.notifier).recordUsage(
        itemId: item.id, quantity: result.quantity, note: result.note,
      );
      if (mounted) showAppSnackBar('Pemakaian stok tercatat.');
    } catch (error) {
      if (mounted) showAppSnackBar(userErrorMessage(error, fallback: 'Pemakaian stok belum tersimpan.'));
    }
  }

  Future<void> _showExpenseSheet(BuildContext context) async {
    final description = TextEditingController();
    final amount = TextEditingController();
    var category = 'Operasional';
    var method = 'Tunai';
    final formKey = GlobalKey<FormState>();
    final result = await showAppModalBottomSheet<_ExpenseInput>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Form(
          key: formKey,
          child: AppBottomSheetBody(
            children: [
              const Text(
                'Tambah Pengeluaran',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: description,
                decoration: const InputDecoration(labelText: 'Deskripsi'),
                validator: (value) => (value ?? '').trim().isEmpty
                    ? 'Deskripsi wajib diisi.'
                    : null,
              ),
              const SizedBox(height: 12),
              _AmountField(controller: amount),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(labelText: 'Kategori'),
                items: const [
                  DropdownMenuItem(
                    value: 'Operasional',
                    child: Text('Operasional'),
                  ),
                  DropdownMenuItem(value: 'Gaji', child: Text('Gaji')),
                  DropdownMenuItem(value: 'Manual', child: Text('Lainnya')),
                ],
                onChanged: (value) =>
                    setModalState(() => category = value ?? category),
              ),
              const SizedBox(height: 12),
              _MethodField(
                value: method,
                onChanged: (value) => setModalState(() => method = value),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  if (!formKey.currentState!.validate()) return;
                  Navigator.of(context).pop(
                    _ExpenseInput(
                      description: description.text.trim(),
                      category: category,
                      amount: int.parse(amount.text),
                      method: method,
                    ),
                  );
                },
                icon: const Icon(Icons.save_outlined),
                label: const Text('Simpan Pengeluaran'),
              ),
            ],
          ),
        ),
      ),
    );
    description.dispose();
    amount.dispose();
    await _save(result, successMessage: 'Pengeluaran masuk Buku Kas.');
  }

  Future<void> _save(
    _ExpenseInput? result, {
    required String successMessage,
  }) async {
    if (result == null || !mounted) return;
    await waitForTransientUiDismissal();
    if (!mounted) return;
    try {
      await ref
          .read(expenseControllerProvider.notifier)
          .addExpense(
            description: result.description,
            category: result.category,
            amount: result.amount,
            method: result.method,
          );
      if (mounted) showAppSnackBar(successMessage);
    } catch (error) {
      if (mounted) {
        showAppSnackBar(
          userErrorMessage(
            error,
            fallback: 'Data gagal disimpan. Periksa nominal dan coba lagi.',
          ),
        );
      }
    }
  }
}

class _ProcurementView extends StatelessWidget {
  const _ProcurementView({
    required this.stock,
    required this.procurement,
    required this.isOwner,
    required this.onManageStock,
    required this.onUseStock,
  });

  final List<PreviewInventoryItem> stock;
  final List<PreviewExpense> procurement;
  final bool isOwner;
  final VoidCallback onManageStock;
  final ValueChanged<PreviewInventoryItem> onUseStock;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Live Stock',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
                  ),
                  Text(
                    'Jumlah stok terbaru dari semua pengguna.',
                    style: TextStyle(
                      color: AppColors.secondaryText,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (isOwner)
              TextButton.icon(
                onPressed: onManageStock,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Kelola'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: stock.isEmpty ? 100 : 262,
          child: stock.isEmpty
              ? Card(
                  margin: EdgeInsets.zero,
                  child: Center(
                    child: Text(
                      isOwner
                          ? 'Stok belum ada. Tekan Kelola untuk menambahkan.'
                          : 'Stok belum ditambahkan oleh Owner.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) => GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: constraints.maxWidth >= 720 ? 4 : 2,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                    mainAxisExtent: 124,
                    ),
                    itemCount: stock.length,
                    itemBuilder: (context, index) {
                      final item = stock[index];
                      return InkWell(
                        onTap: () => onUseStock(item),
                        key: ValueKey('live-stock-${item.name}'),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: item.isLowStock
                                ? AppColors.warning.withValues(alpha: 0.10)
                                : AppColors.primaryBlue.withValues(alpha: 0.06),
                            border: Border.all(
                              color: item.isLowStock
                                  ? AppColors.warning
                                  : AppColors.outline,
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    item.isLowStock
                                        ? Icons.warning_amber
                                        : Icons.inventory_2_outlined,
                                    size: 18,
                                    color: item.isLowStock
                                        ? AppColors.warning
                                        : AppColors.primaryBlue,
                                  ),
                                  const Spacer(),
                                  if (item.isLowStock)
                                    const Text(
                                      'MENIPIS',
                                      style: TextStyle(
                                        color: AppColors.warning,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              Text(
                                item.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                '${item.stock == item.stock.roundToDouble() ? item.stock.toStringAsFixed(0) : item.stock.toStringAsFixed(1)} ${item.unit}',
                                style: const TextStyle(
                                  color: AppColors.primaryNavy,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                ),
                              ),
                              const Spacer(),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Text('Pakai →', style: TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.w800, fontSize: 12)),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Riwayat Pengadaan',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _ExpenseList(
            items: procurement,
            emptyTitle: 'Pengadaan belum ada',
            emptyMessage: 'Catat pembelian gas, plastik, sabun, atau pewangi.',
          ),
        ),
      ],
    );
  }
}

enum _ExpensePeriod { today, yesterday, week, month }

extension on _ExpensePeriod {
  String get label => switch (this) {
    _ExpensePeriod.today => 'Hari ini',
    _ExpensePeriod.yesterday => 'Kemarin',
    _ExpensePeriod.week => 'Seminggu',
    _ExpensePeriod.month => 'Bulan ini',
  };
}

class _ExpenseList extends StatefulWidget {
  const _ExpenseList({
    required this.items,
    required this.emptyTitle,
    required this.emptyMessage,
  });

  final List<PreviewExpense> items;
  final String emptyTitle;
  final String emptyMessage;

  @override
  State<_ExpenseList> createState() => _ExpenseListState();
}

class _ExpenseListState extends State<_ExpenseList> {
  _ExpensePeriod _period = _ExpensePeriod.today;

  List<PreviewExpense> get _filteredItems {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = switch (_period) {
      _ExpensePeriod.today => today,
      _ExpensePeriod.yesterday => today.subtract(const Duration(days: 1)),
      _ExpensePeriod.week => today.subtract(const Duration(days: 6)),
      _ExpensePeriod.month => DateTime(now.year, now.month),
    };
    final end = switch (_period) {
      _ExpensePeriod.today => today.add(const Duration(days: 1)),
      _ExpensePeriod.yesterday => today,
      _ExpensePeriod.week => today.add(const Duration(days: 1)),
      _ExpensePeriod.month => DateTime(now.year, now.month + 1),
    };

    return widget.items.where((item) {
      final createdAt = item.createdAt.toLocal();
      return !createdAt.isBefore(start) && createdAt.isBefore(end);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = _filteredItems;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<_ExpensePeriod>(
          segments: [
            for (final period in _ExpensePeriod.values)
              ButtonSegment(value: period, label: Text(period.label)),
          ],
          selected: {_period},
          showSelectedIcon: false,
          style: ButtonStyle(
            visualDensity: VisualDensity.compact,
            textStyle: WidgetStateProperty.all(
              const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            ),
          ),
            onSelectionChanged: (selection) {
              setState(() => _period = selection.first);
            },
          ),
        ),
        const SizedBox(height: 10),
        ListTile(
          dense: true,
          title: Text('${filteredItems.length} transaksi ${_period.label.toLowerCase()}'),
          trailing: Text(
            filteredItems.fold<int>(0, (sum, item) => sum + item.amount).toRupiah(),
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        Expanded(
          child: filteredItems.isEmpty
              ? AppStateView.empty(
                  title: widget.items.isEmpty
                      ? widget.emptyTitle
                      : 'Tidak ada data ${_period.label.toLowerCase()}',
                  message: widget.items.isEmpty
                      ? widget.emptyMessage
                      : 'Pilih rentang waktu lain untuk melihat riwayat.',
                )
              : ListView.separated(
                  itemCount: filteredItems.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final item = filteredItems[index];
                    return Card(
                      margin: EdgeInsets.zero,
                      clipBehavior: Clip.antiAlias,
                      child: ExpansionTile(
                        key: PageStorageKey(item.id),
                        tilePadding: const EdgeInsets.fromLTRB(10, 0, 8, 0),
                        childrenPadding: const EdgeInsets.fromLTRB(
                          12,
                          0,
                          12,
                          10,
                        ),
                        visualDensity: VisualDensity.compact,
                        title: Row(
                          children: [
                            Icon(
                              item.category == 'Stok'
                                  ? Icons.local_shipping_outlined
                                  : Icons.price_check_outlined,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item.description,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              item.amount.toRupiah(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '${item.category} · ${item.method}\n'
                              '${item.createdAt.toIndonesianDate()} '
                              '${item.createdAt.toIndonesianTime()}',
                              style: const TextStyle(
                                color: AppColors.secondaryText,
                                height: 1.45,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _AmountField extends StatelessWidget {
  const _AmountField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    keyboardType: TextInputType.number,
    decoration: const InputDecoration(labelText: 'Nominal'),
    validator: (value) =>
        (int.tryParse(value ?? '') ?? 0) <= 0 ? 'Nominal wajib diisi.' : null,
  );
}

class _MethodField extends StatelessWidget {
  const _MethodField({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
    initialValue: value,
    decoration: const InputDecoration(labelText: 'Metode'),
    items: const [
      DropdownMenuItem(value: 'Tunai', child: Text('Tunai')),
      DropdownMenuItem(value: 'Transfer', child: Text('Transfer')),
      DropdownMenuItem(value: 'QRIS', child: Text('QRIS')),
    ],
    onChanged: (next) {
      if (next != null) onChanged(next);
    },
  );
}

class _ExpenseInput {
  const _ExpenseInput({
    required this.description,
    required this.category,
    required this.amount,
    required this.method,
  });

  final String description;
  final String category;
  final int amount;
  final String method;
}

class _InventoryPurchaseInput {
  const _InventoryPurchaseInput({
    required this.itemId,
    required this.quantity,
    required this.amount,
    required this.method,
    required this.note,
  });

  final String itemId;
  final double quantity;
  final int amount;
  final String method;
  final String note;
}

class _StockUsageInput {
  const _StockUsageInput(this.quantity, this.note);

  final double quantity;
  final String note;
}
