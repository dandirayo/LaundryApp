import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/extensions/currency_extensions.dart';
import '../../../core/extensions/date_time_extensions.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../core/widgets/responsive_page.dart';
import '../../../shared/preview_data.dart';

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  _ReportPeriod _period = _ReportPeriod.today;
  DateTimeRange? _customRange;

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(
      previewDataProvider.select(
        (state) => (
          orders: state.orders,
          cashTransactions: state.cashTransactions,
          legacyMonthlySummaries: state.legacyMonthlySummaries,
        ),
      ),
    );
    final strings = ref.strings;
    final activeRange = _rangeFor(_period);
    final orders = data.orders
        .where((order) => _isWithinRange(order.receivedAt, activeRange))
        .toList();
    final cashTransactions = data.cashTransactions
        .where((entry) => _isWithinRange(entry.createdAt, activeRange))
        .toList();
    final orderValue = orders.fold<int>(
      0,
      (sum, order) => sum + order.totalPrice,
    );
    final paid = orders.fold<int>(0, (sum, order) => sum + order.paidAmount);
    final remaining = orders.fold<int>(
      0,
      (sum, order) => sum + order.remainingAmount,
    );
    final income = cashTransactions
        .where((entry) => entry.type == 'IN')
        .fold<int>(0, (sum, entry) => sum + entry.amount);
    final outcome = cashTransactions
        .where((entry) => entry.type == 'OUT')
        .fold<int>(0, (sum, entry) => sum + entry.amount);
    final openingBalance = data.cashTransactions
        .where((entry) => entry.createdAt.isBefore(activeRange.start))
        .fold<int>(0, (sum, entry) => sum + _cashEffect(entry));
    final uniqueCustomers = orders.map((order) => order.customerId).toSet();
    final legacySummaries = data.legacyMonthlySummaries
        .where((summary) => _isMonthWithinRange(summary.month, activeRange))
        .toList();
    final legacyIncome = legacySummaries.fold<int>(
      0,
      (sum, summary) => sum + summary.income,
    );
    final legacyExpense = legacySummaries.fold<int>(
      0,
      (sum, summary) => sum + summary.expense,
    );
    final legacyProfit = legacySummaries.fold<int>(
      0,
      (sum, summary) => sum + summary.profit,
    );

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(strings.reports),
          bottom: TabBar(
            tabs: [
              Tab(text: strings.orderBook),
              Tab(text: strings.cashbook),
              Tab(text: strings.oldData),
            ],
          ),
        ),
        body: ResponsivePage(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            children: [
              _ReportDateFilterBar(
                selected: _period,
                rangeLabel: _rangeLabel(activeRange),
                onChanged: _changePeriod,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TabBarView(
                  children: [
                    ListView(
                      children: [
                        _Metric('Jumlah pesanan', '${orders.length}'),
                        _Metric('Pelanggan unik', '${uniqueCustomers.length}'),
                        _Metric(
                          'Total kilogram',
                          '${orders.fold<double>(0, (sum, order) => sum + order.laundryWeightKg).toStringAsFixed(1)} kg',
                        ),
                        _Metric(
                          'Sepatu',
                          '${orders.fold<double>(0, (sum, order) => sum + order.quantityForUnit('PAIR')).toStringAsFixed(1)} pasang',
                        ),
                        _Metric(
                          'Item',
                          '${orders.fold<double>(0, (sum, order) => sum + order.quantityForUnit('ITEM')).toStringAsFixed(1)} item',
                        ),
                        _Metric(
                          'Buah',
                          '${orders.fold<double>(0, (sum, order) => sum + order.quantityForUnit('PIECE')).toStringAsFixed(1)} buah',
                        ),
                        _Metric('Nilai pesanan', orderValue.toRupiah()),
                        _Metric('Pembayaran diterima', paid.toRupiah()),
                        _Metric('Sisa tagihan', remaining.toRupiah()),
                        _Metric(
                          'Pesanan selesai',
                          '${orders.where((order) => order.orderStatus == PreviewOrderStatus.ready || order.orderStatus == PreviewOrderStatus.pickedUp).length}',
                        ),
                      ],
                    ),
                    ListView(
                      children: [
                        _Metric('Saldo awal', openingBalance.toRupiah()),
                        _Metric('Total uang masuk', income.toRupiah()),
                        _Metric('Total uang keluar', outcome.toRupiah()),
                        _Metric(
                          'Saldo akhir',
                          (openingBalance + income - outcome).toRupiah(),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () {
                            ref
                                .read(previewDataProvider.notifier)
                                .recordBackupExport('Laporan CSV/PDF');
                            showAppSnackBar(
                              'Export laporan preview disiapkan.',
                            );
                          },
                          icon: const Icon(Icons.file_download_outlined),
                          label: const Text('Export CSV/PDF'),
                        ),
                      ],
                    ),
                    ListView(
                      children: [
                        _Metric(
                          'Periode terbaca',
                          legacySummaries.isEmpty
                              ? '-'
                              : '${legacySummaries.first.label} - ${legacySummaries.last.label}',
                        ),
                        _Metric('Pemasukan legacy', legacyIncome.toRupiah()),
                        _Metric('Pengeluaran legacy', legacyExpense.toRupiah()),
                        _Metric('Laba/Rugi legacy', legacyProfit.toRupiah()),
                        _Metric(
                          'Saldo akhir legacy',
                          legacySummaries.isEmpty
                              ? 'Rp0'
                              : legacySummaries.last.closingBalance.toRupiah(),
                        ),
                        const SizedBox(height: 12),
                        if (legacySummaries.isEmpty)
                          const Card(
                            child: ListTile(
                              title: Text('Tidak ada Old Data'),
                              subtitle: Text(
                                'Pilih periode Mei 2025 sampai April 2026, atau gunakan filter 1 tahun/custom.',
                              ),
                            ),
                          )
                        else
                          for (final summary in legacySummaries)
                            Card(
                              child: ListTile(
                                title: Text(summary.label),
                                subtitle: Text(
                                  'Masuk ${summary.income.toRupiah()} - Keluar ${summary.expense.toRupiah()}',
                                ),
                                trailing: Text(
                                  summary.profit.toRupiah(),
                                  style: TextStyle(
                                    color: summary.profit >= 0
                                        ? AppColors.success
                                        : AppColors.error,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _changePeriod(_ReportPeriod period) async {
    if (period == _ReportPeriod.custom) {
      final now = DateTime.now();
      final activeRange = _rangeFor(_period);
      final initialDateRange =
          _customRange ??
          DateTimeRange(
            start: activeRange.start,
            end: activeRange.end.subtract(const Duration(days: 1)),
          );
      final selectedRange = await showDateRangePicker(
        context: context,
        firstDate: DateTime(now.year - 3),
        lastDate: DateTime(now.year + 1, 12, 31),
        initialDateRange: initialDateRange,
        helpText: 'Pilih rentang laporan',
        saveText: 'Terapkan',
      );

      if (selectedRange == null || !mounted) {
        return;
      }

      setState(() {
        _period = period;
        _customRange = selectedRange;
      });
      return;
    }

    setState(() {
      _period = period;
    });
  }

  DateTimeRange _rangeFor(_ReportPeriod period) {
    final today = _startOfDay(DateTime.now());

    return switch (period) {
      _ReportPeriod.today => DateTimeRange(
        start: today,
        end: today.add(const Duration(days: 1)),
      ),
      _ReportPeriod.yesterday => DateTimeRange(
        start: today.subtract(const Duration(days: 1)),
        end: today,
      ),
      _ReportPeriod.thisWeek => DateTimeRange(
        start: today.subtract(Duration(days: today.weekday - 1)),
        end: today
            .subtract(Duration(days: today.weekday - 1))
            .add(const Duration(days: 7)),
      ),
      _ReportPeriod.thisMonth => DateTimeRange(
        start: DateTime(today.year, today.month),
        end: today.month == 12
            ? DateTime(today.year + 1)
            : DateTime(today.year, today.month + 1),
      ),
      _ReportPeriod.last3Months => DateTimeRange(
        start: DateTime(today.year, today.month - 2),
        end: today.month == 12
            ? DateTime(today.year + 1)
            : DateTime(today.year, today.month + 1),
      ),
      _ReportPeriod.last6Months => DateTimeRange(
        start: DateTime(today.year, today.month - 5),
        end: today.month == 12
            ? DateTime(today.year + 1)
            : DateTime(today.year, today.month + 1),
      ),
      _ReportPeriod.lastYear => DateTimeRange(
        start: DateTime(today.year - 1, today.month, today.day),
        end: today.add(const Duration(days: 1)),
      ),
      _ReportPeriod.legacyExcel => DateTimeRange(
        start: DateTime(2025, 5),
        end: DateTime(2026, 5),
      ),
      _ReportPeriod.custom =>
        _customRange == null
            ? DateTimeRange(
                start: today,
                end: today.add(const Duration(days: 1)),
              )
            : DateTimeRange(
                start: _startOfDay(_customRange!.start),
                end: _startOfDay(
                  _customRange!.end,
                ).add(const Duration(days: 1)),
              ),
    };
  }

  String _rangeLabel(DateTimeRange range) {
    final end = range.end.subtract(const Duration(days: 1));
    if (_isSameDay(range.start, end)) {
      return range.start.toIndonesianDate();
    }
    return '${range.start.toIndonesianDate()} - ${end.toIndonesianDate()}';
  }

  bool _isWithinRange(DateTime date, DateTimeRange range) {
    return !date.isBefore(range.start) && date.isBefore(range.end);
  }

  bool _isMonthWithinRange(DateTime month, DateTimeRange range) {
    final monthStart = DateTime(month.year, month.month);
    final monthEnd = month.month == 12
        ? DateTime(month.year + 1)
        : DateTime(month.year, month.month + 1);
    return monthEnd.isAfter(range.start) && monthStart.isBefore(range.end);
  }

  bool _isSameDay(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  DateTime _startOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  int _cashEffect(PreviewCashTransaction entry) {
    return entry.type == 'IN' ? entry.amount : -entry.amount;
  }
}

enum _ReportPeriod {
  today('Hari ini'),
  yesterday('Kemarin'),
  thisWeek('Minggu ini'),
  thisMonth('Bulan ini'),
  last3Months('3 bulan'),
  last6Months('6 bulan'),
  lastYear('1 tahun'),
  legacyExcel('Old Data'),
  custom('Rentang');

  const _ReportPeriod(this.label);

  final String label;
}

class _ReportDateFilterBar extends StatelessWidget {
  const _ReportDateFilterBar({
    required this.selected,
    required this.rangeLabel,
    required this.onChanged,
  });

  final _ReportPeriod selected;
  final String rangeLabel;
  final ValueChanged<_ReportPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.date_range_outlined,
                  color: AppColors.primaryBlue,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Periode laporan',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        rangeLabel,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.secondaryText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final period in _ReportPeriod.values) ...[
                    ChoiceChip(
                      label: Text(period.label),
                      selected: selected == period,
                      onSelected: (_) => onChanged(period),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(label),
        trailing: Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}
