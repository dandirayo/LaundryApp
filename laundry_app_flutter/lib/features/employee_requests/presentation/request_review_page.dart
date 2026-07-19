import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/extensions/currency_extensions.dart';
import '../../../core/extensions/date_time_extensions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/ui_action_queue.dart';
import '../../../core/widgets/app_bottom_sheet_body.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import '../../../core/widgets/responsive_page.dart';
import '../../../shared/preview_data.dart';

class RequestReviewPage extends ConsumerStatefulWidget {
  const RequestReviewPage({super.key});

  @override
  ConsumerState<RequestReviewPage> createState() => _RequestReviewPageState();
}

class _RequestReviewPageState extends ConsumerState<RequestReviewPage> {
  PreviewRequestStatus? _statusFilter;

  @override
  Widget build(BuildContext context) {
    final allRequests = ref.watch(
      previewDataProvider.select((state) => state.requests),
    );
    final requests = allRequests.where((request) {
      return _statusFilter == null || request.status == _statusFilter;
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Review Request')),
      body: ResponsivePage(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: const Text('Semua'),
                      selected: _statusFilter == null,
                      onSelected: (_) => setState(() => _statusFilter = null),
                    ),
                  ),
                  for (final status in PreviewRequestStatus.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(status.label),
                        selected: _statusFilter == status,
                        onSelected: (_) =>
                            setState(() => _statusFilter = status),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: requests.isEmpty
                  ? const AppStateView.empty(
                      title: 'Tidak ada request',
                      message:
                          'Request karyawan yang masuk akan tampil untuk ditinjau Owner.',
                    )
                  : ListView.separated(
                      itemCount: requests.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final request = requests[index];
                        return _RequestReviewCard(
                          request: request,
                          onApprove: () => _reviewRequest(
                            request,
                            PreviewRequestStatus.approved,
                          ),
                          onReject: () => _reviewRequest(
                            request,
                            PreviewRequestStatus.rejected,
                          ),
                          onPay: () => _payRequest(request),
                          onComplete: () => _completeRequest(request),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _reviewRequest(
    PreviewEmployeeRequest request,
    PreviewRequestStatus status,
  ) async {
    final note = await _showReviewNoteSheet(
      context,
      title: status == PreviewRequestStatus.approved
          ? 'Catatan Persetujuan'
          : 'Alasan Penolakan',
      requireNote: status == PreviewRequestStatus.rejected,
    );
    if (note == null || !mounted) {
      return;
    }
    await waitForTransientUiDismissal();
    if (!mounted) {
      return;
    }
    final confirmed = await showConfirmationDialog(
      context,
      title: status == PreviewRequestStatus.approved
          ? 'Setujui request?'
          : 'Tolak request?',
      message:
          '${request.type} dari ${request.employeeName} akan '
          '${status == PreviewRequestStatus.approved ? 'disetujui' : 'ditolak'}.',
      confirmLabel: status == PreviewRequestStatus.approved
          ? 'Setujui'
          : 'Tolak',
      isDestructive: status == PreviewRequestStatus.rejected,
    );
    if (!confirmed || !mounted) {
      return;
    }
    await waitForTransientUiDismissal();
    if (!mounted) {
      return;
    }
    try {
      ref
          .read(previewDataProvider.notifier)
          .reviewRequest(request.id, status, reviewNote: note);
      _showMessage('Request ${status.label.toLowerCase()}.');
    } on StateError catch (error) {
      _showMessage(error.message);
    }
  }

  Future<void> _payRequest(PreviewEmployeeRequest request) async {
    final method = await _showPaymentMethodSheet(context);
    if (method == null || !mounted) {
      return;
    }
    await waitForTransientUiDismissal();
    if (!mounted) {
      return;
    }
    final confirmed = await showConfirmationDialog(
      context,
      title: 'Bayar request?',
      message:
          '${request.type} senilai ${request.amount.toRupiah()} akan dicatat sebagai uang keluar.',
      confirmLabel: 'Bayar',
    );
    if (!confirmed || !mounted) {
      return;
    }
    await waitForTransientUiDismissal();
    if (!mounted) {
      return;
    }
    try {
      ref
          .read(previewDataProvider.notifier)
          .payEmployeeRequest(requestId: request.id, method: method);
      _showMessage('Pembayaran request masuk Buku Kas.');
    } on StateError catch (error) {
      _showMessage(error.message);
    }
  }

  Future<void> _completeRequest(PreviewEmployeeRequest request) async {
    final confirmed = await showConfirmationDialog(
      context,
      title: 'Tandai selesai?',
      message:
          '${request.type} dari ${request.employeeName} akan diselesaikan.',
      confirmLabel: 'Selesai',
    );
    if (!confirmed || !mounted) {
      return;
    }
    await waitForTransientUiDismissal();
    if (!mounted) {
      return;
    }
    try {
      ref.read(previewDataProvider.notifier).completeRequest(request.id);
      _showMessage('Request ditandai selesai.');
    } on StateError catch (error) {
      _showMessage(error.message);
    }
  }

  Future<String?> _showReviewNoteSheet(
    BuildContext context, {
    required String title,
    required bool requireNote,
  }) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final result = await showAppModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Form(
        key: formKey,
        child: AppBottomSheetBody(
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: controller,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: requireNote ? 'Catatan wajib' : 'Catatan opsional',
              ),
              validator: (value) {
                if (requireNote && (value ?? '').trim().isEmpty) {
                  return 'Catatan wajib diisi.';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                if (!formKey.currentState!.validate()) {
                  return;
                }
                Navigator.of(context).pop(controller.text.trim());
              },
              icon: const Icon(Icons.check),
              label: const Text('Lanjut'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    return result;
  }

  Future<String?> _showPaymentMethodSheet(BuildContext context) async {
    var method = 'Tunai';
    return showAppModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AppBottomSheetBody(
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
    );
  }

  void _showMessage(String message) {
    showAppSnackBar(message);
  }
}

class _RequestReviewCard extends StatelessWidget {
  const _RequestReviewCard({
    required this.request,
    required this.onApprove,
    required this.onReject,
    required this.onPay,
    required this.onComplete,
  });

  final PreviewEmployeeRequest request;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onPay;
  final VoidCallback onComplete;

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
                    request.type,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
                _StatusBadge(status: request.status),
              ],
            ),
            const SizedBox(height: 6),
            Text(request.reason),
            const SizedBox(height: 6),
            Text(
              '${request.employeeName} - ${request.createdAt.toIndonesianDate()} ${request.createdAt.toIndonesianTime()}',
              style: const TextStyle(color: AppColors.secondaryText),
            ),
            if (request.amount > 0) ...[
              const SizedBox(height: 6),
              Text(
                request.amount.toRupiah(),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
            if (request.reviewNote.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                request.reviewNote,
                style: const TextStyle(color: AppColors.secondaryText),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (request.status == PreviewRequestStatus.pending) ...[
                  FilledButton.icon(
                    onPressed: onApprove,
                    icon: const Icon(Icons.check),
                    label: const Text('Setujui'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onReject,
                    icon: const Icon(Icons.close),
                    label: const Text('Tolak'),
                  ),
                ],
                if (request.status == PreviewRequestStatus.approved) ...[
                  if (request.amount > 0)
                    FilledButton.icon(
                      onPressed: onPay,
                      icon: const Icon(Icons.payments_outlined),
                      label: const Text('Bayar'),
                    )
                  else
                    FilledButton.icon(
                      onPressed: onComplete,
                      icon: const Icon(Icons.task_alt),
                      label: const Text('Selesaikan'),
                    ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final PreviewRequestStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      PreviewRequestStatus.pending => AppColors.warning,
      PreviewRequestStatus.approved => AppColors.primaryBlue,
      PreviewRequestStatus.rejected => AppColors.error,
      PreviewRequestStatus.paid => AppColors.success,
      PreviewRequestStatus.completed => AppColors.success,
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          status.label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
