import 'package:flutter/material.dart';
import '../../../core/services/bluetooth_receipt_printer.dart';
import '../../../core/errors/failure.dart';

import '../../../core/extensions/currency_extensions.dart';
import '../../../core/extensions/date_time_extensions.dart';
import '../../../core/extensions/quantity_extensions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/ui_action_queue.dart';
import '../../../core/widgets/app_bottom_sheet_body.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../shared/preview_data.dart';

String _signedAmount(int amount) =>
    '${amount > 0 ? '+' : '-'}${amount.abs().toRupiah()}';

Future<void> showReceiptPreviewSheet({
  required BuildContext context,
  required PreviewOrder order,
  required List<PreviewPayment> payments,
  required String shopName,
  required String shopAddress,
  required String employeeName,
}) {
  var paperWidth = 80;
  var printing = false;
  return showAppModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          return AppBottomSheetBody(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Preview Struk Thermal',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 80, label: Text('80')),
                      ButtonSegment(value: 58, label: Text('58')),
                    ],
                    selected: {paperWidth},
                    showSelectedIcon: false,
                    onSelectionChanged: (value) =>
                        setModalState(() => paperWidth = value.first),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _ReceiptPaper(
                paperWidth: paperWidth,
                order: order,
                payments: payments,
                shopName: shopName,
                shopAddress: shopAddress,
                employeeName: employeeName,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: printing
                    ? null
                    : () async {
                        setModalState(() => printing = true);
                        try {
                          await BluetoothReceiptPrinter.instance.printLines(
                            [
                              'IDOLA LAUNDRY',
                              shopName.toUpperCase(),
                              shopAddress,
                              order.remainingAmount == 0
                                  ? 'NOTA LUNAS'
                                  : 'NOTA PEMBAYARAN',
                              '-' * (paperWidth == 80 ? 48 : 32),
                              'No. Nota: ${order.orderNumber}',
                              'Tgl Masuk: ${order.receivedAt.toIndonesianDate()} ${order.receivedAt.toIndonesianTime()}',
                              'Pelanggan: ${order.customerNameSnapshot}',
                              'Kasir: $employeeName',
                              '-' * (paperWidth == 80 ? 48 : 32),
                              for (final item in order.items) ...[
                                item.serviceNameSnapshot,
                                '${formatQuantityForUnit(item.quantity, item.unit)} x ${item.price.toRupiah()}',
                                'Jumlah: ${item.total.toRupiah()}',
                              ],
                              '-' * (paperWidth == 80 ? 48 : 32),
                              if (order.roundingAdjustment != 0) ...[
                                'Subtotal: ${order.itemSubtotal.toRupiah()}',
                                'Pembulatan: ${_signedAmount(order.roundingAdjustment)}',
                              ],
                              'Total: ${order.totalPrice.toRupiah()}',
                              'Dibayar: ${order.paidAmount.toRupiah()}',
                              'Sisa: ${order.remainingAmount.toRupiah()}',
                              'Status: ${order.paymentStatus.label}',
                              'Terima Kasih Atas Kepercayaan Anda',
                              'Harap simpan nota ini sebagai bukti pengambilan.',
                            ],
                            paperWidth: paperWidth,
                            logoAsset: 'assets/images/idola_one_logo.png',
                          );
                          showAppSnackBar(
                            'Struk dikirim. Periksa hasil pada printer.',
                          );
                        } catch (error) {
                          showAppSnackBar(
                            error is Failure
                                ? error.message
                                : 'Gagal mengirim struk. Periksa printer sebelum mencoba lagi.',
                          );
                        } finally {
                          if (context.mounted) {
                            setModalState(() => printing = false);
                          }
                        }
                      },
                icon: const Icon(Icons.print_outlined),
                label: Text(
                  printing ? 'Mengirim...' : 'Cetak ke Printer Thermal',
                ),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Lanjut'),
              ),
            ],
          );
        },
      );
    },
  );
}

class _ReceiptPaper extends StatelessWidget {
  const _ReceiptPaper({
    required this.paperWidth,
    required this.order,
    required this.payments,
    required this.shopName,
    required this.shopAddress,
    required this.employeeName,
  });

  final int paperWidth;
  final PreviewOrder order;
  final List<PreviewPayment> payments;
  final String shopName;
  final String shopAddress;
  final String employeeName;

  @override
  Widget build(BuildContext context) {
    final paid = order.paidAmount;
    final previewWidth = paperWidth == 58 ? 296.0 : 380.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Align(
          alignment: Alignment.center,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppColors.outline),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x22000000),
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: constraints.maxWidth,
                minWidth: previewWidth > constraints.maxWidth
                    ? constraints.maxWidth
                    : previewWidth,
                maxHeight: 620,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: DefaultTextStyle(
                  style: const TextStyle(
                    color: Colors.black,
                    fontFamily: 'monospace',
                    fontSize: 12,
                    height: 1.25,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Image.asset(
                          'assets/images/idola_one_logo.png',
                          width: paperWidth == 80 ? 96 : 74,
                          height: paperWidth == 80 ? 96 : 74,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.local_laundry_service_outlined,
                            size: 56,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      _center('IDOLA LAUNDRY', bold: true),
                      _center(shopName.toUpperCase(), bold: true),
                      _center(shopAddress),
                      const SizedBox(height: 4),
                      _center(
                        order.remainingAmount == 0
                            ? 'NOTA LUNAS'
                            : 'NOTA PEMBAYARAN',
                        bold: true,
                      ),
                      _line(),
                      _row('No. Nota', order.orderNumber),
                      _row(
                        'Tgl Masuk',
                        '${order.receivedAt.toIndonesianDate()} ${order.receivedAt.toIndonesianTime()}',
                      ),
                      _row('Pelanggan', order.customerNameSnapshot),
                      _row('Kasir', employeeName),
                      _line(),
                      for (final item in order.items) ...[
                        Text(item.serviceNameSnapshot),
                        _row(
                          '${formatQuantityForUnit(item.quantity, item.unit)} x ${item.price.toRupiah()}',
                          item.total.toRupiah(),
                        ),
                      ],
                      _line(),
                      if (order.roundingAdjustment != 0) ...[
                        _row('Subtotal', order.itemSubtotal.toRupiah()),
                        _row(
                          'Pembulatan',
                          _signedRupiah(order.roundingAdjustment),
                        ),
                      ],
                      _row('TOTAL', order.totalPrice.toRupiah(), bold: true),
                      _row('Dibayar', paid.toRupiah()),
                      _row('Sisa', order.remainingAmount.toRupiah()),
                      _row('Status', order.paymentStatus.label),
                      _line(),
                      _center('Terima Kasih Atas Kepercayaan Anda'),
                      _center(
                        'Harap simpan nota ini sebagai bukti pengambilan.',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _signedRupiah(int amount) {
    if (amount == 0) return amount.toRupiah();
    return '${amount > 0 ? '+' : '-'}${amount.abs().toRupiah()}';
  }

  Widget _center(String text, {bool bold = false}) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w400),
    );
  }

  Widget _line() {
    final charCount = paperWidth == 58 ? 32 : 48;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text('-' * charCount),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 2, child: Text(label)),
          const Text(' : '),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: bold ? FontWeight.w800 : FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
