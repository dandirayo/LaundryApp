import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/extensions/currency_extensions.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../core/widgets/responsive_page.dart';
import '../../../shared/preview_data.dart';

class OrderCreatePage extends ConsumerStatefulWidget {
  const OrderCreatePage({super.key});

  @override
  ConsumerState<OrderCreatePage> createState() => _OrderCreatePageState();
}

class _OrderCreatePageState extends ConsumerState<OrderCreatePage> {
  final _quantityController = TextEditingController(text: '1');
  final _paidController = TextEditingController(text: '0');
  final _noteController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _customerId;
  String? _serviceId;
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
    final selectedService = services
        .where((service) => service.id == _serviceId)
        .cast<PreviewService?>()
        .firstOrNull;
    final quantity = double.tryParse(_quantityController.text) ?? 0;
    final total = selectedService == null
        ? 0
        : (selectedService.price * quantity).round();

    return Scaffold(
      appBar: AppBar(title: const Text('Tambah Pesanan')),
      body: ResponsivePage(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: customers.isEmpty || services.isEmpty
            ? AppStateView.empty(
                title: 'Data master belum lengkap',
                message:
                    'Tambahkan minimal satu pelanggan dan satu layanan sebelum membuat pesanan.',
              )
            : Form(
                key: _formKey,
                child: ListView(
                  children: [
                    _StepTitle(number: 1, title: 'Pilih pelanggan'),
                    DropdownButtonFormField<String>(
                      initialValue: _customerId,
                      items: [
                        for (final customer in customers)
                          DropdownMenuItem(
                            value: customer.id,
                            child: Text(customer.name),
                          ),
                      ],
                      onChanged: (value) => setState(() => _customerId = value),
                      decoration: const InputDecoration(labelText: 'Pelanggan'),
                      validator: (value) =>
                          value == null ? 'Pelanggan wajib dipilih.' : null,
                    ),
                    const SizedBox(height: 20),
                    _StepTitle(number: 2, title: 'Pilih layanan'),
                    DropdownButtonFormField<String>(
                      initialValue: _serviceId,
                      items: [
                        for (final service in services)
                          DropdownMenuItem(
                            value: service.id,
                            child: Text(
                              '${service.name} - ${service.price.toRupiah()}/${service.unit}',
                            ),
                          ),
                      ],
                      onChanged: (value) => setState(() => _serviceId = value),
                      decoration: const InputDecoration(labelText: 'Layanan'),
                      validator: (value) =>
                          value == null ? 'Layanan wajib dipilih.' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _quantityController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Berat/Jumlah',
                      ),
                      onChanged: (_) => setState(() {}),
                      validator: (value) =>
                          (double.tryParse(value ?? '') ?? 0) <= 0
                          ? 'Berat atau jumlah wajib lebih dari nol.'
                          : null,
                    ),
                    const SizedBox(height: 20),
                    _StepTitle(number: 3, title: 'Pembayaran'),
                    Text(
                      'Total sementara ${total.toRupiah()}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _paidController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'DP / pembayaran awal',
                      ),
                      validator: (value) {
                        final amount = int.tryParse(value ?? '') ?? 0;
                        if (amount < 0) {
                          return 'Nominal tidak valid.';
                        }
                        if (amount > total) {
                          return 'Pembayaran melebihi total.';
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
                      decoration: const InputDecoration(labelText: 'Metode'),
                    ),
                    const SizedBox(height: 20),
                    _StepTitle(number: 4, title: 'Catatan dan petugas'),
                    DropdownButtonFormField<String>(
                      initialValue: employees.first.id,
                      items: [
                        for (final employee in employees)
                          DropdownMenuItem(
                            value: employee.id,
                            child: Text(employee.name),
                          ),
                      ],
                      onChanged: (_) {},
                      decoration: const InputDecoration(labelText: 'Petugas'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _noteController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Catatan pesanan',
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _submit,
                      icon: const Icon(Icons.receipt_long_outlined),
                      label: const Text('Simpan dan Tampilkan Struk'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    try {
      final order = ref
          .read(previewDataProvider.notifier)
          .createOrder(
            customerId: _customerId!,
            serviceId: _serviceId!,
            quantity: double.parse(_quantityController.text),
            paidAmount: int.tryParse(_paidController.text) ?? 0,
            paymentMethod: _paymentMethod,
            employeeId: 'employee-1',
            note: _noteController.text,
          );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${order.orderNumber} berhasil dibuat.')),
      );
      context.go('/orders/${order.id}');
    } on StateError catch (error) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
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
