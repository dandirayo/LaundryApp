import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/extensions/currency_extensions.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/ui_action_queue.dart';
import '../../../core/widgets/app_bottom_sheet_body.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../core/widgets/responsive_page.dart';
import '../../../shared/preview_data.dart';

class OrderCreatePage extends ConsumerStatefulWidget {
  const OrderCreatePage({super.key});

  @override
  ConsumerState<OrderCreatePage> createState() => _OrderCreatePageState();
}

class _OrderCreatePageState extends ConsumerState<OrderCreatePage> {
  final _quantityController = TextEditingController(text: '3');
  final _paidController = TextEditingController(text: '0');
  final _noteController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _items = <_OrderDraftItem>[];
  var _mode = _OrderMode.kilo;
  var _detailsExpanded = false;
  String? _customerId;
  String? _serviceId;
  String? _employeeId;
  String _paymentMethod = 'Tunai';

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
    final customers = data.customers;
    final services = data.services
        .where((service) => service.isActive)
        .toList();
    final employees = data.employees;
    final selectedEmployeeId = _employeeId ?? employees.first.id;
    final selectedService = services
        .where((service) => service.id == _serviceId)
        .cast<PreviewService?>()
        .firstOrNull;
    final selectedCustomer = customers
        .where((customer) => customer.id == _customerId)
        .cast<PreviewCustomer?>()
        .firstOrNull;
    final quickServices = services
        .where((service) {
          final group = service.effectiveGroup.toLowerCase();
          final unit = service.unit.toUpperCase();
          return switch (_mode) {
            _OrderMode.kilo ||
            _OrderMode.mix => group == 'kiloan' || unit == 'KG',
            _OrderMode.unit => group != 'kiloan' && unit != 'KG',
          };
        })
        .take(_mode == _OrderMode.unit ? 8 : 9)
        .toList();
    final total = _items.fold<int>(0, (sum, item) => sum + item.total);
    final strings = ref.strings;

    return Scaffold(
      appBar: AppBar(title: Text(strings.addOrder)),
      body: ResponsivePage(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: customers.isEmpty || services.isEmpty
            ? AppStateView.empty(
                title: strings.isEnglish
                    ? 'Master data is incomplete'
                    : 'Data master belum lengkap',
                message: strings.isEnglish
                    ? 'Add at least one customer and one service before creating an order.'
                    : 'Tambahkan minimal satu pelanggan dan satu layanan sebelum membuat pesanan.',
              )
            : Form(
                key: _formKey,
                child: ListView(
                  children: [
                    _QuickHeader(
                      title: strings.isEnglish
                          ? 'Quick Order'
                          : 'Pesanan Cepat',
                      subtitle: strings.isEnglish
                          ? 'Use the big buttons first. Details can be filled later.'
                          : 'Pakai tombol besar dulu. Detail bisa diisi belakangan.',
                    ),
                    const SizedBox(height: 16),
                    _StepTitle(
                      number: 1,
                      title: strings.isEnglish
                          ? 'Choose customer'
                          : 'Pilih pelanggan',
                    ),
                    FormField<String>(
                      initialValue: _customerId,
                      validator: (value) => value == null
                          ? (strings.isEnglish
                                ? 'Customer is required.'
                                : 'Pelanggan wajib dipilih.')
                          : null,
                      builder: (field) => Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _CustomerQuickButton(
                            customer: selectedCustomer,
                            hasError: field.hasError,
                            errorText: field.errorText,
                            onPick: () async {
                              final customer = await _pickCustomer(
                                context,
                                customers,
                              );
                              if (customer == null || !mounted) {
                                return;
                              }
                              setState(() => _customerId = customer.id);
                              field.didChange(customer.id);
                            },
                            onAdd: () async {
                              final customer = await _createQuickCustomer(
                                context,
                              );
                              if (customer == null || !mounted) {
                                return;
                              }
                              setState(() => _customerId = customer.id);
                              field.didChange(customer.id);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _StepTitle(
                      number: 2,
                      title: strings.isEnglish
                          ? 'Choose order type'
                          : 'Pilih jenis pesanan',
                    ),
                    _ModeSelector(
                      selected: _mode,
                      onChanged: (mode) => setState(() {
                        _mode = mode;
                        _serviceId = null;
                        _quantityController.text = mode == _OrderMode.unit
                            ? '1'
                            : '3';
                      }),
                    ),
                    const SizedBox(height: 12),
                    _StepTitle(
                      number: 3,
                      title: strings.isEnglish
                          ? 'Tap service and amount'
                          : 'Pencet layanan dan isi jumlah',
                    ),
                    if (quickServices.isNotEmpty)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final service in quickServices)
                            _ServiceQuickButton(
                              service: service,
                              selected: service.id == _serviceId,
                              onTap: () => _selectService(service),
                            ),
                        ],
                      ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final service = await _pickService(context, services);
                        if (service == null || !mounted) {
                          return;
                        }
                        _selectService(service);
                      },
                      icon: const Icon(Icons.search),
                      label: Text(
                        strings.isEnglish
                            ? 'Search another service'
                            : 'Cari layanan lain',
                      ),
                    ),
                    const SizedBox(height: 12),
                    _QuantityStepper(
                      controller: _quantityController,
                      unit:
                          selectedService?.unit ??
                          (_mode == _OrderMode.unit ? 'PCS' : 'KG'),
                      isKilo:
                          (selectedService?.unit ?? 'KG').toUpperCase() == 'KG',
                      onChanged: () => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: selectedService == null
                          ? null
                          : () => _addItem(selectedService),
                      icon: const Icon(Icons.add),
                      label: Text(
                        strings.isEnglish
                            ? 'Add to order'
                            : 'Masukkan ke pesanan',
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_items.isEmpty)
                      _EmptyItemsCard(strings: strings)
                    else ...[
                      for (final item in _items)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _DraftItemTile(
                            item: item,
                            onDelete: () => setState(() => _items.remove(item)),
                          ),
                        ),
                    ],
                    const SizedBox(height: 16),
                    _TotalBar(total: total),
                    const SizedBox(height: 12),
                    ExpansionTile(
                      initiallyExpanded: _detailsExpanded,
                      onExpansionChanged: (value) =>
                          setState(() => _detailsExpanded = value),
                      tilePadding: EdgeInsets.zero,
                      title: Text(
                        strings.isEnglish
                            ? 'Optional details'
                            : 'Detail opsional',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      children: [
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _paidController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: strings.isEnglish
                                ? 'Down payment / initial payment'
                                : 'DP / pembayaran awal',
                          ),
                          validator: (value) {
                            final amount = int.tryParse(value ?? '') ?? 0;
                            if (_items.isEmpty) {
                              return strings.isEnglish
                                  ? 'Add order items first.'
                                  : 'Tambahkan item pesanan dulu.';
                            }
                            if (amount < 0) {
                              return strings.isEnglish
                                  ? 'Amount is invalid.'
                                  : 'Nominal tidak valid.';
                            }
                            if (amount > total) {
                              return strings.isEnglish
                                  ? 'Payment exceeds total.'
                                  : 'Pembayaran melebihi total.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: _paymentMethod,
                          items: const [
                            DropdownMenuItem(
                              value: 'Tunai',
                              child: Text('Tunai'),
                            ),
                            DropdownMenuItem(
                              value: 'Transfer',
                              child: Text('Transfer'),
                            ),
                            DropdownMenuItem(
                              value: 'QRIS',
                              child: Text('QRIS'),
                            ),
                          ],
                          onChanged: (value) => setState(
                            () => _paymentMethod = value ?? _paymentMethod,
                          ),
                          decoration: InputDecoration(
                            labelText: strings.method,
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: selectedEmployeeId,
                          items: [
                            for (final employee in employees)
                              DropdownMenuItem(
                                value: employee.id,
                                child: Text(employee.name),
                              ),
                          ],
                          onChanged: (value) => setState(
                            () => _employeeId = value ?? selectedEmployeeId,
                          ),
                          decoration: InputDecoration(
                            labelText: strings.employee,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _noteController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            labelText: strings.isEnglish
                                ? 'Order note'
                                : 'Catatan pesanan',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _submit,
                      icon: const Icon(Icons.receipt_long_outlined),
                      label: Text(
                        strings.isEnglish
                            ? 'Save and Show Receipt'
                            : 'Simpan dan Tampilkan Struk',
                      ),
                    ),
                  ],
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
      builder: (context) => _ServicePickerSheet(services: services),
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
                labelText: strings.isEnglish ? 'WhatsApp number' : 'Nomor WA',
                prefixIcon: const Icon(Icons.chat_outlined),
              ),
              validator: (value) =>
                  (value ?? '').trim().length < 8 ? strings.invalidPhone : null,
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
      return ref
          .read(previewDataProvider.notifier)
          .addCustomer(
            name: result.name,
            phone: result.phone,
            address: result.address,
            note: '',
          );
    } on StateError catch (error) {
      showAppSnackBar(error.message);
      return null;
    }
  }

  void _selectService(PreviewService service) {
    final quantity = double.tryParse(_quantityController.text) ?? 0;
    setState(() {
      _serviceId = service.id;
      if (service.unit.toUpperCase() == 'KG' && quantity < 3) {
        _quantityController.text = '3';
      }
      if (service.unit.toUpperCase() != 'KG' && quantity <= 0) {
        _quantityController.text = '1';
      }
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

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    try {
      final order = ref
          .read(previewDataProvider.notifier)
          .createOrderWithItems(
            customerId: _customerId!,
            items: [
              for (final item in _items)
                (serviceId: item.service.id, quantity: item.quantity),
            ],
            paidAmount: int.tryParse(_paidController.text) ?? 0,
            paymentMethod: _paymentMethod,
            employeeId: _employeeId ?? 'employee-1',
            note: _noteController.text,
          );
      if (!mounted) {
        return;
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
    } on StateError catch (error) {
      showAppSnackBar(error.message);
    }
  }
}

enum _OrderMode { kilo, unit, mix }

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

class _QuickHeader extends StatelessWidget {
  const _QuickHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.softBlue,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        children: [
          const Icon(Icons.bolt_outlined, color: AppColors.primaryNavy),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.primaryNavy,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(color: AppColors.secondaryText),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerQuickButton extends StatelessWidget {
  const _CustomerQuickButton({
    required this.customer,
    required this.hasError,
    required this.errorText,
    required this.onPick,
    required this.onAdd,
  });

  final PreviewCustomer? customer;
  final bool hasError;
  final String? errorText;
  final VoidCallback onPick;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final selected = customer;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: onPick,
                icon: const Icon(Icons.search),
                label: Text(
                  selected == null
                      ? 'Pelanggan Lama'
                      : '${selected.name} - ${selected.phone}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Pelanggan Baru'),
              ),
            ),
          ],
        ),
        if (hasError && errorText != null) ...[
          const SizedBox(height: 6),
          Text(
            errorText!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  }
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
    final title = service.effectiveVariant.isEmpty
        ? service.name
        : '${service.effectiveItem} ${service.effectiveVariant}';
    return SizedBox(
      width: 168,
      height: 86,
      child: selected
          ? FilledButton(
              onPressed: onTap,
              child: _ServiceButtonContent(service: service, title: title),
            )
          : OutlinedButton(
              onPressed: onTap,
              child: _ServiceButtonContent(service: service, title: title),
            ),
    );
  }
}

class _ServiceButtonContent extends StatelessWidget {
  const _ServiceButtonContent({required this.service, required this.title});

  final PreviewService service;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          '${service.price.toRupiah()}/${service.unit}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({
    required this.controller,
    required this.unit,
    required this.isKilo,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String unit;
  final bool isKilo;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final label = isKilo ? 'Berat kg' : 'Jumlah';
    final step = isKilo ? 0.5 : 1.0;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconButton.filledTonal(
          tooltip: 'Kurangi',
          onPressed: () => _change(-step),
          icon: const Icon(Icons.remove),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextFormField(
            controller: controller,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            decoration: InputDecoration(labelText: '$label ($unit)'),
            onChanged: (_) => onChanged(),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          tooltip: 'Tambah',
          onPressed: () => _change(step),
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }

  void _change(double delta) {
    final current = double.tryParse(controller.text) ?? 0;
    final min = isKilo ? 3.0 : 1.0;
    final next = (current + delta).clamp(min, 999.0);
    controller.text = isKilo
        ? next.toStringAsFixed(1)
        : next.round().toString();
    onChanged();
  }
}

class _TotalBar extends StatelessWidget {
  const _TotalBar({required this.total});

  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.lightGold,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        children: [
          const Icon(Icons.receipt_long_outlined, color: AppColors.primaryNavy),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Total sementara',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          Text(
            total.toRupiah(),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.primaryNavy,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
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
  const _ServicePickerSheet({required this.services});

  final List<PreviewService> services;

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
      _PickerLevel.group => 'Pilih Kelompok Layanan',
      _PickerLevel.category => 'Pilih Kategori',
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
  const _DraftItemTile({required this.item, required this.onDelete});

  final _OrderDraftItem item;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(
          item.service.name,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          '${item.quantity.toStringAsFixed(1)} ${item.service.unit} x ${item.service.price.toRupiah()}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              item.total.toRupiah(),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            IconButton(
              tooltip: 'Hapus item',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyItemsCard extends StatelessWidget {
  const _EmptyItemsCard({required this.strings});

  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.shopping_basket_outlined),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                strings.isEnglish
                    ? 'Add kilo, item, or both in this order.'
                    : 'Tambahkan kiloan, satuan, atau keduanya dalam pesanan ini.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepTitle extends StatelessWidget {
  const _StepTitle({required this.number, required this.title});

  final int number;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          CircleAvatar(radius: 14, child: Text('$number')),
          const SizedBox(width: 10),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
