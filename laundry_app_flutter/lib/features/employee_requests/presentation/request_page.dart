import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/extensions/currency_extensions.dart';
import '../../../core/extensions/date_time_extensions.dart';
import '../../../core/utils/ui_action_queue.dart';
import '../../../core/widgets/app_bottom_sheet_body.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../core/widgets/responsive_page.dart';
import '../../../shared/preview_data.dart';

class RequestPage extends ConsumerWidget {
  const RequestPage({required this.typeLabel, super.key});

  final String typeLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref
        .watch(previewDataProvider.select((state) => state.requests))
        .where((request) => request.type == typeLabel)
        .toList();

    return Scaffold(
      appBar: AppBar(title: Text(typeLabel)),
      floatingActionButton: requests.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _showRequestSheet(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Request'),
            ),
      body: ResponsivePage(
        padding: EdgeInsets.fromLTRB(16, 8, 16, requests.isEmpty ? 24 : 96),
        child: requests.isEmpty
            ? AppStateView.empty(
                title: '$typeLabel belum ada',
                message:
                    'Ajukan request agar Owner dapat meninjau dan memberi keputusan.',
                actionLabel: 'Buat request',
                onAction: () => _showRequestSheet(context, ref),
              )
            : ListView.separated(
                itemCount: requests.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final request = requests[index];
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.pending_actions_outlined),
                      title: Text(request.reason),
                      subtitle: Text(
                        '${request.employeeName} - ${request.createdAt.toIndonesianDate()} ${request.createdAt.toIndonesianTime()}',
                      ),
                      trailing: Text(
                        request.status.label,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Future<void> _showRequestSheet(BuildContext context, WidgetRef ref) async {
    final reason = TextEditingController();
    final amount = TextEditingController(text: _isStockRequest ? '1' : '0');
    final formKey = GlobalKey<FormState>();
    final requiresMoney =
        typeLabel.contains('Kasbon') || typeLabel.contains('Insentif');
    final requiresQuantity = _isStockRequest;
    final showAmountField = requiresMoney || requiresQuantity;
    final result = await showAppModalBottomSheet<_RequestInput>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Form(
        key: formKey,
        child: AppBottomSheetBody(
          children: [
            Text(
              typeLabel,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: reason,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Alasan'),
              validator: (value) =>
                  (value ?? '').trim().isEmpty ? 'Alasan wajib diisi.' : null,
            ),
            const SizedBox(height: 12),
            if (showAmountField) ...[
              TextFormField(
                controller: amount,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: requiresQuantity ? 'Quantity' : 'Nominal',
                  helperText: requiresQuantity
                      ? 'Masukkan jumlah barang yang diminta.'
                      : (int.tryParse(amount.text) ?? 0).toRupiah(),
                ),
                validator: (value) {
                  final parsed = int.tryParse(value ?? '') ?? 0;
                  if (parsed < 0) {
                    return requiresQuantity
                        ? 'Quantity tidak boleh negatif.'
                        : 'Nominal tidak boleh negatif.';
                  }
                  if ((requiresMoney || requiresQuantity) && parsed <= 0) {
                    return requiresQuantity
                        ? 'Quantity wajib lebih dari nol.'
                        : 'Nominal wajib lebih dari nol.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
            ],
            FilledButton.icon(
              onPressed: () {
                if (!formKey.currentState!.validate()) {
                  return;
                }
                Navigator.of(context).pop(
                  _RequestInput(
                    reason: reason.text,
                    amount: int.tryParse(amount.text) ?? 0,
                  ),
                );
              },
              icon: const Icon(Icons.send_outlined),
              label: const Text('Kirim Request'),
            ),
          ],
        ),
      ),
    );
    reason.dispose();
    amount.dispose();

    if (result == null || !context.mounted) {
      return;
    }
    await waitForTransientUiDismissal();
    if (!context.mounted) {
      return;
    }
    ref
        .read(previewDataProvider.notifier)
        .addRequest(
          type: typeLabel,
          reason: result.reason,
          amount: result.amount,
        );
    showAppSnackBar('Request dikirim ke Owner.');
  }

  bool get _isStockRequest => typeLabel.contains('Stok');
}

class _RequestInput {
  const _RequestInput({required this.reason, required this.amount});

  final String reason;
  final int amount;
}
