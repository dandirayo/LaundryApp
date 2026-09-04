import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/user_error_message.dart';
import '../../../core/extensions/currency_extensions.dart';
import '../../../core/extensions/quantity_extensions.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/ui_action_queue.dart';
import '../../../core/widgets/app_bottom_sheet_body.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../shared/preview_data.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../customers/data/device_contact_repository.dart';
import '../../customers/domain/contact_import.dart';
import '../../customers/domain/customer.dart';
import '../../customers/presentation/customer_controller.dart';
import '../../employees/presentation/employee_directory_controller.dart';
import '../../services/presentation/service_controller.dart';
import 'order_controller.dart';
import 'receipt_preview_sheet.dart';

class OrderCreatePage extends ConsumerStatefulWidget {
  const OrderCreatePage({super.key});

  @override
  ConsumerState<OrderCreatePage> createState() => _OrderCreatePageState();
}

class _OrderCreatePageState extends ConsumerState<OrderCreatePage> {
  final _deviceContacts = DeviceContactRepository();
  final _quantityController = TextEditingController(text: '3');
  final _paidController = TextEditingController(text: '0');
  final _noteController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _items = <_OrderDraftItem>[];
  var _mode = _OrderMode.kilo;
  String? _quickCategory;
  String? _selectedQuantityUnit;
  String? _customerId;
  String? _serviceId;
  String? _employeeId;
  String _paymentMethod = 'Tunai';
  var _showReceiptAfterSave = true;
  var _isSubmitting = false;
  var _isSyncingContacts = false;

  @override
  void dispose() {
    _quantityController.dispose();
    _paidController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(
      previewDataProvider.select(
        (state) => (
          customers: state.customers,
          services: state.services,
          employees: state.employees,
        ),
      ),
    );
    final onlineCustomers = ref
        .watch(customerControllerProvider)
        .value
        ?.customers;
    final customers = onlineCustomers == null
        ? data.customers
        : [
            for (final c in onlineCustomers)
              PreviewCustomer(
                id: c.id,
                name: c.name,
                phone: c.phone ?? "",
                normalizedPhone: c.normalizedPhone ?? "",
                address: c.address,
                note: c.note,
                createdAt: c.createdAt,
              ),
          ];

    final serviceSource =
        ref.watch(serviceControllerProvider).value ?? data.services;
    final services = serviceSource
        .where((service) => service.isActive)
        .toList();
    final employees =
        ref.watch(employeeDirectoryProvider).value ?? data.employees;

    final selectedEmployeeId = _employeeId ?? employees.firstOrNull?.id;
    final selectedCustomer = customers
        .where((c) => c.id == _customerId)
        .cast<PreviewCustomer?>()
        .firstOrNull;

    final modeServices = services
        .where(
          (service) => switch (_mode) {
            _OrderMode.kilo => service.effectiveGroup == 'Kiloan',
            _OrderMode.unit => service.effectiveGroup == 'Satuan',
            _OrderMode.mix => true,
          },
        )
        .toList();
    final quickCategories = modeServices
        .map((service) => service.effectiveCategory)
        .toSet()
        .toList();
    final selectedCategory = quickCategories.contains(_quickCategory)
        ? _quickCategory
        : null;
    final quickServices = _quickServicesForMode(
      modeServices
          .where(
            (service) =>
                selectedCategory == null ||
                service.effectiveCategory == selectedCategory,
          )
          .toList(),
      _mode,
    );

    final total = _items.fold<int>(0, (sum, item) => sum + item.total);
    final strings = ref.strings;

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.addOrder),
        elevation: 0,
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.primaryNavy,
      ),
      backgroundColor: AppColors.surface,
      body: services.isEmpty || employees.isEmpty
          ? AppStateView.empty(
              title: strings.isEnglish
                  ? "Master data is incomplete"
                  : "Data master belum lengkap",
              message: strings.isEnglish
                  ? "Add at least one service and employee."
                  : "Tambahkan minimal satu layanan dan karyawan.",
            )
          : customers.isEmpty
          ? _CustomerSetupEmptyState(
              isSyncing: _isSyncingContacts,
              onSync: () => _syncContacts(context),
              onAdd: () async {
                final customer = await _createQuickCustomer(context);
                if (customer != null && mounted) {
                  setState(() => _customerId = customer.id);
                }
              },
            )
          : Form(
              key: _formKey,
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      children: [
                        Container(
                          color: AppColors.surface,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Column(
                            children: [
                              _buildCompactCustomerSelector(
                                selectedCustomer,
                                customers,
                              ),
                              const SizedBox(height: 12),
                              _ModeSelector(
                                selected: _mode,
                                onChanged: (mode) => setState(() {
                                  _mode = mode;
                                  _serviceId = null;
                                  _selectedQuantityUnit = null;
                                  _quantityController.text =
                                      mode == _OrderMode.unit ? "1" : "3";
                                }),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (_items.isNotEmpty) ...[
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      "Keranjang Pesanan",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                        color: AppColors.primaryNavy,
                                      ),
                                    ),
                                    Text(
                                      "${_items.length} Item",
                                      style: const TextStyle(
                                        color: AppColors.primaryBlue,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                for (final item in _items)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: _DraftItemTile(
                                      item: item,
                                      onDelete: () =>
                                          setState(() => _items.remove(item)),
                                      onQuantityChanged: (newQty) {
                                        setState(() {
                                          final index = _items.indexOf(item);
                                          if (index != -1) {
                                            _items[index] = _OrderDraftItem(
                                              service: item.service,
                                              quantity: newQty,
                                            );
                                          }
                                        });
                                      },
                                    ),
                                  ),
                                const Divider(height: 32),
                              ],
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    strings.isEnglish
                                        ? "Quick Services"
                                        : "Layanan Cepat",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                      color: AppColors.primaryNavy,
                                    ),
                                  ),
                                  TextButton.icon(
                                    onPressed: () async {
                                      final service = await _pickService(
                                        context,
                                        services,
                                      );
                                      if (service != null && mounted) {
                                        _selectService(service);
                                        _addItem(service);
                                      }
                                    },
                                    icon: const Icon(Icons.search, size: 18),
                                    label: Text(
                                      strings.isEnglish ? "Lainnya" : "Lainnya",
                                    ),
                                    style: TextButton.styleFrom(
                                      foregroundColor: AppColors.primaryBlue,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      minimumSize: Size.zero,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    for (final category in <String?>[
                                      null,
                                      ...quickCategories,
                                    ])
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          right: 8,
                                        ),
                                        child: ChoiceChip(
                                          label: Text(category ?? 'Semua'),
                                          selected:
                                              selectedCategory == category,
                                          onSelected: (_) => setState(
                                            () => _quickCategory = category,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (quickServices.isNotEmpty)
                                _ServiceQuickGrid(
                                  services: quickServices,
                                  selectedServiceId: _serviceId,
                                  onTap: (service) {
                                    _selectService(service);
                                    _addItem(service);
                                  },
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStickyBottomBar(
                    total,
                    employees,
                    selectedEmployeeId,
                    strings,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildCompactCustomerSelector(
    PreviewCustomer? selected,
    List<PreviewCustomer> customers,
  ) {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () async {
              final customer = await _pickCustomer(context, customers);
              if (customer != null && mounted) {
                setState(() => _customerId = customer.id);
              }
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.outline.withValues(alpha: 0.2),
                border: Border.all(color: AppColors.outline),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.person,
                    color: AppColors.primaryNavy,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      selected == null
                          ? "Pilih Pelanggan..."
                          : "${selected.name} (${selected.phone})",
                      style: TextStyle(
                        fontWeight: selected == null
                            ? FontWeight.normal
                            : FontWeight.w700,
                        color: selected == null
                            ? AppColors.secondaryText
                            : AppColors.primaryNavy,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(
                    Icons.arrow_drop_down,
                    color: AppColors.secondaryText,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _buildCustomerActionButton(
          tooltip: 'Sinkron kontak HP',
          backgroundColor: AppColors.softBlue,
          foregroundColor: AppColors.primaryNavy,
          onPressed: _isSyncingContacts ? null : () => _syncContacts(context),
          child: _isSyncingContacts
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.sync),
        ),
        const SizedBox(width: 8),
        _buildCustomerActionButton(
          tooltip: 'Tambah pelanggan',
          backgroundColor: AppColors.primaryBlue,
          foregroundColor: Colors.white,
          onPressed: () async {
            final customer = await _createQuickCustomer(context);
            if (customer != null && mounted) {
              setState(() => _customerId = customer.id);
            }
          },
          child: const Icon(Icons.person_add),
        ),
      ],
    );
  }

  Widget _buildCustomerActionButton({
    required String tooltip,
    required Color backgroundColor,
    required Color foregroundColor,
    required VoidCallback? onPressed,
    required Widget child,
  }) {
    return Container(
      height: 48,
      width: 48,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: backgroundColor.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        color: foregroundColor,
        icon: child,
      ),
    );
  }

  Future<void> _syncContacts(BuildContext context) async {
    if (_isSyncingContacts) return;
    setState(() => _isSyncingContacts = true);
    try {
      final candidates = await _loadDeviceContactCandidates(context);
      if (candidates == null || !context.mounted) return;
      final result = await ref
          .read(customerControllerProvider.notifier)
          .syncContacts(candidates);
      if (context.mounted) {
        showAppSnackBar(_contactSyncMessage(result));
      }
    } catch (error) {
      if (context.mounted) {
        showAppSnackBar(
          userErrorMessage(
            error,
            fallback: 'Kontak belum bisa disinkronkan. Coba lagi.',
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncingContacts = false);
      }
    }
  }

  Future<List<ContactImportCandidate>?> _loadDeviceContactCandidates(
    BuildContext context,
  ) async {
    bool granted;
    try {
      granted = await _deviceContacts.requestReadPermission();
    } catch (error) {
      if (context.mounted) {
        showAppSnackBar(
          userErrorMessage(
            error,
            fallback: 'Daftar kontak belum bisa dibuka. Coba lagi.',
          ),
        );
      }
      return null;
    }
    if (!context.mounted) {
      return null;
    }
    if (!granted) {
      await _showContactPermissionDialog(context);
      return null;
    }

    try {
      final candidates = await _deviceContacts.fetchContactCandidates();
      if (candidates.isEmpty && context.mounted) {
        showAppSnackBar('Daftar kontak perangkat kosong.');
      }
      return candidates.isEmpty ? null : candidates;
    } catch (error) {
      if (context.mounted) {
        showAppSnackBar(
          userErrorMessage(
            error,
            fallback: 'Kontak perangkat gagal dimuat. Coba lagi.',
          ),
        );
      }
      return null;
    }
  }

  Future<void> _showContactPermissionDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Izin kontak diperlukan'),
        content: const Text(
          'Izin kontak diperlukan untuk menyinkronkan pelanggan dari daftar kontak.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _deviceContacts.openSettings();
            },
            child: const Text('Buka Pengaturan'),
          ),
        ],
      ),
    );
  }

  String _contactSyncMessage(ContactSyncResult result) {
    if (result.importedCount == 0) {
      if (result.skippedCount == 0) {
        return 'Tidak ada kontak yang bisa disinkronkan.';
      }
      return 'Tidak ada kontak baru. ${result.skippedCount} kontak dilewati.';
    }

    final skippedText = result.skippedCount == 0
        ? ''
        : ' ${result.skippedCount} dilewati.';
    return '${result.importedCount} kontak berhasil disinkronkan.$skippedText';
  }

  Widget _buildStickyBottomBar(
    int total,
    List<PreviewEmployee> employees,
    String? selectedEmployeeId,
    AppStrings strings,
  ) {
    final paidAmount = _currentPaidAmount().clamp(0, total);
    final remaining = (total - paidAmount).clamp(0, total);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryNavy.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, -8),
          ),
        ],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Total Tagihan",
                      style: TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      total.toRupiah(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                        color: AppColors.primaryNavy,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      "Sisa Bayar",
                      style: TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      remaining.toRupiah(),
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        color: remaining == 0
                            ? AppColors.success
                            : AppColors.primaryNavy,
                      ),
                    ),
                    Text(
                      'Dibayar ${paidAmount.toRupiah()}',
                      style: const TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _PaymentPresetButton(
                    label: 'Belum',
                    selected: paidAmount == 0,
                    onTap: () => _setPaidAmount(0),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _PaymentPresetButton(
                    label: 'DP 50%',
                    selected: total > 0 && paidAmount == (total / 2).round(),
                    onTap: () => _setPaidAmount((total / 2).round()),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _PaymentPresetButton(
                    label: 'Lunas',
                    selected: total > 0 && paidAmount == total,
                    onTap: () => _setPaidAmount(total),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: () => _showOptionalDetailsSheet(
                  employees,
                  selectedEmployeeId,
                  strings,
                ),
                icon: const Icon(Icons.tune_outlined, size: 18),
                label: const Text(
                  "Nominal Manual, Metode Bayar & Kasir",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.softBlue,
                  foregroundColor: AppColors.primaryNavy,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton.icon(
                onPressed: _isSubmitting ? null : _submit,
                icon: _isSubmitting
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle, size: 24),
                label: Text(
                  _isSubmitting ? "MENYIMPAN..." : "SIMPAN & CETAK NOTA",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryNavy,
                  shadowColor: AppColors.primaryNavy.withValues(alpha: 0.5),
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _currentPaidAmount() => int.tryParse(_paidController.text) ?? 0;

  void _setPaidAmount(int value) {
    setState(() {
      _paidController.text = value.clamp(0, 1 << 31).toString();
    });
  }

  void _showOptionalDetailsSheet(
    List<PreviewEmployee> employees,
    String? selectedEmployeeId,
    AppStrings strings,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.outline,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  "Informasi Pembayaran & Kasir",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: AppColors.primaryNavy,
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _paidController,
                  keyboardType: TextInputType.number,
                  onChanged: (_) {
                    setState(() {});
                    setSheetState(() {});
                  },
                  validator: (value) {
                    final paidAmount = int.tryParse((value ?? '').trim());
                    if (paidAmount == null) {
                      return 'Nominal bayar wajib angka.';
                    }
                    final total = _items.fold<int>(
                      0,
                      (sum, item) => sum + item.total,
                    );
                    if (paidAmount < 0) {
                      return 'Nominal DP tidak boleh kurang dari nol.';
                    }
                    if (paidAmount > total) {
                      return 'Nominal DP tidak boleh lebih besar dari total.';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    labelText: "Nominal Bayar Manual / DP",
                    prefixIcon: const Icon(Icons.payments_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _paymentMethod,
                  items: const [
                    DropdownMenuItem(value: "Tunai", child: Text("Tunai")),
                    DropdownMenuItem(
                      value: "Transfer",
                      child: Text("Transfer"),
                    ),
                    DropdownMenuItem(value: "QRIS", child: Text("QRIS")),
                  ],
                  onChanged: (value) {
                    setState(() => _paymentMethod = value ?? _paymentMethod);
                    setSheetState(() {});
                  },
                  decoration: InputDecoration(
                    labelText: "Metode Pembayaran",
                    prefixIcon: const Icon(
                      Icons.account_balance_wallet_outlined,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedEmployeeId,
                  items: [
                    for (final employee in employees)
                      DropdownMenuItem(
                        value: employee.id,
                        child: Text(employee.name),
                      ),
                  ],
                  onChanged: (value) {
                    setState(() => _employeeId = value ?? selectedEmployeeId);
                    setSheetState(() {});
                  },
                  decoration: InputDecoration(
                    labelText: "Pilih Kasir",
                    prefixIcon: const Icon(Icons.badge_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _noteController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: "Catatan Pesanan",
                    prefixIcon: const Icon(Icons.notes),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    "Cetak Struk Otomatis",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  value: _showReceiptAfterSave,
                  activeThumbColor: AppColors.primaryNavy,
                  onChanged: (value) {
                    setState(() => _showReceiptAfterSave = value);
                    setSheetState(() {});
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryNavy,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      "SELESAI",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<PreviewCustomer?> _pickCustomer(
    BuildContext context,
    List<PreviewCustomer> customers,
  ) {
    return showAppModalBottomSheet<PreviewCustomer>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _CustomerPickerSheet(customers: customers),
    );
  }

  Future<PreviewService?> _pickService(
    BuildContext context,
    List<PreviewService> services,
  ) {
    return showAppModalBottomSheet<PreviewService>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _ServicePickerSheet(
        services: services,
        initialGroup: switch (_mode) {
          _OrderMode.kilo => 'Kiloan',
          _OrderMode.unit => 'Satuan',
          _OrderMode.mix => null,
        },
      ),
    );
  }

  Future<PreviewCustomer?> _createQuickCustomer(BuildContext context) async {
    final strings = ref.read(appLanguageProvider) == AppLanguage.en
        ? const AppStrings(AppLanguage.en)
        : const AppStrings(AppLanguage.id);
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final addressController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showAppModalBottomSheet<_QuickCustomerInput>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Form(
        key: formKey,
        child: AppBottomSheetBody(
          children: [
            Text(
              strings.isEnglish ? 'New Customer' : 'Pelanggan Baru',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: nameController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: strings.isEnglish ? 'Customer name' : 'Nama',
                prefixIcon: const Icon(Icons.person_outline),
              ),
              validator: (value) =>
                  (value ?? '').trim().isEmpty ? strings.nameRequired : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: strings.isEnglish
                    ? 'WhatsApp number (optional)'
                    : 'Nomor WA (opsional)',
                prefixIcon: const Icon(Icons.chat_outlined),
              ),
              validator: (value) {
                return Customer.isValidOptionalPhone(value ?? '')
                    ? null
                    : strings.invalidPhone;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: addressController,
              decoration: InputDecoration(
                labelText: strings.isEnglish
                    ? 'Address (optional)'
                    : 'Alamat opsional',
                prefixIcon: const Icon(Icons.place_outlined),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                if (!formKey.currentState!.validate()) {
                  return;
                }
                Navigator.of(context).pop(
                  _QuickCustomerInput(
                    name: nameController.text,
                    phone: phoneController.text,
                    address: addressController.text,
                  ),
                );
              },
              icon: const Icon(Icons.check_circle_outline),
              label: Text(strings.save),
            ),
          ],
        ),
      ),
    );

    nameController.dispose();
    phoneController.dispose();
    addressController.dispose();

    if (result == null || !mounted) {
      return null;
    }
    try {
      await ref
          .read(customerControllerProvider.notifier)
          .addCustomer(
            name: result.name,
            phone: result.phone,
            address: result.address,
            note: '',
          );
      final customers = ref.read(customerControllerProvider).value?.customers;
      final created = customers
          ?.where(
            (customer) =>
                customer.name.trim() == result.name.trim() &&
                customer.phone == Customer.phoneFromInput(result.phone),
          )
          .firstOrNull;
      if (created == null) return null;
      return PreviewCustomer(
        id: created.id,
        name: created.name,
        phone: created.phone ?? '',
        normalizedPhone: created.normalizedPhone ?? '',
        address: created.address,
        note: created.note,
        createdAt: created.createdAt,
      );
    } catch (error) {
      showAppSnackBar(error.toString());
      return null;
    }
  }

  void _selectService(PreviewService service) {
    final quantity = double.tryParse(_quantityController.text) ?? 0;
    final unit = service.unit.toUpperCase();
    setState(() {
      _serviceId = service.id;
      if (_selectedQuantityUnit != unit) {
        _quantityController.text = unit == 'KG' ? '3' : '1';
      } else if (unit == 'KG' && quantity < 3) {
        _quantityController.text = '3';
      }
      if (unit != 'KG' && quantity <= 0) {
        _quantityController.text = '1';
      }
      _selectedQuantityUnit = unit;
    });
  }

  void _addItem(PreviewService service) {
    final strings = ref.read(appLanguageProvider) == AppLanguage.en
        ? const AppStrings(AppLanguage.en)
        : const AppStrings(AppLanguage.id);
    final quantity = double.tryParse(_quantityController.text) ?? 0;
    if (quantity <= 0) {
      showAppSnackBar(
        strings.isEnglish
            ? 'Weight or quantity must be greater than zero.'
            : 'Berat atau jumlah wajib lebih dari nol.',
      );
      return;
    }
    if (service.unit.toUpperCase() == 'KG' && quantity < 3) {
      showAppSnackBar(
        strings.isEnglish
            ? 'Minimum kilo laundry is 3 kg.'
            : 'Minimum laundry kiloan 3 kg.',
      );
      return;
    }
    setState(() {
      _items.add(_OrderDraftItem(service: service, quantity: quantity));
      _quantityController.text = service.unit.toUpperCase() == 'KG' ? '3' : '1';
    });
  }

  Future<void> _submit() async {
    if (_isSubmitting) {
      return;
    }
    final missingSteps = _missingOrderSteps();
    if (missingSteps.isNotEmpty) {
      await _showMissingStepsDialog(missingSteps);
      return;
    }
    if (!_formKey.currentState!.validate()) {
      await _showMissingStepsDialog([
        'Cek kolom pembayaran dan detail pesanan yang bertanda merah.',
      ]);
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final order = await ref
          .read(orderControllerProvider.notifier)
          .create(
            customerId: _customerId!,
            items: [
              for (final item in _items)
                (service: item.service, quantity: item.quantity),
            ],
            paidAmount: int.tryParse(_paidController.text) ?? 0,
            paymentMethod: _paymentMethod,
            employeeId: _employeeId ?? 'employee-1',
            note: _noteController.text,
          );
      if (!mounted) {
        return;
      }
      final latest = ref.read(previewDataProvider);
      final payments = latest.payments
          .where((payment) => payment.orderId == order.id)
          .toList();
      final currentUser = ref.read(authControllerProvider).value?.user;
      final employeeName =
          (ref.read(employeeDirectoryProvider).value ?? latest.employees)
              .where((employee) => employee.id == order.assignedEmployeeId)
              .map((employee) => employee.name)
              .firstOrNull ??
          (currentUser?.employeeId == order.assignedEmployeeId
              ? currentUser?.name
              : null);
      if (_showReceiptAfterSave) {
        await waitForTransientUiDismissal();
        if (!mounted) {
          return;
        }
        await showReceiptPreviewSheet(
          context: context,
          order: order,
          payments: payments,
          shopName: latest.shopName,
          shopAddress: latest.shopAddress,
          employeeName: order.receivedByName.trim().isEmpty
              ? employeeName ?? 'Petugas'
              : order.receivedByName,
        );
        if (!mounted) {
          return;
        }
      }
      final strings = ref.read(appLanguageProvider) == AppLanguage.en
          ? const AppStrings(AppLanguage.en)
          : const AppStrings(AppLanguage.id);
      showAppSnackBar(
        strings.isEnglish
            ? '${order.orderNumber} created successfully.'
            : '${order.orderNumber} berhasil dibuat.',
      );
      context.go('/orders/${order.id}');
    } catch (error) {
      if (mounted) {
        showAppSnackBar(
          userErrorMessage(
            error,
            fallback:
                'Pesanan gagal disimpan. Periksa data pelanggan dan layanan.',
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  List<String> _missingOrderSteps() {
    final missing = <String>[];
    if (_customerId == null) {
      missing.add('Pilih pelanggan dulu atau tambah pelanggan baru.');
    }
    if (_items.isEmpty) {
      missing.add(
        'Pilih layanan paket atau layanan lainnya untuk masuk ke pesanan.',
      );
    }
    final paidAmount = int.tryParse(_paidController.text) ?? 0;
    final total = _items.fold<int>(0, (sum, item) => sum + item.total);
    if (paidAmount < 0) {
      missing.add('Nominal DP tidak boleh kurang dari nol.');
    }
    if (paidAmount > total) {
      missing.add('Nominal DP tidak boleh lebih besar dari total pesanan.');
    }
    return missing;
  }

  Future<void> _showMissingStepsDialog(List<String> steps) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lengkapi pesanan dulu'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final step in steps)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• '),
                    Expanded(child: Text(step)),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Mengerti'),
          ),
        ],
      ),
    );
  }
}

enum _OrderMode { kilo, unit, mix }

const _coreLaundryPackages = [
  _CoreLaundryPackage(
    title: 'Cuci Setrika Reguler',
    category: 'Cuci Setrika',
    item: 'Cuci Setrika',
    variant: 'Reguler',
    sortOrder: 0,
  ),
  _CoreLaundryPackage(
    title: 'Cuci Setrika Express',
    category: 'Cuci Setrika',
    item: 'Cuci Setrika',
    variant: 'Express',
    sortOrder: 1,
  ),
  _CoreLaundryPackage(
    title: 'Cuci Setrika Kilat',
    category: 'Cuci Setrika',
    item: 'Cuci Setrika',
    variant: 'Kilat',
    sortOrder: 2,
  ),
  _CoreLaundryPackage(
    title: 'Cuci Kering Lipat Reguler',
    category: 'Cuci Kering Lipat',
    item: 'Cuci Kering Lipat',
    variant: 'Reguler',
    sortOrder: 3,
  ),
  _CoreLaundryPackage(
    title: 'Cuci Kering Lipat Express',
    category: 'Cuci Kering Lipat',
    item: 'Cuci Kering Lipat',
    variant: 'Express',
    sortOrder: 4,
  ),
  _CoreLaundryPackage(
    title: 'Cuci Kering Lipat Kilat',
    category: 'Cuci Kering Lipat',
    item: 'Cuci Kering Lipat',
    variant: 'Kilat',
    sortOrder: 5,
  ),
  _CoreLaundryPackage(
    title: 'Setrika Lipat Reguler',
    category: 'Setrika Lipat',
    item: 'Setrika Lipat',
    variant: 'Reguler',
    sortOrder: 6,
  ),
  _CoreLaundryPackage(
    title: 'Setrika Lipat Express',
    category: 'Setrika Lipat',
    item: 'Setrika Lipat',
    variant: 'Express',
    sortOrder: 7,
  ),
  _CoreLaundryPackage(
    title: 'Setrika Lipat Kilat',
    category: 'Setrika Lipat',
    item: 'Setrika Lipat',
    variant: 'Kilat',
    sortOrder: 8,
  ),
];

List<PreviewService> _quickServicesForMode(
  List<PreviewService> services,
  _OrderMode mode,
) {
  final activeServices = services.where((service) => service.isActive).toList();
  final kiloServices = activeServices
      .where((service) => service.unit.toUpperCase() == 'KG')
      .toList();
  final unitServices =
      activeServices
          .where((service) => service.unit.toUpperCase() != 'KG')
          .toList()
        ..sort(_compareQuickService);

  final coreServices = <PreviewService>[];
  final usedIds = <String>{};
  for (final package in _coreLaundryPackages) {
    final matches =
        kiloServices.where((service) => package.matches(service)).toList()
          ..sort(_compareQuickService);
    if (matches.isNotEmpty && usedIds.add(matches.first.id)) {
      coreServices.add(matches.first);
    }
  }

  final extraKiloServices =
      kiloServices
          .where(
            (service) =>
                !usedIds.contains(service.id) &&
                _corePackageFor(service) == null,
          )
          .toList()
        ..sort(_compareQuickService);

  return switch (mode) {
    _OrderMode.kilo => [
      ...coreServices,
      ...extraKiloServices,
    ].take(12).toList(),
    _OrderMode.unit => unitServices.take(12).toList(),
    _OrderMode.mix => [
      ...coreServices,
      ...unitServices.take(3),
      ...extraKiloServices,
    ].take(12).toList(),
  };
}

int _compareQuickService(PreviewService a, PreviewService b) {
  final aCore = _corePackageFor(a)?.sortOrder;
  final bCore = _corePackageFor(b)?.sortOrder;
  if (aCore != null || bCore != null) {
    return (aCore ?? 999).compareTo(bCore ?? 999);
  }
  final sortOrder = a.sortOrder.compareTo(b.sortOrder);
  if (sortOrder != 0) {
    return sortOrder;
  }
  return a.name.compareTo(b.name);
}

_CoreLaundryPackage? _corePackageFor(PreviewService service) {
  for (final package in _coreLaundryPackages) {
    if (package.matches(service)) {
      return package;
    }
  }
  return null;
}

String _normalizePackageText(String value) {
  return value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
}

class _CoreLaundryPackage {
  const _CoreLaundryPackage({
    required this.title,
    required this.category,
    required this.item,
    required this.variant,
    required this.sortOrder,
  });

  final String title;
  final String category;
  final String item;
  final String variant;
  final int sortOrder;

  bool matches(PreviewService service) {
    if (service.unit.toUpperCase() != 'KG') {
      return false;
    }
    final searchable = _normalizePackageText(
      '${service.name} ${service.effectiveCategory} '
      '${service.effectiveItem} ${service.effectiveVariant}',
    );
    final normalizedVariant = _normalizePackageText(variant);
    if (!searchable.contains(normalizedVariant)) {
      return false;
    }
    final normalizedCategory = _normalizePackageText(category);
    if (normalizedCategory == 'cuci kering lipat') {
      return searchable.contains('cuci kering lipat') ||
          searchable.contains('cuci lipat');
    }
    if (normalizedCategory == 'setrika lipat') {
      return searchable.contains('setrika') && !searchable.contains('cuci');
    }
    return searchable.contains(normalizedCategory);
  }
}

class _CustomerSetupEmptyState extends StatelessWidget {
  const _CustomerSetupEmptyState({
    required this.isSyncing,
    required this.onSync,
    required this.onAdd,
  });

  final bool isSyncing;
  final VoidCallback onSync;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.softMint,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.contacts_outlined,
                  color: AppColors.primaryNavy,
                  size: 30,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Pelanggan belum ada',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'Sinkronkan kontak HP agar pelanggan langsung bisa dipilih saat membuat pesanan.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.secondaryText,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: isSyncing ? null : onSync,
                icon: isSyncing
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync),
                label: Text(isSyncing ? 'Menyinkronkan...' : 'Sinkron Kontak'),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Tambah Manual'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickCustomerInput {
  const _QuickCustomerInput({
    required this.name,
    required this.phone,
    required this.address,
  });

  final String name;
  final String phone;
  final String address;
}

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({required this.selected, required this.onChanged});

  final _OrderMode selected;
  final ValueChanged<_OrderMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ModeButton(
            label: 'Kiloan',
            icon: Icons.scale_outlined,
            selected: selected == _OrderMode.kilo,
            onTap: () => onChanged(_OrderMode.kilo),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ModeButton(
            label: 'Satuan',
            icon: Icons.checkroom_outlined,
            selected: selected == _OrderMode.unit,
            onTap: () => onChanged(_OrderMode.unit),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ModeButton(
            label: 'Gabung',
            icon: Icons.playlist_add_check_outlined,
            selected: selected == _OrderMode.mix,
            onTap: () => onChanged(_OrderMode.mix),
          ),
        ),
      ],
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 76,
      child: selected
          ? FilledButton(
              onPressed: onTap,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [Icon(icon), const SizedBox(height: 6), Text(label)],
              ),
            )
          : OutlinedButton(
              onPressed: onTap,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [Icon(icon), const SizedBox(height: 6), Text(label)],
              ),
            ),
    );
  }
}

class _ServiceQuickGrid extends StatelessWidget {
  const _ServiceQuickGrid({
    required this.services,
    required this.selectedServiceId,
    required this.onTap,
  });

  final List<PreviewService> services;
  final String? selectedServiceId;
  final ValueChanged<PreviewService> onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 330 ? 3 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: services.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: columns == 3 ? 0.88 : 1.18,
          ),
          itemBuilder: (context, index) {
            final service = services[index];
            return _ServiceQuickButton(
              service: service,
              selected: service.id == selectedServiceId,
              onTap: () => onTap(service),
            );
          },
        );
      },
    );
  }
}

class _ServiceQuickButton extends StatelessWidget {
  const _ServiceQuickButton({
    required this.service,
    required this.selected,
    required this.onTap,
  });

  final PreviewService service;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final corePackage = _corePackageFor(service);
    final title =
        corePackage?.title ??
        (service.effectiveVariant.isEmpty
            ? service.name
            : '${service.effectiveItem} ${service.effectiveVariant}');
    final isCorePackage = corePackage != null;
    final backgroundColor = selected
        ? AppColors.primaryNavy
        : isCorePackage
        ? AppColors.lightGold.withValues(alpha: 0.42)
        : AppColors.surface;
    final foregroundColor = selected ? Colors.white : AppColors.primaryNavy;
    final borderColor = selected
        ? AppColors.primaryNavy
        : isCorePackage
        ? AppColors.warning.withValues(alpha: 0.38)
        : AppColors.outline;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor),
            boxShadow: [
              if (isCorePackage)
                BoxShadow(
                  color: AppColors.primaryNavy.withValues(alpha: 0.05),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
            ],
          ),
          child: _ServiceButtonContent(
            service: service,
            title: title,
            foregroundColor: foregroundColor,
            selected: selected,
          ),
        ),
      ),
    );
  }
}

class _ServiceButtonContent extends StatelessWidget {
  const _ServiceButtonContent({
    required this.service,
    required this.title,
    required this.foregroundColor,
    required this.selected,
  });

  final PreviewService service;
  final String title;
  final Color foregroundColor;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final mutedColor = selected
        ? Colors.white.withValues(alpha: 0.78)
        : AppColors.secondaryText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.local_laundry_service_outlined,
              color: foregroundColor,
              size: 18,
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: selected
                    ? Colors.white.withValues(alpha: 0.14)
                    : Colors.white.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                service.unit.toUpperCase(),
                style: TextStyle(
                  color: foregroundColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Text(
            title,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: foregroundColor,
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
              height: 1.12,
            ),
          ),
        ),
        Text(
          service.price.toRupiah(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: foregroundColor,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          'per ${service.unit.toUpperCase()}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: mutedColor,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _PaymentPresetButton extends StatelessWidget {
  const _PaymentPresetButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: selected
          ? FilledButton(
              onPressed: onTap,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryNavy,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            )
          : OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryNavy,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                side: const BorderSide(color: AppColors.outline),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
    );
  }
}

class _CustomerPickerSheet extends StatefulWidget {
  const _CustomerPickerSheet({required this.customers});

  final List<PreviewCustomer> customers;

  @override
  State<_CustomerPickerSheet> createState() => _CustomerPickerSheetState();
}

class _CustomerPickerSheetState extends State<_CustomerPickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customers = widget.customers
        .where((customer) {
          final query = _normalize(_query);
          if (query.isEmpty) {
            return true;
          }
          return _normalize(
            '${customer.name} ${customer.phone} ${customer.normalizedPhone} ${customer.address}',
          ).contains(query);
        })
        .take(30)
        .toList();

    return AppBottomSheetBody(
      children: [
        Text(
          'Pilih Pelanggan',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Cari nama, nomor, atau alamat',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (value) => setState(() => _query = value),
        ),
        const SizedBox(height: 12),
        if (customers.isEmpty)
          const AppStateView.empty(
            title: 'Pelanggan tidak ditemukan',
            message: 'Coba kata kunci lain atau tambahkan pelanggan baru.',
          )
        else
          for (final customer in customers)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.person_outline),
              title: Text(customer.name),
              subtitle: Text(
                [
                  customer.phone,
                  if (customer.address.trim().isNotEmpty) customer.address,
                ].join(' - '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => Navigator.of(context).pop(customer),
            ),
      ],
    );
  }

  String _normalize(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}

class _ServicePickerSheet extends StatefulWidget {
  const _ServicePickerSheet({required this.services, this.initialGroup});

  final List<PreviewService> services;
  final String? initialGroup;

  @override
  State<_ServicePickerSheet> createState() => _ServicePickerSheetState();
}

class _ServicePickerSheetState extends State<_ServicePickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';
  String? _group;
  String? _category;
  String? _item;

  @override
  void initState() {
    super.initState();
    _group = widget.initialGroup;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _normalize(_query);
    final services =
        widget.services
            .where(
              (service) =>
                  query.isEmpty ||
                  _normalize(
                    '${service.name} ${service.breadcrumb} ${service.unit}',
                  ).contains(query),
            )
            .toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final currentServices = services.where((service) {
      return (_group == null || service.effectiveGroup == _group) &&
          (_category == null || service.effectiveCategory == _category) &&
          (_item == null || service.effectiveItem == _item);
    }).toList();
    final level = _item == null
        ? _category == null
              ? _group == null
                    ? _PickerLevel.group
                    : _PickerLevel.category
              : _PickerLevel.item
        : _PickerLevel.variant;
    final title = switch (level) {
      _PickerLevel.group => 'Pilih Kategori Utama',
      _PickerLevel.category => 'Pilih Subkategori',
      _PickerLevel.item => 'Pilih Jenis Barang',
      _PickerLevel.variant => 'Pilih Varian',
    };
    final options = switch (level) {
      _PickerLevel.group => _unique(
        services.map((service) => service.effectiveGroup),
      ),
      _PickerLevel.category => _unique(
        currentServices.map((service) => service.effectiveCategory),
      ),
      _PickerLevel.item => _unique(
        currentServices.map((service) => service.effectiveItem),
      ),
      _PickerLevel.variant => const <String>[],
    };

    return AppBottomSheetBody(
      children: [
        Row(
          children: [
            if (_group != null)
              IconButton(
                tooltip: 'Kembali',
                onPressed: _goBack,
                icon: const Icon(Icons.arrow_back),
              ),
            Expanded(
              child: Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        if (_group != null) ...[
          const SizedBox(height: 4),
          Text(
            [
              _group,
              _category,
              _item,
            ].whereType<String>().where((part) => part.isNotEmpty).join(' > '),
            style: const TextStyle(
              color: AppColors.primaryBlue,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        const SizedBox(height: 12),
        TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Cari layanan',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (value) => setState(() => _query = value),
        ),
        const SizedBox(height: 12),
        if (currentServices.isEmpty)
          const AppStateView.empty(
            title: 'Layanan tidak ditemukan',
            message: 'Coba kategori atau kata kunci lain.',
          )
        else if (level != _PickerLevel.variant)
          for (final option in options)
            _ServiceOptionTile(
              title: option,
              subtitle: _optionSubtitle(level, currentServices, option),
              onTap: () => _selectOption(level, option),
            )
        else
          for (final service in currentServices)
            _ServiceOptionTile(
              title: service.effectiveVariant.isEmpty
                  ? service.name
                  : service.effectiveVariant,
              subtitle:
                  '${service.breadcrumb} - ${service.unit} - ${service.estimatedHours} jam',
              trailing: service.price.toRupiah(),
              onTap: () => Navigator.of(context).pop(service),
            ),
      ],
    );
  }

  void _selectOption(_PickerLevel level, String option) {
    setState(() {
      switch (level) {
        case _PickerLevel.group:
          _group = option;
        case _PickerLevel.category:
          _category = option;
        case _PickerLevel.item:
          _item = option;
        case _PickerLevel.variant:
          break;
      }
    });
  }

  void _goBack() {
    setState(() {
      if (_item != null) {
        _item = null;
      } else if (_category != null) {
        _category = null;
      } else {
        _group = null;
      }
    });
  }

  String _optionSubtitle(
    _PickerLevel level,
    List<PreviewService> services,
    String option,
  ) {
    final matching = services.where((service) {
      return switch (level) {
        _PickerLevel.group => service.effectiveGroup == option,
        _PickerLevel.category => service.effectiveCategory == option,
        _PickerLevel.item => service.effectiveItem == option,
        _PickerLevel.variant => false,
      };
    }).toList();
    final variants = matching.length;
    final minPrice = matching
        .map((service) => service.price)
        .fold<int?>(
          null,
          (min, price) => min == null || price < min ? price : min,
        );
    if (minPrice == null) {
      return '';
    }
    return '$variants pilihan, mulai ${minPrice.toRupiah()}';
  }

  List<String> _unique(Iterable<String> values) {
    final result = <String>[];
    for (final value in values) {
      if (value.trim().isEmpty || result.contains(value)) {
        continue;
      }
      result.add(value);
    }
    return result;
  }

  String _normalize(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}

enum _PickerLevel { group, category, item, variant }

class _ServiceOptionTile extends StatelessWidget {
  const _ServiceOptionTile({
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final String? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: subtitle.isEmpty ? null : Text(subtitle),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (trailing != null)
              Text(
                trailing!,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

class _OrderDraftItem {
  const _OrderDraftItem({required this.service, required this.quantity});

  final PreviewService service;
  final double quantity;

  int get total => (service.price * quantity).round();
}

class _DraftItemTile extends StatelessWidget {
  const _DraftItemTile({
    required this.item,
    required this.onDelete,
    required this.onQuantityChanged,
  });

  final _OrderDraftItem item;
  final VoidCallback onDelete;
  final ValueChanged<double> onQuantityChanged;

  @override
  Widget build(BuildContext context) {
    final isKilo = item.service.unit.toUpperCase() == 'KG';
    final isMeasured = [
      'KG',
      'M2',
      'M',
    ].contains(item.service.unit.toUpperCase());
    final min = isKilo ? 3.0 : (isMeasured ? 0.01 : 1.0);
    final step = isMeasured ? 0.5 : 1.0;
    final quantityLabel = formatQuantityForUnit(
      item.quantity,
      item.service.unit,
    );

    return Card(
      child: ListTile(
        title: Text(
          item.service.name,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text('$quantityLabel x ${item.service.price.toRupiah()}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(
                Icons.remove_circle_outline,
                size: 22,
                color: AppColors.primaryBlue,
              ),
              onPressed: item.quantity <= min
                  ? null
                  : () => onQuantityChanged(
                      (item.quantity - step).clamp(min, double.infinity),
                    ),
            ),
            InkWell(
              onTap: () => _editQuantity(context, min, isMeasured),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 4,
                ),
                child: Text(
                  quantityLabel.split(' ').first,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.add_circle_outline,
                size: 22,
                color: AppColors.primaryBlue,
              ),
              onPressed: () => onQuantityChanged(item.quantity + step),
            ),
            const SizedBox(width: 8),
            Text(
              item.total.toRupiah(),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            IconButton(
              tooltip: 'Hapus item',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline, color: AppColors.error),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editQuantity(
    BuildContext context,
    double minimum,
    bool measured,
  ) async {
    final controller = TextEditingController(text: item.quantity.toString());
    final formKey = GlobalKey<FormState>();
    final quantity = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Jumlah (${item.service.unit})'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.numberWithOptions(decimal: measured),
            decoration: InputDecoration(
              labelText: 'Jumlah',
              helperText: measured
                  ? 'Maksimal 2 angka desimal, contoh 2,25'
                  : 'Jumlah barang utuh',
            ),
            validator: (text) {
              final normalized = (text ?? '').trim().replaceAll(',', '.');
              final value = double.tryParse(normalized);
              if (value == null || !value.isFinite || value < minimum) {
                return 'Minimal $minimum ${item.service.unit}';
              }
              if (!measured && value % 1 != 0) {
                return 'Gunakan jumlah barang utuh';
              }
              if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(normalized)) {
                return 'Gunakan maksimal 2 angka desimal';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(
                  context,
                  double.parse(controller.text.trim().replaceAll(',', '.')),
                );
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (quantity != null) onQuantityChanged(quantity);
    // Route disposal can lag behind its result while the dialog animates out.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    controller.dispose();
  }
}
