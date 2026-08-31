import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/user_error_message.dart';
import '../../../core/extensions/currency_extensions.dart';
import '../../../core/extensions/date_time_extensions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/ui_action_queue.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../core/widgets/responsive_page.dart';
import '../../../shared/preview_data.dart';
import '../../auth/domain/app_user.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/request_kind.dart';
import 'employee_request_controller.dart';
import 'request_form_sheet.dart';

class RequestPage extends ConsumerStatefulWidget {
  const RequestPage({this.initialType, super.key});

  final String? initialType;

  @override
  ConsumerState<RequestPage> createState() => _RequestPageState();
}

class _RequestPageState extends ConsumerState<RequestPage> {
  String _statusFilter = 'Semua';
  RequestCategory? _categoryFilter;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _categoryFilter = requestCategory(widget.initialType ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).value?.user;
    final preview = ref.watch(
      previewDataProvider.select(
        (state) => (requests: state.requests, employees: state.employees),
      ),
    );
    final requestState = ref.watch(employeeRequestControllerProvider);
    final employee = _resolveCurrentEmployee(preview.employees, user);
    final employeeId = employee?.id ?? user?.employeeId;
    final allRequests = (requestState.value?.requests ?? preview.requests)
        .where(
          (request) => employeeId == null || request.employeeId == employeeId,
        )
        .toList();
    final requests = allRequests.where((request) {
      final statusMatches =
          _statusFilter == 'Semua' ||
          request.status.label == _statusFilter ||
          (_statusFilter == 'Selesai' &&
              request.status == PreviewRequestStatus.paid);
      final typeMatches =
          _categoryFilter == null ||
          requestCategory(request.type) == _categoryFilter;
      return statusMatches && typeMatches;
    }).toList();
    final pendingCount = allRequests
        .where((item) => item.status == PreviewRequestStatus.pending)
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengajuan Saya'),
        actions: [
          IconButton(
            tooltip: 'Muat ulang pengajuan',
            onPressed: requestState.isLoading
                ? null
                : () => ref
                      .read(employeeRequestControllerProvider.notifier)
                      .refresh(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isSubmitting
            ? null
            : () => _showRequestSheet(context, employee: employee),
        icon: const Icon(Icons.add),
        label: Text(_isSubmitting ? 'Mengirim…' : 'Buat Pengajuan'),
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(employeeRequestControllerProvider.notifier).refresh(),
        child: ResponsivePage(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _RequestSummary(
                  total: allRequests.length,
                  pending: pendingCount,
                  isOnline: requestState.value?.isOnline ?? false,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 14)),
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final status in const [
                            'Semua',
                            'Pending',
                            'Disetujui',
                            'Ditolak',
                            'Dibayar',
                            'Selesai',
                          ])
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text(status),
                                selected: _statusFilter == status,
                                onSelected: (_) =>
                                    setState(() => _statusFilter = status),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<RequestCategory?>(
                      key: ValueKey(_categoryFilter),
                      initialValue: _categoryFilter,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Kategori pengajuan',
                        prefixIcon: Icon(Icons.tune),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('Semua kategori'),
                        ),
                        for (final category in RequestCategory.values)
                          DropdownMenuItem(
                            value: category,
                            child: Text(category.label),
                          ),
                      ],
                      onChanged: (value) =>
                          setState(() => _categoryFilter = value),
                    ),
                  ],
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 14)),
              if (requestState.hasError)
                SliverToBoxAdapter(
                  child: AppStateView.error(
                    title: 'Pengajuan belum dapat dimuat',
                    message: userErrorMessage(
                      requestState.error,
                      fallback: 'Pengajuan belum dapat dimuat. Coba lagi.',
                    ),
                    actionLabel: 'Coba lagi',
                    onAction: () => ref
                        .read(employeeRequestControllerProvider.notifier)
                        .refresh(),
                  ),
                )
              else if (requestState.isLoading && allRequests.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (requests.isEmpty)
                SliverToBoxAdapter(
                  child: AppStateView.empty(
                    title: allRequests.isEmpty
                        ? 'Belum ada pengajuan'
                        : 'Pengajuan tidak ditemukan',
                    message: allRequests.isEmpty
                        ? 'Ajukan kebutuhan stok, izin dan jadwal, atau dana dan biaya dari satu halaman.'
                        : 'Ubah filter untuk melihat pengajuan lainnya.',
                    actionLabel: allRequests.isEmpty ? 'Buat pengajuan' : null,
                    onAction: allRequests.isEmpty
                        ? () => _showRequestSheet(context, employee: employee)
                        : null,
                  ),
                )
              else
                SliverList.separated(
                  itemCount: requests.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) =>
                      _RequestCard(request: requests[index]),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showRequestSheet(
    BuildContext context, {
    required PreviewEmployee? employee,
  }) async {
    if (_isSubmitting) return;
    final user = ref.read(authControllerProvider).value?.user;
    final currentEmployee =
        employee ??
        _resolveCurrentEmployee(ref.read(previewDataProvider).employees, user);
    if (currentEmployee == null) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Akun belum terhubung'),
          content: const Text(
            'Minta Owner membuka menu Tim, lalu pastikan akun login terhubung ke karyawan aktif.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Mengerti'),
            ),
          ],
        ),
      );
      return;
    }

    final initialKind = RequestKind.fromStorage(widget.initialType);
    final result = await showAppModalBottomSheet<RequestSubmission>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => RequestFormSheet(
        initialType: initialKind?.category == _categoryFilter
            ? initialKind?.storageValue
            : switch (_categoryFilter) {
                RequestCategory.schedule => RequestKind.leave.storageValue,
                RequestCategory.funds => RequestKind.cashAdvance.storageValue,
                _ => RequestKind.stock.storageValue,
              },
      ),
    );
    if (result == null || !context.mounted) return;
    await waitForTransientUiDismissal();
    if (!context.mounted) return;
    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(employeeRequestControllerProvider.notifier)
          .addRequest(
            type: result.kind.storageValue,
            reason: result.summary,
            amount: result.amount,
            employeeId: currentEmployee.id,
            employeeName: currentEmployee.name,
          );
      if (mounted) {
        setState(() {
          _categoryFilter = result.kind.category;
          _statusFilter = 'Semua';
        });
        showAppSnackBar('Pengajuan dikirim ke Owner.');
      }
    } catch (error) {
      if (context.mounted) {
        showAppSnackBar(
          userErrorMessage(
            error,
            fallback: 'Pengajuan gagal dikirim. Periksa data lalu coba lagi.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}

class _RequestSummary extends StatelessWidget {
  const _RequestSummary({
    required this.total,
    required this.pending,
    required this.isOnline,
  });

  final int total;
  final int pending;
  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.rule_folder_outlined, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$pending menunggu keputusan',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    '$total pengajuan - ${isOnline ? 'Tersinkron' : 'Mode lokal'}',
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

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request});

  final PreviewEmployeeRequest request;

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
                    requestLabel(request.type),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                _StatusBadge(status: request.status),
              ],
            ),
            const SizedBox(height: 8),
            Text(request.reason),
            if (request.amount > 0) ...[
              const SizedBox(height: 6),
              Text(
                request.type.contains('Stok')
                    ? 'Jumlah: ${request.amount}'
                    : request.amount.toRupiah(),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              '${request.createdAt.toIndonesianDate()} ${request.createdAt.toIndonesianTime()}',
              style: const TextStyle(color: AppColors.secondaryText),
            ),
            if (request.reviewNote.isNotEmpty) ...[
              const Divider(height: 20),
              Text(
                'Catatan Owner: ${request.reviewNote}',
                style: const TextStyle(color: AppColors.secondaryText),
              ),
            ],
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
          style: TextStyle(color: color, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

PreviewEmployee? _resolveCurrentEmployee(
  List<PreviewEmployee> employees,
  AppUser? user,
) {
  final employeeId = user?.employeeId;
  if (employeeId != null) {
    final byId = employees
        .where((employee) => employee.id == employeeId)
        .firstOrNull;
    if (byId != null) return byId;
  }

  if (user?.userId.startsWith('preview-') == true &&
      employeeId == 'preview-employee-1') {
    final previewEmployee = employees
        .where((employee) => employee.id == 'employee-1')
        .firstOrNull;
    if (previewEmployee != null) return previewEmployee;
  }

  if (employeeId != null && user?.userId.startsWith('preview-') != true) {
    return PreviewEmployee(
      id: employeeId,
      name: user?.name ?? 'Karyawan',
      phone: user?.phone ?? '',
      position: 'Karyawan',
      isActive: true,
    );
  }

  final normalizedName = user?.name.trim().toLowerCase();
  if (normalizedName == null || normalizedName.isEmpty) return null;
  return employees
      .where((employee) => employee.name.trim().toLowerCase() == normalizedName)
      .firstOrNull;
}
