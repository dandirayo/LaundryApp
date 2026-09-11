import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/user_error_message.dart';
import '../../../core/extensions/currency_extensions.dart';
import '../../../core/extensions/date_time_extensions.dart';
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
        label: Text(_tabs.index == 0 ? 'Pengadaan' : 'Pengeluaran'),
      ),
      body: ResponsivePage(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        child: TabBarView(
          controller: _tabs,
          children: [
            _ProcurementView(
              stock: inventory,
              procurement: procurement,
              isOwner: isOwner,
              onManageStock: () => context.go(AppRoutes.inventory),
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
    const products = ['Gas', 'Plastik', 'Sabun', 'Pewangi'];
    const sizes = ['30', '35', '40', '45', '50', '55'];
    const plasticTypes = ['Biasa', 'Jinjing', 'Plastik Satuan'];
    var product = products.first;
    var size = sizes.first;
    var plasticType = plasticTypes.first;
    var method = 'Tunai';
    final amount = TextEditingController();
    final note = TextEditingController();
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
                'Tambah Pengadaan Stok',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
              ),
              const SizedBox(height: 6),
              const Text('Pilih barang lalu masukkan total nominal belanja.'),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final value in products)
                    ChoiceChip(
                      label: Text(value),
                      selected: product == value,
                      onSelected: (_) => setModalState(() => product = value),
                    ),
                ],
              ),
              if (product == 'Plastik') ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: size,
                  decoration: const InputDecoration(
                    labelText: 'Ukuran plastik',
                  ),
                  items: [
                    for (final value in sizes)
                      DropdownMenuItem(
                        value: value,
                        child: Text('Ukuran $value'),
                      ),
                  ],
                  onChanged: (value) =>
                      setModalState(() => size = value ?? size),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: plasticType,
                  decoration: const InputDecoration(labelText: 'Jenis plastik'),
                  items: [
                    for (final value in plasticTypes)
                      DropdownMenuItem(value: value, child: Text(value)),
                  ],
                  onChanged: (value) =>
                      setModalState(() => plasticType = value ?? plasticType),
                ),
              ],
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
                  final label = product == 'Plastik'
                      ? 'Plastik ukuran $size - $plasticType'
                      : product;
                  final description = note.text.trim().isEmpty
                      ? label
                      : '$label - ${note.text.trim()}';
                  Navigator.of(context).pop(
                    _ExpenseInput(
                      description: description,
                      category: 'Stok',
                      amount: int.parse(amount.text),
                      method: method,
                    ),
                  );
                },
                icon: const Icon(Icons.save_outlined),
                label: const Text('Simpan Pengadaan'),
              ),
            ],
          ),
        ),
      ),
    );
    amount.dispose();
    note.dispose();
    await _save(result, successMessage: 'Pengadaan tersimpan dan tersinkron.');
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
  });

  final List<PreviewInventoryItem> stock;
  final List<PreviewExpense> procurement;
  final bool isOwner;
  final VoidCallback onManageStock;

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
          height: 112,
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
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: stock.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final item = stock[index];
                    return Container(
                      width: 150,
                      padding: const EdgeInsets.all(12),
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
                          const Spacer(),
                          Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            '${item.stock.toStringAsFixed(1)} ${item.unit}',
                            style: const TextStyle(
                              color: AppColors.primaryNavy,
                              fontWeight: FontWeight.w900,
                              fontSize: 17,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
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

class _ExpenseList extends StatelessWidget {
  const _ExpenseList({
    required this.items,
    required this.emptyTitle,
    required this.emptyMessage,
  });

  final List<PreviewExpense> items;
  final String emptyTitle;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return AppStateView.empty(title: emptyTitle, message: emptyMessage);
    }
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = items[index];
        return Card(
          child: ListTile(
            leading: Icon(
              item.category == 'Stok'
                  ? Icons.local_shipping_outlined
                  : Icons.price_check_outlined,
            ),
            title: Text(item.description),
            subtitle: Text(
              '${item.category} · ${item.method}\n${item.createdAt.toIndonesianDate()} ${item.createdAt.toIndonesianTime()}',
            ),
            isThreeLine: true,
            trailing: Text(
              item.amount.toRupiah(),
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        );
      },
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
