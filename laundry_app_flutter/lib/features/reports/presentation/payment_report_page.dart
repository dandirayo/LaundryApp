import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/extensions/currency_extensions.dart';
import '../../../core/extensions/date_time_extensions.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../core/widgets/responsive_page.dart';
import '../../../shared/preview_data.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../cashbook/domain/payment_method_totals.dart';
import '../../cashbook/presentation/payment_method_summary_card.dart';
import '../../orders/presentation/order_controller.dart';

class PaymentReportPage extends ConsumerStatefulWidget {
  const PaymentReportPage({super.key});

  @override
  ConsumerState<PaymentReportPage> createState() => _PaymentReportPageState();
}

class _PaymentReportPageState extends ConsumerState<PaymentReportPage> {
  _PaymentPeriod _period = _PaymentPeriod.today;
  DateTimeRange? _customRange;
  bool _openingWhatsApp = false;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).value?.user;
    final paymentState = ref.watch(orderPaymentControllerProvider);
    final onlineMode =
        ref.watch(orderRepositoryProvider).isOnline &&
        user != null &&
        !user.shopId.startsWith('preview-shop');
    final payments =
        paymentState.value ??
        (onlineMode ? null : ref.watch(previewDataProvider).payments);
    final range = _rangeFor(_period);
    final summary = payments == null
        ? null
        : CustomerPaymentSummary.forRange(payments, range.start, range.end);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan Pembayaran'),
        actions: [
          IconButton(
            tooltip: 'Perbarui laporan',
            onPressed: () =>
                ref.read(orderPaymentControllerProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ResponsivePage(
        maxWidth: 1200,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final useLandscapeLayout =
                MediaQuery.orientationOf(context) == Orientation.landscape &&
                constraints.maxWidth >= 760;
            if (useLandscapeLayout && summary != null) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: constraints.maxWidth * .38,
                    child: ListView(
                      children: [
                        _periodCard(range),
                        const SizedBox(height: 12),
                        _totalCard(summary),
                        _scopeNote(),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ListView(
                      children: [
                        PaymentMethodSummaryCard(
                          title: 'Rincian pembayaran',
                          totals: summary.methods,
                          hybridOrderCount: summary.hybridOrderCount,
                          hybridAmount: summary.hybridAmountInRange,
                        ),
                        const SizedBox(height: 12),
                        _whatsAppActions(
                          summary,
                          range,
                          user?.name ?? 'Karyawan',
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }
            return ListView(
              children: [
                _periodCard(range),
                if (summary == null)
                  _loadingCard(paymentState.hasError)
                else ...[
                  _scopeNote(),
                  _totalCard(summary),
                  PaymentMethodSummaryCard(
                    title: 'Rincian pembayaran',
                    totals: summary.methods,
                    hybridOrderCount: summary.hybridOrderCount,
                    hybridAmount: summary.hybridAmountInRange,
                  ),
                  const SizedBox(height: 10),
                  _whatsAppActions(summary, range, user?.name ?? 'Karyawan'),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _periodCard(DateTimeRange range) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_rangeLabel(range), style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final period in _PaymentPeriod.values) ...[
                  ChoiceChip(
                    label: Text(period.label),
                    selected: _period == period,
                    onSelected: (_) => _changePeriod(period),
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

  Widget _scopeNote() => const Padding(
    padding: EdgeInsets.fromLTRB(4, 4, 4, 8),
    child: Text(
      'Hanya pembayaran pelanggan; transaksi kas lain dan pengeluaran ada di Buku Kas Owner.',
      style: TextStyle(color: AppColors.secondaryText, fontSize: 12),
    ),
  );

  Widget _totalCard(CustomerPaymentSummary summary) => Card(
    child: ListTile(
      title: const Text('Total pembayaran pelanggan'),
      subtitle: Text('${summary.paymentCount} transaksi pada periode ini'),
      trailing: Text(
        summary.total.toRupiah(),
        style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.primaryNavy),
      ),
    ),
  );

  Widget _loadingCard(bool hasError) => Card(
    child: ListTile(
      title: Text(hasError ? 'Laporan belum berhasil dimuat' : 'Memuat pembayaran...'),
      trailing: hasError
          ? TextButton(
              onPressed: () => ref.read(orderPaymentControllerProvider.notifier).refresh(),
              child: const Text('Coba lagi'),
            )
          : const CircularProgressIndicator(),
    ),
  );

  Widget _whatsAppActions(
    CustomerPaymentSummary summary,
    DateTimeRange range,
    String senderName,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      FilledButton.icon(
        onPressed: _openingWhatsApp
            ? null
            : () => _sendReport(summary, range, senderName),
        icon: const Icon(Icons.send_outlined),
        label: const Text('Kirim laporan via WhatsApp'),
      ),
      const SizedBox(height: 8),
      const Text(
        'WhatsApp membuka draf pesan. Periksa angka dan penerimanya sebelum menekan Kirim.',
        style: TextStyle(color: AppColors.secondaryText, fontSize: 12),
      ),
    ],
  );

  Future<void> _changePeriod(_PaymentPeriod period) async {
    if (period == _PaymentPeriod.custom) {
      final now = DateTime.now();
      final active = _rangeFor(_period);
      final selected = await showDateRangePicker(
        context: context,
        firstDate: DateTime(now.year - 3),
        lastDate: DateTime(now.year + 1, 12, 31),
        initialDateRange:
            _customRange ??
            DateTimeRange(
              start: active.start,
              end: active.end.subtract(const Duration(days: 1)),
            ),
        helpText: 'Pilih rentang laporan pembayaran',
        saveText: 'Terapkan',
      );
      if (selected == null || !mounted) return;
      setState(() {
        _period = period;
        _customRange = selected;
      });
      return;
    }
    setState(() => _period = period);
  }

  DateTimeRange _rangeFor(_PaymentPeriod period) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return switch (period) {
      _PaymentPeriod.today => DateTimeRange(
        start: today,
        end: today.add(const Duration(days: 1)),
      ),
      _PaymentPeriod.yesterday => DateTimeRange(
        start: today.subtract(const Duration(days: 1)),
        end: today,
      ),
      _PaymentPeriod.thisWeek => DateTimeRange(
        start: today.subtract(Duration(days: today.weekday - 1)),
        end: today
            .subtract(Duration(days: today.weekday - 1))
            .add(const Duration(days: 7)),
      ),
      _PaymentPeriod.thisMonth => DateTimeRange(
        start: DateTime(today.year, today.month),
        end: DateTime(today.year, today.month + 1),
      ),
      _PaymentPeriod.last3Months => DateTimeRange(
        start: DateTime(today.year, today.month - 2),
        end: DateTime(today.year, today.month + 1),
      ),
      _PaymentPeriod.last6Months => DateTimeRange(
        start: DateTime(today.year, today.month - 5),
        end: DateTime(today.year, today.month + 1),
      ),
      _PaymentPeriod.lastYear => DateTimeRange(
        start: DateTime(today.year - 1, today.month, today.day),
        end: today.add(const Duration(days: 1)),
      ),
      _PaymentPeriod.custom =>
        _customRange == null
            ? DateTimeRange(
                start: today,
                end: today.add(const Duration(days: 1)),
              )
            : DateTimeRange(
                start: DateTime(
                  _customRange!.start.year,
                  _customRange!.start.month,
                  _customRange!.start.day,
                ),
                end: DateTime(
                  _customRange!.end.year,
                  _customRange!.end.month,
                  _customRange!.end.day + 1,
                ),
              ),
    };
  }

  String _rangeLabel(DateTimeRange range) {
    final end = range.end.subtract(const Duration(days: 1));
    if (range.start.year == end.year &&
        range.start.month == end.month &&
        range.start.day == end.day) {
      return range.start.toIndonesianDate();
    }
    return '${range.start.toIndonesianDate()} - ${end.toIndonesianDate()}';
  }

  Future<void> _sendReport(
    CustomerPaymentSummary summary,
    DateTimeRange range,
    String senderName,
  ) async {
    setState(() => _openingWhatsApp = true);
    try {
      final user = ref.read(authControllerProvider).value?.user;
      String? ownerPhone;
      final client = ref.read(orderRepositoryProvider);
      if (client.isOnline &&
          user != null &&
          !user.shopId.startsWith('preview-shop')) {
        try {
          // Profiles are readable by members of the same shop through RLS.
          final rows = await SupabaseService.maybeClient!
              .from('profiles')
              .select('phone')
              .eq('shop_id', user.shopId)
              .eq('role', 'OWNER')
              .limit(5);
          ownerPhone = rows
              .map((row) => (row['phone'] ?? '').toString().trim())
              .where((phone) => phone.isNotEmpty)
              .firstOrNull;
        } catch (_) {
          // A report can still be shared by choosing the chat manually.
        }
      }
      final message = paymentReportWhatsAppMessage(
        period: _rangeLabel(range),
        senderName: senderName,
        summary: summary,
      );
      final phone = ownerPhone == null
          ? ''
          : PreviewDataController.normalizeIndonesianPhone(
              ownerPhone,
            ).replaceAll('+', '');
      final uri = phone.length >= 8
          ? Uri.https('wa.me', '/$phone', {'text': message})
          : Uri.https('api.whatsapp.com', '/send', {'text': message});
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (mounted && !opened) {
        showAppSnackBar('WhatsApp belum bisa dibuka. Coba lagi.');
      }
    } catch (_) {
      if (mounted) showAppSnackBar('Laporan belum bisa dibuka di WhatsApp.');
    } finally {
      if (mounted) setState(() => _openingWhatsApp = false);
    }
  }
}

String paymentReportWhatsAppMessage({
  required String period,
  required String senderName,
  required CustomerPaymentSummary summary,
}) {
  return 'Laporan pembayaran Idola Laundry\n'
      'Periode: $period\n'
      'Dibuat oleh: $senderName\n\n'
      'Tunai/Cash: ${summary.methods['Tunai'].toRupiah()}\n'
      'Transfer/TF: ${summary.methods['Transfer'].toRupiah()}\n'
      'QRIS: ${summary.methods['QRIS'].toRupiah()}\n'
      'Lainnya: ${summary.methods['Lainnya'].toRupiah()}\n'
      'Total diterima: ${summary.total.toRupiah()} '
      '(${summary.paymentCount} transaksi)\n\n'
      'Hybrid Tunai + Transfer: ${summary.hybridOrderCount} pesanan, '
      '${summary.hybridAmountInRange.toRupiah()} pada periode ini.\n'
      'Nominal Hybrid sudah termasuk dalam Tunai dan Transfer di atas; '
      'jangan dijumlahkan lagi.\n\n'
      'Mohon konfirmasi, terima kasih.';
}

enum _PaymentPeriod {
  today('Hari ini'),
  yesterday('Kemarin'),
  thisWeek('Minggu ini'),
  thisMonth('Bulan ini'),
  last3Months('3 bulan'),
  last6Months('6 bulan'),
  lastYear('1 tahun'),
  custom('Rentang');

  const _PaymentPeriod(this.label);
  final String label;
}
