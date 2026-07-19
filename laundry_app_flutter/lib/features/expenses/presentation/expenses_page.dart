import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/extensions/currency_extensions.dart';
import '../../../core/extensions/date_time_extensions.dart';
import '../../../core/widgets/app_bottom_sheet_body.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../core/widgets/responsive_page.dart';
import '../../../shared/preview_data.dart';

class ExpensesPage extends ConsumerWidget {
  const ExpensesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenses = ref.watch(
      previewDataProvider.select((state) => state.expenses),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengeluaran'),
        actions: [
          IconButton(
            tooltip: 'Tambah pengeluaran',
            onPressed: () => _showExpenseSheet(context, ref),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      floatingActionButton: expenses.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _showExpenseSheet(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Pengeluaran'),
            ),
      body: ResponsivePage(
        padding: EdgeInsets.fromLTRB(16, 8, 16, expenses.isEmpty ? 24 : 96),
        child: expenses.isEmpty
            ? AppStateView.empty(
                title: 'Pengeluaran belum ada',
                message:
                    'Tambah pengeluaran agar otomatis tercatat di Buku Kas.',
                actionLabel: 'Tambah pengeluaran',
                onAction: () => _showExpenseSheet(context, ref),
              )
            : ListView.separated(
                itemCount: expenses.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final expense = expenses[index];
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.price_check_outlined),
                      title: Text(expense.description),
                      subtitle: Text(
                        '${expense.category} - ${expense.method}\n${expense.createdAt.toIndonesianDate()} ${expense.createdAt.toIndonesianTime()}',
                      ),
                      isThreeLine: true,
                      trailing: Text(
                        expense.amount.toRupiah(),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Future<void> _showExpenseSheet(BuildContext context, WidgetRef ref) async {
    final description = TextEditingController();
    final amount = TextEditingController();
    var category = 'Operasional';
    var method = 'Tunai';
    final formKey = GlobalKey<FormState>();
    final result = await showModalBottomSheet<_ExpenseInput>(
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
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
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
              TextFormField(
                controller: amount,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Nominal'),
                validator: (value) => (int.tryParse(value ?? '') ?? 0) <= 0
                    ? 'Nominal wajib diisi.'
                    : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: category,
                items: const [
                  DropdownMenuItem(
                    value: 'Operasional',
                    child: Text('Operasional'),
                  ),
                  DropdownMenuItem(value: 'Gaji', child: Text('Gaji')),
                  DropdownMenuItem(value: 'Stok', child: Text('Stok')),
                  DropdownMenuItem(value: 'Manual', child: Text('Manual')),
                ],
                onChanged: (value) =>
                    setModalState(() => category = value ?? category),
                decoration: const InputDecoration(labelText: 'Kategori'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: method,
                items: const [
                  DropdownMenuItem(value: 'Tunai', child: Text('Tunai')),
                  DropdownMenuItem(value: 'Transfer', child: Text('Transfer')),
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
                    _ExpenseInput(
                      description: description.text,
                      category: category,
                      amount: int.parse(amount.text),
                      method: method,
                    ),
                  );
                },
                icon: const Icon(Icons.save_outlined),
                label: const Text('Simpan'),
              ),
            ],
          ),
        ),
      ),
    );
    description.dispose();
    amount.dispose();

    if (result == null || !context.mounted) {
      return;
    }
    ref
        .read(previewDataProvider.notifier)
        .addExpense(
          description: result.description,
          category: result.category,
          amount: result.amount,
          method: result.method,
        );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Pengeluaran masuk Buku Kas.')),
    );
  }
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
