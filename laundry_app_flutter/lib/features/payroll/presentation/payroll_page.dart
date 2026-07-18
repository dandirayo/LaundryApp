import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/extensions/currency_extensions.dart';
import '../../../core/extensions/date_time_extensions.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import '../../../core/widgets/responsive_page.dart';
import '../../../shared/preview_data.dart';

class PayrollPage extends ConsumerWidget {
  const PayrollPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(previewDataProvider);
    final incentiveRequests = data.requests
        .where(
          (request) =>
              request.type.contains('Insentif') ||
              request.type.contains('Kasbon'),
        )
        .toList();
    final periodStart = _startOfWeek(DateTime.now());

    return Scaffold(
      appBar: AppBar(title: const Text('Gaji & Insentif')),
      body: ResponsivePage(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: ListView(
          children: [
            const Card(
              child: ListTile(
                leading: Icon(Icons.payments_outlined),
                title: Text('Gaji mingguan default'),
                subtitle: Text(
                  'Nominal tersimpan sebagai setting bisnis, bukan hardcoded produksi.',
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Pembayaran minggu ini',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            for (final employee in data.employees) ...[
              _PayrollEmployeeCard(
                employee: employee,
                amount: data.weeklySalaryAmount,
                periodStart: periodStart,
                isPaid: _isSalaryPaid(data, employee.id, periodStart),
                onPay: () => _paySalary(context, ref, employee),
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 12),
            Text(
              'Request terkait gaji',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            if (incentiveRequests.isEmpty)
              const Card(
                child: ListTile(
                  title: Text('Belum ada request insentif atau kasbon.'),
                ),
              )
            else
              for (final request in incentiveRequests)
                Card(
                  child: ListTile(
                    title: Text(request.type),
                    subtitle: Text(
                      '${request.reason}\n${request.status.label}',
                    ),
                    isThreeLine: true,
                    trailing: Text(request.amount.toRupiah()),
                  ),
                ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => context.go(AppRoutes.requestReview),
              icon: const Icon(Icons.rule_folder_outlined),
              label: const Text('Review Request Karyawan'),
            ),
          ],
        ),
      ),
    );
  }

  bool _isSalaryPaid(
    PreviewDataState data,
    String employeeId,
    DateTime periodStart,
  ) {
    final referenceId = _payrollReference(employeeId, periodStart);
    return data.cashTransactions.any(
      (cash) =>
          cash.referenceType == 'PAYROLL' && cash.referenceId == referenceId,
    );
  }

  Future<void> _paySalary(
    BuildContext context,
    WidgetRef ref,
    PreviewEmployee employee,
  ) async {
    final method = await _showPaymentMethodSheet(context);
    if (method == null || !context.mounted) {
      return;
    }
    final confirmed = await showConfirmationDialog(
      context,
      title: 'Bayar gaji?',
      message:
          'Gaji mingguan ${employee.name} akan dicatat sebagai uang keluar.',
      confirmLabel: 'Bayar',
    );
    if (!confirmed || !context.mounted) {
      return;
    }
    try {
      ref
          .read(previewDataProvider.notifier)
          .payWeeklySalary(employeeId: employee.id, method: method);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Gaji masuk Buku Kas.')));
    } on StateError catch (error) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<String?> _showPaymentMethodSheet(BuildContext context) async {
    var method = 'Tunai';
    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Metode Pembayaran',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
              const SizedBox(height: 16),
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
                onPressed: () => Navigator.of(context).pop(method),
                icon: const Icon(Icons.point_of_sale),
                label: const Text('Pilih Metode'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  DateTime _startOfWeek(DateTime value) {
    final date = DateTime(value.year, value.month, value.day);
    return date.subtract(Duration(days: date.weekday - DateTime.monday));
  }

  String _payrollReference(String employeeId, DateTime periodStart) {
    return 'PAYROLL-$employeeId-${periodStart.year}${periodStart.month.toString().padLeft(2, '0')}${periodStart.day.toString().padLeft(2, '0')}';
  }
}

class _PayrollEmployeeCard extends StatelessWidget {
  const _PayrollEmployeeCard({
    required this.employee,
    required this.amount,
    required this.periodStart,
    required this.isPaid,
    required this.onPay,
  });

  final PreviewEmployee employee;
  final int amount;
  final DateTime periodStart;
  final bool isPaid;
  final VoidCallback onPay;

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
                    employee.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
                Text(
                  amount.toRupiah(),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${employee.position} - Periode ${periodStart.toIndonesianDate()}',
              style: const TextStyle(color: AppColors.secondaryText),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: isPaid ? null : onPay,
              icon: Icon(isPaid ? Icons.task_alt : Icons.payments_outlined),
              label: Text(isPaid ? 'Sudah Dibayar' : 'Bayar Gaji'),
            ),
          ],
        ),
      ),
    );
  }
}
