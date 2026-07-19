import 'package:flutter/material.dart';

import '../../../core/extensions/currency_extensions.dart';
import '../../../core/extensions/date_time_extensions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/ui_action_queue.dart';
import '../../../core/widgets/app_bottom_sheet_body.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../shared/preview_data.dart';

Future<void> showReceiptPreviewSheet({
  required BuildContext context,
  required PreviewOrder order,
  required List<PreviewPayment> payments,
  required String shopName,
  required String shopAddress,
  required String employeeName,
}) {
  var paperWidth = 58;
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
                      ButtonSegment(value: 58, label: Text('58')),
                      ButtonSegment(value: 80, label: Text('80')),
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
                onPressed: () => showAppSnackBar(
                  'Preview siap. Cetak fisik menunggu plugin printer thermal.',
                ),
                icon: const Icon(Icons.print_outlined),
                label: const Text('Cetak ke Printer Thermal'),
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
    final paid = payments.fold<int>(0, (sum, payment) => sum + payment.amount);
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
                      _center(shopName.toUpperCase(), bold: true),
                      _center(shopAddress),
                      _line(),
                      _row('No', order.orderNumber),
                      _row(
                        'Masuk',
                        '${order.receivedAt.toIndonesianDate()} ${order.receivedAt.toIndonesianTime()}',
                      ),
                      _row('Pelanggan', order.customerNameSnapshot),
                      _row('Petugas', employeeName),
                      _line(),
                      for (final item in order.items) ...[
                        Text(item.serviceNameSnapshot),
                        _row(
                          '${item.quantity.toStringAsFixed(1)} ${item.unit} x ${item.price.toRupiah()}',
                          item.total.toRupiah(),
                        ),
                      ],
                      _line(),
                      _row('Total', order.totalPrice.toRupiah(), bold: true),
                      _row('Dibayar', paid.toRupiah()),
                      _row('Sisa', order.remainingAmount.toRupiah()),
                      _row('Status', order.paymentStatus.label),
                      _line(),
                      _center('Terima kasih'),
                      _center('Simpan struk ini sebagai bukti.'),
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

  Widget _center(String text, {bool bold = false}) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w400),
    );
  }

  Widget _line() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Text('--------------------------------'),
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
