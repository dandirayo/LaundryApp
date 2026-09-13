import 'package:flutter/material.dart';

import '../../../core/errors/failure.dart';
import '../../../core/extensions/currency_extensions.dart';
import '../../../core/extensions/date_time_extensions.dart';
import '../../../core/extensions/quantity_extensions.dart';
import '../../../core/services/bluetooth_receipt_printer.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/ui_action_queue.dart';
import '../../../core/widgets/app_bottom_sheet_body.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../shared/preview_data.dart';

enum ReceiptCopyType { customer, laundryLabel, pickup }

extension ReceiptCopyTypeLabel on ReceiptCopyType {
  String get label => switch (this) {
    ReceiptCopyType.customer => 'Nota Pelanggan',
    ReceiptCopyType.laundryLabel => 'Label Cucian',
    ReceiptCopyType.pickup => 'Bukti Pengambilan',
  };
}

Future<void> showReceiptPreviewSheet({
  required BuildContext context,
  required PreviewOrder order,
  required List<PreviewPayment> payments,
  required String shopName,
  required String shopAddress,
  required String employeeName,
  List<ReceiptCopyType> copies = ReceiptCopyType.values,
  ReceiptCopyType? initialCopy,
}) {
  assert(copies.isNotEmpty);
  var paperWidth = 80;
  var selectedCopy = initialCopy != null && copies.contains(initialCopy)
      ? initialCopy
      : copies.first;
  var printing = false;

  return showAppModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setModalState) => AppBottomSheetBody(
        children: [
          Text(
            'Cetak Nota Thermal',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            copies.contains(ReceiptCopyType.laundryLabel) && copies.length > 1
                ? 'Cetak nota pelanggan dan label cucian secara bergantian.'
                : 'Periksa isi dan ukuran kertas sebelum mencetak.',
            style: const TextStyle(color: AppColors.secondaryText),
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<ReceiptCopyType>(
              segments: [
                for (final copy in copies)
                  ButtonSegment(value: copy, label: Text(copy.label)),
              ],
              selected: {selectedCopy},
              showSelectedIcon: false,
              onSelectionChanged: (value) =>
                  setModalState(() => selectedCopy = value.first),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Ukuran printer',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 80, label: Text('80 mm')),
                  ButtonSegment(value: 58, label: Text('58 mm')),
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
            copy: selectedCopy,
            order: order,
            shopName: shopName,
            shopAddress: shopAddress,
            employeeName: employeeName,
          ),
          const SizedBox(height: 12),
          if (copies.contains(ReceiptCopyType.customer) &&
              copies.contains(ReceiptCopyType.laundryLabel)) ...[
            FilledButton.icon(
              onPressed: printing
                  ? null
                  : () async {
                      setModalState(() => printing = true);
                      try {
                        await BluetoothReceiptPrinter.instance.printLines(
                          standardReceiptLines(
                            order: order,
                            copy: ReceiptCopyType.customer,
                            shopName: shopName,
                            shopAddress: shopAddress,
                            employeeName: employeeName,
                            paperWidth: paperWidth,
                          ),
                          paperWidth: paperWidth,
                          logoAsset: 'assets/images/idola_one_logo.png',
                        );
                        await BluetoothReceiptPrinter.instance.printStyledLines(
                          laundryLabelLines(order),
                          paperWidth: paperWidth,
                        );
                        showAppSnackBar(
                          'Nota pelanggan dan label cucian dikirim ke printer.',
                        );
                      } catch (error) {
                        showAppSnackBar(
                          error is Failure
                              ? error.message
                              : 'Gagal mengirim cetakan. Periksa printer sebelum mencoba lagi.',
                        );
                      } finally {
                        if (context.mounted) {
                          setModalState(() => printing = false);
                        }
                      }
                    },
              icon: const Icon(Icons.copy_all_outlined),
              label: Text(
                printing ? 'Mengirim...' : 'Cetak Nota + Label (2 Lembar)',
              ),
            ),
            const SizedBox(height: 8),
          ],
          OutlinedButton.icon(
            onPressed: printing
                ? null
                : () async {
                    setModalState(() => printing = true);
                    try {
                      if (selectedCopy == ReceiptCopyType.laundryLabel) {
                        await BluetoothReceiptPrinter.instance.printStyledLines(
                          laundryLabelLines(order),
                          paperWidth: paperWidth,
                        );
                      } else {
                        await BluetoothReceiptPrinter.instance.printLines(
                          standardReceiptLines(
                            order: order,
                            copy: selectedCopy,
                            shopName: shopName,
                            shopAddress: shopAddress,
                            employeeName: employeeName,
                            paperWidth: paperWidth,
                          ),
                          paperWidth: paperWidth,
                          logoAsset: 'assets/images/idola_one_logo.png',
                        );
                      }
                      showAppSnackBar(
                        '${selectedCopy.label} dikirim. Periksa hasil pada printer.',
                      );
                    } catch (error) {
                      showAppSnackBar(
                        error is Failure
                            ? error.message
                            : 'Gagal mengirim cetakan. Periksa printer sebelum mencoba lagi.',
                      );
                    } finally {
                      if (context.mounted) {
                        setModalState(() => printing = false);
                      }
                    }
                  },
            icon: const Icon(Icons.print_outlined),
            label: Text(
              printing ? 'Mengirim...' : 'Cetak ${selectedCopy.label}',
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.check),
            label: const Text('Selesai'),
          ),
        ],
      ),
    ),
  );
}

List<String> standardReceiptLines({
  required PreviewOrder order,
  required ReceiptCopyType copy,
  required String shopName,
  required String shopAddress,
  required String employeeName,
  required int paperWidth,
}) {
  final separator = '-' * (paperWidth == 80 ? 48 : 32);
  final heading = copy == ReceiptCopyType.pickup
      ? 'TANDA TERIMA PENGAMBILAN'
      : order.remainingAmount == 0
      ? 'NOTA LUNAS'
      : 'NOTA PESANAN';
  return [
    'IDOLA LAUNDRY',
    shopName.toUpperCase(),
    shopAddress,
    heading,
    separator,
    'No. Nota: ${order.orderNumber}',
    'Tgl Masuk: ${order.receivedAt.toIndonesianDate()} ${order.receivedAt.toIndonesianTime()}',
    'Pelanggan: ${order.customerNameSnapshot}',
    'Kasir: $employeeName',
    separator,
    for (final item in order.items) ...[
      item.serviceNameSnapshot,
      '${formatQuantityForUnit(item.quantity, item.unit)} x ${item.price.toRupiah()}',
      'Jumlah: ${item.total.toRupiah()}',
    ],
    if (order.note.trim().isNotEmpty) ...[
      separator,
      'CATATAN: ${order.note.trim()}',
    ],
    separator,
    if (order.roundingAdjustment != 0) ...[
      'Subtotal: ${order.itemSubtotal.toRupiah()}',
      'Pembulatan: ${_signedAmount(order.roundingAdjustment)}',
    ],
    'Total: ${order.totalPrice.toRupiah()}',
    'Dibayar: ${order.paidAmount.toRupiah()}',
    'Sisa: ${order.remainingAmount.toRupiah()}',
    'Status Bayar: ${order.paymentStatus.label.toUpperCase()}',
    if (copy == ReceiptCopyType.pickup) 'Status Barang: SUDAH DIAMBIL',
    separator,
    copy == ReceiptCopyType.pickup
        ? 'Bukti barang telah diterima pelanggan.'
        : 'Simpan nota ini sebagai bukti pesanan.',
  ];
}

List<ThermalPrintLine> laundryLabelLines(PreviewOrder order) {
  final itemSummary = order.items
      .map(
        (item) =>
            '${formatQuantityForUnit(item.quantity, item.unit)} ${item.serviceNameSnapshot}',
      )
      .join(' / ');
  return [
    const ThermalPrintLine(
      'LABEL CUCIAN',
      bold: true,
      large: true,
      align: ThermalTextAlign.center,
    ),
    ThermalPrintLine(
      order.orderNumber,
      bold: true,
      large: true,
      align: ThermalTextAlign.center,
    ),
    ThermalPrintLine(
      order.customerNameSnapshot.toUpperCase(),
      bold: true,
      large: true,
      align: ThermalTextAlign.center,
    ),
    const ThermalPrintLine('--------------------------------'),
    ThermalPrintLine('BERAT/JUMLAH: $itemSummary', bold: true, large: true),
    ThermalPrintLine(
      'BAYAR: ${order.paymentStatus.label.toUpperCase()}',
      bold: true,
      large: true,
    ),
    ThermalPrintLine('SISA: ${order.remainingAmount.toRupiah()}', bold: true),
    if (order.note.trim().isNotEmpty) ...[
      const ThermalPrintLine('CATATAN:', bold: true, large: true),
      ThermalPrintLine(
        order.note.trim().toUpperCase(),
        bold: true,
        large: true,
      ),
    ],
  ];
}

String _signedAmount(int amount) =>
    '${amount > 0 ? '+' : '-'}${amount.abs().toRupiah()}';

class _ReceiptPaper extends StatelessWidget {
  const _ReceiptPaper({
    required this.paperWidth,
    required this.copy,
    required this.order,
    required this.shopName,
    required this.shopAddress,
    required this.employeeName,
  });

  final int paperWidth;
  final ReceiptCopyType copy;
  final PreviewOrder order;
  final String shopName;
  final String shopAddress;
  final String employeeName;

  @override
  Widget build(BuildContext context) {
    final previewWidth = paperWidth == 58 ? 296.0 : 380.0;
    return LayoutBuilder(
      builder: (context, constraints) => Align(
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
              maxHeight: 540,
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
                child: copy == ReceiptCopyType.laundryLabel
                    ? _LaundryLabelPreview(order: order)
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Icon(
                            Icons.local_laundry_service_outlined,
                            size: 48,
                          ),
                          const SizedBox(height: 6),
                          for (final line in standardReceiptLines(
                            order: order,
                            copy: copy,
                            shopName: shopName,
                            shopAddress: shopAddress,
                            employeeName: employeeName,
                            paperWidth: paperWidth,
                          ))
                            Text(line),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LaundryLabelPreview extends StatelessWidget {
  const _LaundryLabelPreview({required this.order});

  final PreviewOrder order;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final line in laundryLabelLines(order))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              line.text,
              textAlign: switch (line.align) {
                ThermalTextAlign.left => TextAlign.left,
                ThermalTextAlign.center => TextAlign.center,
                ThermalTextAlign.right => TextAlign.right,
              },
              style: TextStyle(
                fontSize: line.large ? 20 : 12,
                fontWeight: line.bold ? FontWeight.w900 : FontWeight.w400,
                height: 1.15,
              ),
            ),
          ),
      ],
    );
  }
}
