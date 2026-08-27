
import sys

file_path = r'c:\Users\ASUS\Documents\GitHub\LaundryApp\laundry_app_flutter\lib\features\orders\presentation\order_create_page.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

new_build_and_helpers = '''
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
    final onlineCustomers = ref.watch(customerControllerProvider).value?.customers;
    final customers = onlineCustomers == null
        ? data.customers
        : [for (final c in onlineCustomers) PreviewCustomer(id: c.id, name: c.name, phone: c.phone ?? '', normalizedPhone: c.normalizedPhone ?? '', address: c.address, note: c.note, createdAt: c.createdAt)];
    
    final serviceSource = ref.watch(serviceControllerProvider).value ?? data.services;
    final services = serviceSource.where((service) => service.isActive).toList();
    final employees = data.employees;
    
    final selectedEmployeeId = _employeeId ?? employees.firstOrNull?.id;
    final selectedCustomer = customers.where((c) => c.id == _customerId).cast<PreviewCustomer?>().firstOrNull;
    
    final quickServices = services.where((service) {
      final group = service.effectiveGroup.toLowerCase();
      final unit = service.unit.toUpperCase();
      return switch (_mode) {
        _OrderMode.kilo || _OrderMode.mix => group == 'kiloan' || unit == 'KG',
        _OrderMode.unit => group != 'kiloan' && unit != 'KG',
      };
    }).take(_mode == _OrderMode.unit ? 8 : 9).toList();
    
    final total = _items.fold<int>(0, (sum, item) => sum + item.total);
    final strings = ref.strings;

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.addOrder),
        elevation: 0,
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.primaryNavy,
      ),
      backgroundColor: AppColors.softBackground,
      body: customers.isEmpty || services.isEmpty || employees.isEmpty
          ? AppStateView.empty(
              title: strings.isEnglish ? 'Master data is incomplete' : 'Data master belum lengkap',
              message: strings.isEnglish ? 'Add at least one customer, service, and employee.' : 'Tambahkan minimal satu pelanggan, layanan, dan karyawan.',
            )
          : Form(
              key: _formKey,
              child: Column(
                children: [
                  // 1. HEADER: Customer & Mode
                  Container(
                    color: AppColors.surface,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Column(
                      children: [
                        _buildCompactCustomerSelector(selectedCustomer, customers),
                        const SizedBox(height: 12),
                        _ModeSelector(
                          selected: _mode,
                          onChanged: (mode) => setState(() {
                            _mode = mode;
                            _serviceId = null;
                            _quantityController.text = mode == _OrderMode.unit ? '1' : '3';
                          }),
                        ),
                      ],
                    ),
                  ),
                  
                  // 2. MAIN: Cart & Quick Services
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (_items.isNotEmpty) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Keranjang Pesanan', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.primaryNavy)),
                              Text(' Item', style: const TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          for (final item in _items)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _DraftItemTile(
                                item: item,
                                onDelete: () => setState(() => _items.remove(item)),
                              ),
                            ),
                          const Divider(height: 32),
                        ],

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(strings.isEnglish ? 'Quick Services' : 'Layanan Cepat', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.primaryNavy)),
                            TextButton.icon(
                              onPressed: () async {
                                final service = await _pickService(context, services);
                                if (service != null && mounted) _selectServiceAndShowDialog(service);
                              },
                              icon: const Icon(Icons.search, size: 18),
                              label: Text(strings.isEnglish ? 'Lainnya' : 'Lainnya'),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.primaryBlue,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                minimumSize: Size.zero,
                              ),
                            )
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (quickServices.isNotEmpty)
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final service in quickServices)
                                _ServiceQuickButton(
                                  service: service,
                                  selected: service.id == _serviceId,
                                  onTap: () => _selectServiceAndShowDialog(service),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  
                  // 3. FOOTER: Sticky Action Bar
                  _buildStickyBottomBar(total, employees, selectedEmployeeId, strings),
                ],
              ),
            ),
    );
  }

  Widget _buildCompactCustomerSelector(PreviewCustomer? selected, List<PreviewCustomer> customers) {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () async {
              final customer = await _pickCustomer(context, customers);
              if (customer != null && mounted) setState(() => _customerId = customer.id);
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.outline.withOpacity(0.2),
                border: Border.all(color: AppColors.outline),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person, color: AppColors.primaryNavy, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      selected == null ? 'Pilih Pelanggan...' : ' ()',
                      style: TextStyle(
                        fontWeight: selected == null ? FontWeight.normal : FontWeight.w700,
                        color: selected == null ? AppColors.secondaryText : AppColors.primaryNavy,
                        fontSize: 15,
                      ),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down, color: AppColors.secondaryText),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          height: 48,
          width: 48,
          decoration: BoxDecoration(
            color: AppColors.primaryBlue,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: AppColors.primaryBlue.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
          ),
          child: IconButton(
            onPressed: () async {
              final customer = await _createQuickCustomer(context);
              if (customer != null && mounted) setState(() => _customerId = customer.id);
            },
            icon: const Icon(Icons.person_add, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildStickyBottomBar(int total, List<PreviewEmployee> employees, String? selectedEmployeeId, AppStrings strings) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(color: AppColors.primaryNavy.withOpacity(0.08), blurRadius: 24, offset: const Offset(0, -8)),
        ],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Tagihan', style: TextStyle(color: AppColors.secondaryText, fontSize: 13, fontWeight: FontWeight.w600)),
                    Text(
                      total.toRupiah(),
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: AppColors.primaryNavy),
                    ),
                  ],
                ),
                FilledButton.tonalIcon(
                  onPressed: () => _showOptionalDetailsSheet(employees, selectedEmployeeId, strings),
                  icon: const Icon(Icons.tune, size: 18),
                  label: const Text('Detail / DP', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.softBlue,
                    foregroundColor: AppColors.primaryNavy,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.check_circle, size: 24),
                label: const Text('SIMPAN PESANAN', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryNavy,
                  shadowColor: AppColors.primaryNavy.withOpacity(0.5),
                  elevation: 8,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _selectServiceAndShowDialog(PreviewService service) {
    _selectService(service);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(service.name, style: const TextStyle(color: AppColors.primaryNavy, fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Tentukan jumlah/berat untuk layanan ini:', style: TextStyle(color: AppColors.secondaryText)),
            const SizedBox(height: 24),
            _QuantityStepper(
              controller: _quantityController,
              unit: service.unit,
              isKilo: service.unit.toUpperCase() == 'KG',
              onChanged: () {},
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text('Batal', style: TextStyle(color: AppColors.secondaryText))
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _addItem(service);
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Tambahkan', style: TextStyle(fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  void _showOptionalDetailsSheet(List<PreviewEmployee> employees, String? selectedEmployeeId, AppStrings strings) {
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
            left: 24, right: 24, top: 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.outline, borderRadius: BorderRadius.circular(2))),
                ),
                const SizedBox(height: 20),
                Text('Detail Opsional', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, color: AppColors.primaryNavy)),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _paidController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'DP / Pembayaran Awal', 
                    prefixIcon: const Icon(Icons.payments_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _paymentMethod,
                  items: const [
                    DropdownMenuItem(value: 'Tunai', child: Text('Tunai')),
                    DropdownMenuItem(value: 'Transfer', child: Text('Transfer')),
                    DropdownMenuItem(value: 'QRIS', child: Text('QRIS')),
                  ],
                  onChanged: (value) {
                    setState(() => _paymentMethod = value ?? _paymentMethod);
                    setSheetState(() {});
                  },
                  decoration: InputDecoration(
                    labelText: 'Metode Pembayaran', 
                    prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedEmployeeId,
                  items: [
                    for (final employee in employees)
                      DropdownMenuItem(value: employee.id, child: Text(employee.name)),
                  ],
                  onChanged: (value) {
                    setState(() => _employeeId = value ?? selectedEmployeeId);
                    setSheetState(() {});
                  },
                  decoration: InputDecoration(
                    labelText: 'Pilih Kasir', 
                    prefixIcon: const Icon(Icons.badge_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _noteController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Catatan Pesanan', 
                    prefixIcon: const Icon(Icons.notes),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Cetak Struk Otomatis', style: TextStyle(fontWeight: FontWeight.w600)),
                  value: _showReceiptAfterSave,
                  activeColor: AppColors.primaryNavy,
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('SELESAI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
'''

new_lines = []
in_build_method = False
brace_count = 0

for line in lines:
    if line.strip().startswith('@override') and 'Widget build(BuildContext context)' in ''.join(lines[lines.index(line):lines.index(line)+2]):
        in_build_method = True
        new_lines.append(new_build_and_helpers)
        brace_count = 0
        continue
    
    if in_build_method:
        brace_count += line.count('{')
        brace_count -= line.count('}')
        if brace_count == 0 and line.strip() == '}':
            # Finished skipping the old build method
            in_build_method = False
            # Wait, the new_build_and_helpers ALREADY contains the closing brace for build!
            continue
    else:
        new_lines.append(line)

with open(file_path, 'w', encoding='utf-8') as f:
    f.writelines(new_lines)

