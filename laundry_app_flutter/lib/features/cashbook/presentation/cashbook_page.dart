import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/extensions/currency_extensions.dart';
import '../../../core/extensions/date_time_extensions.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../core/widgets/responsive_page.dart';
import '../../../shared/preview_data.dart';
import '../domain/payment_method_totals.dart';
import 'cashbook_controller.dart';
import 'payment_method_summary_card.dart';

class CashbookPage extends ConsumerStatefulWidget {
  const CashbookPage({super.key});

  @override
  ConsumerState<CashbookPage> createState() => _CashbookPageState();
}

class _CashbookPageState extends ConsumerState<CashbookPage>
    with WidgetsBindingObserver {
  _CashbookView _view = _CashbookView.transactions;
  _CashbookPeriod _period = _CashbookPeriod.today;
  DateTimeRange? _customRange;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refresh();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() =>
      ref.read(cashbookControllerProvider.notifier).refresh();

  @override
  Widget build(BuildContext context) {
    final cashbookState = ref.watch(cashbookControllerProvider);
    if (!cashbookState.hasValue) {
      return Scaffold(
        appBar: AppBar(title: Text(ref.strings.cashbook)),
        body: Center(
          child: cashbookState.hasError
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Buku Kas belum berhasil dimuat.'),
                    TextButton(
                      onPressed: _refresh,
                      child: const Text('Coba Lagi'),
                    ),
                  ],
                )
              : const CircularProgressIndicator(),
        ),
      );
    }
    final onlineTransactions = cashbookState.value?.transactions;
    final previewCash = ref.watch(
      previewDataProvider.select(
        (state) => (
          cashTransactions: state.cashTransactions,
          legacyMonthlySummaries: state.legacyMonthlySummaries,
        ),
      ),
    );
    final allTransactions = onlineTransactions ?? previewCash.cashTransactions;
    final legacySummaries = cashbookState.value!.isOnline
        ? <PreviewLegacyMonthlySummary>[]
        : previewCash.legacyMonthlySummaries;
    final strings = ref.strings;
    final range = _rangeFor(_period);
    final filteredCash = allTransactions
        .where((entry) => _isWithinRange(entry.createdAt, range))
        .toList();
    final filteredLegacy = legacySummaries
        .where((summary) => _isMonthWithinRange(summary.month, range))
        .toList();
    final openingBalance = allTransactions
        .where((entry) => entry.createdAt.isBefore(range.start))
        .fold<int>(0, (sum, entry) => sum + _cashEffect(entry));
    final income = filteredCash
        .where((entry) => entry.type == 'IN')
        .fold<int>(0, (sum, entry) => sum + entry.amount);
    final outcome = filteredCash
        .where((entry) => entry.type == 'OUT')
        .fold<int>(0, (sum, entry) => sum + entry.amount);
    final incomeMethods = PaymentMethodTotals.fromTransactions(
      filteredCash,
      type: 'IN',
    );
    final outcomeMethods = PaymentMethodTotals.fromTransactions(
      filteredCash,
      type: 'OUT',
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.cashbook),
        actions: [
          IconButton(
            tooltip: 'Sinkronkan Buku Kas',
            onPressed: _refresh,
            icon: const Icon(Icons.sync),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ResponsivePage(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              if (cashbookState.hasError || cashbookState.value!.syncFailed)
                ListTile(
                  leading: const Icon(Icons.sync_problem),
                  title: const Text(
                    'Sinkronisasi gagal. Menampilkan data terakhir.',
                  ),
                  trailing: TextButton(
                    onPressed: _refresh,
                    child: const Text('Coba Lagi'),
                  ),
                ),
              SegmentedButton<_CashbookView>(
                segments: [
                  ButtonSegment(
                    value: _CashbookView.transactions,
                    label: Text(strings.transactions),
                    icon: const Icon(Icons.receipt_long_outlined),
                  ),
                  ButtonSegment(
                    value: _CashbookView.summary,
                    label: Text(strings.summary),
                    icon: const Icon(Icons.summarize_outlined),
                  ),
                ],
                selected: {_view},
                onSelectionChanged: (value) =>
                    setState(() => _view = value.first),
              ),
              const SizedBox(height: 12),
              _PeriodPicker(
                selected: _period,
                label: _rangeLabel(range),
                onChanged: _changePeriod,
              ),
              const SizedBox(height: 12),
              _TotalTile(
                'Saldo Akhir',
                openingBalance + income - outcome,
                AppColors.primaryNavy,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _TotalTile('Uang Masuk', income, AppColors.success),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TotalTile('Uang Keluar', outcome, AppColors.error),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_view == _CashbookView.transactions) ...[
                PaymentMethodSummaryCard(
                  title: 'Uang masuk: Tunai & Transfer',
                  totals: incomeMethods,
                ),
                Card(
                  child: ExpansionTile(
                    title: const Text(
                      'Rincian uang keluar',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: const Text('Metode pembayaran pengeluaran'),
                    childrenPadding: const EdgeInsets.all(8),
                    children: [
                      PaymentMethodSummaryCard(
                        title: 'Uang keluar menurut cara bayar',
                        totals: outcomeMethods,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                _TransactionList(cash: filteredCash),
              ] else
                _SummaryList(
                  openingBalance: openingBalance,
                  income: income,
                  outcome: outcome,
                  cash: filteredCash,
                  legacySummaries: filteredLegacy,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _changePeriod(_CashbookPeriod period) async {
    if (period == _CashbookPeriod.custom) {
      final now = DateTime.now();
      final activeRange = _rangeFor(_period);
      final selectedRange = await showDateRangePicker(
        context: context,
        firstDate: DateTime(now.year - 3),
        lastDate: DateTime(now.year + 1, 12, 31),
        initialDateRange:
            _customRange ??
            DateTimeRange(
              start: activeRange.start,
              end: activeRange.end.subtract(const Duration(days: 1)),
            ),
        helpText: 'Pilih periode buku kas',
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
    setState(() => _period = period);
  }

  DateTimeRange _rangeFor(_CashbookPeriod period) {
    final today = _startOfDay(DateTime.now());
    final monthEnd = today.month == 12
        ? DateTime(today.year + 1)
        : DateTime(today.year, today.month + 1);
    return switch (period) {
      _CashbookPeriod.today => DateTimeRange(
        start: today,
        end: today.add(const Duration(days: 1)),
      ),
      _CashbookPeriod.yesterday => DateTimeRange(
        start: today.subtract(const Duration(days: 1)),
        end: today,
      ),
      _CashbookPeriod.thisWeek => DateTimeRange(
        start: today.subtract(Duration(days: today.weekday - 1)),
        end: today
            .subtract(Duration(days: today.weekday - 1))
            .add(const Duration(days: 7)),
      ),
      _CashbookPeriod.thisMonth => DateTimeRange(
        start: DateTime(today.year, today.month),
        end: monthEnd,
      ),
      _CashbookPeriod.last3Months => DateTimeRange(
        start: DateTime(today.year, today.month - 2),
        end: monthEnd,
      ),
      _CashbookPeriod.last6Months => DateTimeRange(
        start: DateTime(today.year, today.month - 5),
        end: monthEnd,
      ),
      _CashbookPeriod.lastYear => DateTimeRange(
        start: DateTime(today.year - 1, today.month, today.day),
        end: today.add(const Duration(days: 1)),
      ),
      _CashbookPeriod.legacyExcel => DateTimeRange(
        start: DateTime(2025, 5),
        end: DateTime(2026, 5),
      ),
      _CashbookPeriod.custom =>
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

enum _CashbookView { transactions, summary }

enum _CashbookPeriod {
  today('Hari ini'),
  yesterday('Kemarin'),
  thisWeek('Minggu ini'),
  thisMonth('Bulan ini'),
  last3Months('3 bulan'),
  last6Months('6 bulan'),
  lastYear('1 tahun'),
  legacyExcel('Old Data'),
  custom('Custom');

  const _CashbookPeriod(this.label);

  final String label;
}

class _PeriodPicker extends StatelessWidget {
  const _PeriodPicker({
    required this.selected,
    required this.label,
    required this.onChanged,
  });

  final _CashbookPeriod selected;
  final String label;
  final ValueChanged<_CashbookPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppColors.secondaryText,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final period in _CashbookPeriod.values.take(4)) ...[
                    ChoiceChip(
                      label: Text(period.label),
                      selected: selected == period,
                      onSelected: (_) => onChanged(period),
                    ),
                    const SizedBox(width: 8),
                  ],
                  PopupMenuButton<_CashbookPeriod>(
                    tooltip: 'Periode lainnya',
                    onSelected: onChanged,
                    itemBuilder: (context) => [
                      for (final period in _CashbookPeriod.values.skip(4))
                        PopupMenuItem(value: period, child: Text(period.label)),
                    ],
                    child: Chip(
                      avatar: const Icon(Icons.expand_more, size: 18),
                      label: Text(
                        _CashbookPeriod.values.take(4).contains(selected)
                            ? 'Lainnya'
                            : selected.label,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionList extends StatefulWidget {
  const _TransactionList({required this.cash});

  final List<PreviewCashTransaction> cash;

  @override
  State<_TransactionList> createState() => _TransactionListState();
}

class _TransactionListState extends State<_TransactionList> {
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final cash = widget.cash;
    if (cash.isEmpty) {
      return const AppStateView.empty(
        title: 'Transaksi kas belum ada',
        message: 'Pembayaran pesanan dan pengeluaran akan masuk ke sini.',
      );
    }
    return Column(
      children: [
        for (final entry in (_showAll ? cash : cash.take(10))) ...[
          Card(
            child: ListTile(
              leading: Icon(
                entry.type == 'IN' ? Icons.south_west : Icons.north_east,
                color: entry.type == 'IN' ? AppColors.success : AppColors.error,
              ),
              title: Text(entry.description),
              subtitle: Text(
                '${entry.createdAt.toIndonesianDate()} • ${entry.category} • ${entry.method}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Text(
                entry.amount.toRupiah(),
                style: TextStyle(
                  color: entry.type == 'IN'
                      ? AppColors.success
                      : AppColors.error,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
        ],
        if (cash.length > 10)
          TextButton(
            onPressed: () => setState(() => _showAll = !_showAll),
            child: Text(
              _showAll
                  ? 'Tampilkan lebih sedikit'
                  : 'Lihat semua ${cash.length} transaksi',
            ),
          ),
      ],
    );
  }
}

class _SummaryList extends StatelessWidget {
  const _SummaryList({
    required this.openingBalance,
    required this.income,
    required this.outcome,
    required this.cash,
    required this.legacySummaries,
  });

  final int openingBalance;
  final int income;
  final int outcome;
  final List<PreviewCashTransaction> cash;
  final List<PreviewLegacyMonthlySummary> legacySummaries;

  @override
  Widget build(BuildContext context) {
    final cashInCount = cash.where((entry) => entry.type == 'IN').length;
    final cashOutCount = cash.where((entry) => entry.type == 'OUT').length;
    final biggestExpense = _biggestByType('OUT');
    final biggestIncome = _biggestByType('IN');
    final biggestExpenseCategory = _biggestExpenseCategory();
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
    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                _SummaryRow('Saldo awal', openingBalance.toRupiah()),
                _SummaryRow('Selisih periode', (income - outcome).toRupiah()),
                _SummaryRow('Kas masuk', '$cashInCount transaksi'),
                _SummaryRow('Kas keluar', '$cashOutCount transaksi'),
              ],
            ),
          ),
        ),
        Card(
          child: ExpansionTile(
            title: const Text(
              'Analisis transaksi',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: const Text('Transaksi dan kategori terbesar'),
            childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            children: [
              _Metric('Pengeluaran terbesar', biggestExpense),
              _Metric('Kategori pengeluaran terbesar', biggestExpenseCategory),
              _Metric('Pendapatan terbesar', biggestIncome),
            ],
          ),
        ),
        if (legacySummaries.isNotEmpty)
          Card(
            child: ExpansionTile(
              title: const Text(
                'Old Data',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                '${legacySummaries.first.label} - ${legacySummaries.last.label}',
              ),
              childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              children: [
                _Metric('Pemasukan Old Data', legacyIncome.toRupiah()),
                _Metric('Pengeluaran Old Data', legacyExpense.toRupiah()),
                _Metric('Laba/Rugi Old Data', legacyProfit.toRupiah()),
                _Metric(
                  'Saldo akhir Old Data',
                  legacySummaries.last.closingBalance.toRupiah(),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _biggestByType(String type) {
    final entries = cash.where((entry) => entry.type == type).toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));
    if (entries.isEmpty) {
      return '-';
    }
    return '${entries.first.description} (${entries.first.amount.toRupiah()})';
  }

  String _biggestExpenseCategory() {
    final totals = <String, int>{};
    for (final entry in cash.where((entry) => entry.type == 'OUT')) {
      totals[entry.category] = (totals[entry.category] ?? 0) + entry.amount;
    }
    if (totals.isEmpty) {
      return '-';
    }
    final sorted = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return '${sorted.first.key} (${sorted.first.value.toRupiah()})';
  }
}

class _TotalTile extends StatelessWidget {
  const _TotalTile(this.label, this.amount, this.color);

  final String label;
  final int amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: AppColors.secondaryText)),
            const SizedBox(height: 6),
            Text(
              amount.toRupiah(),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: AppColors.secondaryText),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    ),
  );
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 2, child: Text(label)),
            const SizedBox(width: 16),
            Expanded(
              flex: 3,
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
