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
                      builder: (field) => _PickerField(
                        label: strings.customer,
                        value: selectedCustomer == null
                            ? (strings.isEnglish
                                  ? 'Search customer'
                                  : 'Cari pelanggan')
                            : '${selectedCustomer.name} - ${selectedCustomer.phone}',
                        hasError: field.hasError,
                        errorText: field.errorText,
                        onTap: () async {
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
                      ),
                    ),
                    const SizedBox(height: 20),
                    _StepTitle(
                      number: 2,
                      title: strings.isEnglish
                          ? 'Fill order items'
                          : 'Isi item pesanan',
                    ),
                    _PickerField(
                      label: strings.service,
                      value: selectedService == null
                          ? (strings.isEnglish
                                ? 'Search service'
                                : 'Cari layanan')
                          : '${selectedService.breadcrumb} - ${selectedService.price.toRupiah()}/${selectedService.unit}',
                      onTap: () async {
                        final service = await _pickService(context, services);
                        if (service == null || !mounted) {
                          return;
                        }
                        final quantity =
                            double.tryParse(_quantityController.text) ?? 0;
                        if (service.unit.toUpperCase() == 'KG' &&
                            quantity < 3) {
                          _quantityController.text = '3';
                        }
                        if (service.unit.toUpperCase() != 'KG' &&
                            quantity <= 0) {
                          _quantityController.text = '1';
                        }
                        setState(() => _serviceId = service.id);
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _quantityController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: selectedService?.unit == 'KG'
                                  ? (strings.isEnglish
                                        ? 'Weight kg'
                                        : 'Berat kg')
                                  : (strings.isEnglish ? 'Quantity' : 'Jumlah'),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 124,
                          height: 56,
                          child: FilledButton.icon(
                            onPressed: selectedService == null
                                ? null
                                : () => _addItem(selectedService),
                            icon: const Icon(Icons.add),
                            label: Text(strings.add),
                          ),
                        ),
                      ],
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
                    const SizedBox(height: 20),
                    _StepTitle(
                      number: 3,
                      title: strings.isEnglish ? 'Payment' : 'Pembayaran',
                    ),
                    Text(
                      '${strings.isEnglish ? 'Current total' : 'Total sementara'} ${total.toRupiah()}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
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
                        DropdownMenuItem(value: 'Tunai', child: Text('Tunai')),
                        DropdownMenuItem(
                          value: 'Transfer',
                          child: Text('Transfer'),
                        ),
                        DropdownMenuItem(value: 'QRIS', child: Text('QRIS')),
                      ],
                      onChanged: (value) => setState(
                        () => _paymentMethod = value ?? _paymentMethod,
                      ),
                      decoration: InputDecoration(labelText: strings.method),
                    ),
                    const SizedBox(height: 20),
                    _StepTitle(
                      number: 4,
                      title: strings.isEnglish
                          ? 'Note and staff'
                          : 'Catatan dan petugas',
                    ),
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
                      decoration: InputDecoration(labelText: strings.employee),
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

class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.label,
    required this.value,
    required this.onTap,
    this.hasError = false,
    this.errorText,
  });

  final String label;
  final String value;
  final VoidCallback onTap;
  final bool hasError;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          errorText: hasError ? errorText : null,
          suffixIcon: const Icon(Icons.search),
        ),
        child: Text(value, maxLines: 2, overflow: TextOverflow.ellipsis),
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
