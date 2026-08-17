import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/failure.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/ui_action_queue.dart';
import '../../../core/widgets/app_bottom_sheet_body.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../core/widgets/responsive_page.dart';
import '../../auth/domain/user_role.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/customer.dart';
import 'customer_controller.dart';

class CustomersPage extends ConsumerStatefulWidget {
  const CustomersPage({super.key});

  @override
  ConsumerState<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends ConsumerState<CustomersPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customerControllerProvider);
    final role = ref.watch(authControllerProvider).value?.user?.role;
    final strings = ref.strings;
    final canImportContacts = role == UserRole.owner;
    final title = customersAsync.value == null
        ? strings.customers
        : strings.customersWithCount(customersAsync.value!.totalCount);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (canImportContacts)
            IconButton(
              tooltip: strings.importPhoneContacts,
              onPressed: () => _importContact(context),
              icon: const Icon(Icons.contacts_outlined),
            ),
          IconButton(
            tooltip: strings.addCustomer,
            onPressed: () => _showCustomerDialog(context),
            icon: const Icon(Icons.person_add_alt_1),
          ),
        ],
      ),
      floatingActionButton: customersAsync.value?.customers.isEmpty ?? true
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _showCustomerDialog(context),
              icon: const Icon(Icons.add),
              label: Text(strings.addCustomer),
            ),
      body: customersAsync.when(
        data: (state) => _CustomerListBody(
          state: state,
          query: _query,
          onQueryChanged: (value) => setState(() => _query = value),
          onRefresh: _refresh,
          onAdd: () => _showCustomerDialog(context),
          onEdit: role == UserRole.owner
              ? (customer) => _showCustomerDialog(context, customer: customer)
              : null,
          onPhone: (customer) => _showSnack(
            customer.hasPhone
                ? '${strings.phone}: ${customer.phone}'
                : strings.phoneMissing,
          ),
        ),
        loading: () => const LoadingStateView(),
        error: (error, _) => _CustomerErrorView(
          message: _messageForError(error),
          onRefresh: _refresh,
        ),
      ),
    );
  }

  Future<void> _refresh() {
    return ref.read(customerControllerProvider.notifier).refresh();
  }

  Future<void> _showCustomerDialog(
    BuildContext context, {
    Customer? customer,
  }) async {
    final isEditing = customer != null;
    final strings = ref.read(appLanguageProvider) == AppLanguage.en
        ? const AppStrings(AppLanguage.en)
        : const AppStrings(AppLanguage.id);
    final nameController = TextEditingController(text: customer?.name ?? '');
    final phoneController = TextEditingController(text: customer?.phone ?? '');
    final addressController = TextEditingController(
      text: customer?.address ?? '',
    );
    final noteController = TextEditingController(text: customer?.note ?? '');
    final formKey = GlobalKey<FormState>();

    final result = await showAppModalBottomSheet<_CustomerInput>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return Form(
          key: formKey,
          child: AppBottomSheetBody(
            children: [
              Text(
                isEditing ? strings.editCustomer : strings.addCustomer,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                strings.isEnglish
                    ? 'Name is required. WhatsApp number can be added later.'
                    : 'Nama wajib. Nomor WA bisa ditambahkan nanti.',
                style: const TextStyle(color: AppColors.secondaryText),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: nameController,
                autofocus: !isEditing,
                decoration: InputDecoration(
                  labelText: strings.name,
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
              const SizedBox(height: 8),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(
                  strings.isEnglish ? 'Optional details' : 'Detail opsional',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                children: [
                  TextFormField(
                    controller: addressController,
                    decoration: InputDecoration(
                      labelText: strings.address,
                      prefixIcon: const Icon(Icons.place_outlined),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: noteController,
                    decoration: InputDecoration(
                      labelText: strings.note,
                      prefixIcon: const Icon(Icons.note_alt_outlined),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  if (!formKey.currentState!.validate()) {
                    return;
                  }
                  Navigator.of(context).pop(
                    _CustomerInput(
                      name: nameController.text,
                      phone: phoneController.text,
                      address: addressController.text,
                      note: noteController.text,
                    ),
                  );
                },
                icon: Icon(
                  isEditing ? Icons.check_circle_outline : Icons.save_outlined,
                ),
                label: Text(isEditing ? strings.saveChanges : strings.save),
              ),
            ],
          ),
        );
      },
    );

    nameController.dispose();
    phoneController.dispose();
    addressController.dispose();
    noteController.dispose();

    if (result == null || !mounted) {
      return;
    }
    await waitForTransientUiDismissal();
    if (!mounted) {
      return;
    }
    try {
      final controller = ref.read(customerControllerProvider.notifier);
      if (isEditing) {
        await controller.updateCustomer(
          id: customer.id,
          name: result.name,
          phone: result.phone,
          address: result.address,
          note: result.note,
        );
      } else {
        await controller.addCustomer(
          name: result.name,
          phone: result.phone,
          address: result.address,
          note: result.note,
        );
      }
      if (mounted) {
        _showSnack(isEditing ? strings.customerUpdated : strings.customerAdded);
      }
    } catch (error) {
      if (mounted) {
        _showSnack(_messageForError(error));
      }
    }
  }

  Future<void> _importContact(BuildContext context) async {
    final permission = await FlutterContacts.permissions.request(
      PermissionType.read,
    );
    if (!context.mounted) {
      return;
    }
    if (permission != PermissionStatus.granted) {
      _showSnack('Izin kontak belum diberikan.');
      return;
    }

    final contacts = await FlutterContacts.getAll(
      properties: {ContactProperty.phone},
    );
    if (!context.mounted) {
      return;
    }
    final candidates =
        contacts
            .where(
              (contact) =>
                  (contact.displayName ?? '').trim().isNotEmpty &&
                  contact.phones.any((phone) => phone.number.trim().isNotEmpty),
            )
            .map(
              (contact) => _ImportedContact(
                name: (contact.displayName ?? '').trim(),
                phone: contact.phones
                    .map((phone) => phone.number.trim())
                    .firstWhere((phone) => phone.isNotEmpty, orElse: () => ''),
              ),
            )
            .where((contact) => contact.phone.isNotEmpty)
            .toList()
          ..sort((first, second) => first.name.compareTo(second.name));

    if (candidates.isEmpty) {
      _showSnack('Kontak dengan nomor telepon tidak ditemukan.');
      return;
    }

    final selected = await _showContactPicker(context, candidates);
    if (selected == null || !mounted) {
      return;
    }
    await waitForTransientUiDismissal();
    if (!mounted) {
      return;
    }
    try {
      await ref
          .read(customerControllerProvider.notifier)
          .addCustomer(
            name: selected.name,
            phone: selected.phone,
            address: '',
            note: 'Import kontak HP',
          );
      if (mounted) {
        final strings = ref.read(appLanguageProvider) == AppLanguage.en
            ? const AppStrings(AppLanguage.en)
            : const AppStrings(AppLanguage.id);
        _showSnack(strings.imported(selected.name));
      }
    } catch (error) {
      if (mounted) {
        _showSnack(_messageForError(error));
      }
    }
  }

  Future<_ImportedContact?> _showContactPicker(
    BuildContext context,
    List<_ImportedContact> contacts,
  ) {
    var query = '';
    return showAppModalBottomSheet<_ImportedContact>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = contacts.where((contact) {
              final text = '${contact.name} ${contact.phone}'.toLowerCase();
              return text.contains(query.toLowerCase());
            }).toList();

            return AppBottomSheetBody(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Import Kontak HP',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  decoration: const InputDecoration(
                    hintText: 'Cari nama atau nomor',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) => setModalState(() => query = value),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 420,
                  child: filtered.isEmpty
                      ? const Center(child: Text('Kontak tidak ditemukan.'))
                      : ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final contact = filtered[index];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const CircleAvatar(
                                child: Icon(Icons.person_outline),
                              ),
                              title: Text(contact.name),
                              subtitle: Text(contact.phone),
                              onTap: () => Navigator.of(context).pop(contact),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSnack(String message) {
    showAppSnackBar(message);
  }
}

class _CustomerListBody extends ConsumerWidget {
  const _CustomerListBody({
    required this.state,
    required this.query,
    required this.onQueryChanged,
    required this.onRefresh,
    required this.onAdd,
    required this.onPhone,
    this.onEdit,
  });

  final CustomerListState state;
  final String query;
  final ValueChanged<String> onQueryChanged;
  final Future<void> Function() onRefresh;
  final VoidCallback onAdd;
  final ValueChanged<Customer>? onEdit;
  final ValueChanged<Customer> onPhone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.strings;
    final customers = state.customers.where((customer) {
      final text =
          '${customer.name} ${customer.phone ?? ''} ${customer.address}'
              .toLowerCase();
      return text.contains(query.toLowerCase());
    }).toList();

    return ResponsivePage(
      padding: EdgeInsets.fromLTRB(16, 8, 16, customers.isEmpty ? 24 : 96),
      child: Column(
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: strings.searchCustomers,
              prefixIcon: const Icon(Icons.search),
            ),
            onChanged: onQueryChanged,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: customers.isEmpty
                ? RefreshIndicator(
                    onRefresh: onRefresh,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 80),
                        AppStateView.empty(
                          title: query.trim().isEmpty
                              ? strings.noCustomersTitle
                              : (strings.isEnglish
                                    ? 'Customer not found'
                                    : 'Pelanggan tidak ditemukan'),
                          message: query.trim().isEmpty
                              ? strings.noCustomersMessage
                              : (strings.isEnglish
                                    ? 'Try another name or phone number.'
                                    : 'Coba nama atau nomor lain.'),
                          actionLabel: query.trim().isEmpty
                              ? strings.addCustomer
                              : null,
                          onAction: query.trim().isEmpty ? onAdd : null,
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: onRefresh,
                    child: ListView.separated(
                      padding: const EdgeInsets.only(bottom: 24),
                      itemCount: customers.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final customer = customers[index];
                        final phoneText = customer.hasPhone
                            ? customer.phone!
                            : strings.phoneMissingShort;
                        final addressText = customer.address.isEmpty
                            ? strings.addressMissing
                            : customer.address;
                        return Card(
                          child: ListTile(
                            minTileHeight: 84,
                            onTap: onEdit == null
                                ? null
                                : () => onEdit!(customer),
                            leading: CircleAvatar(
                              backgroundColor: AppColors.softMint,
                              child: Text(
                                customer.name.trim().isEmpty
                                    ? '?'
                                    : customer.name.characters.first
                                          .toUpperCase(),
                                style: const TextStyle(
                                  color: AppColors.primaryNavy,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            title: Text(
                              customer.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            subtitle: Text('$phoneText\n$addressText'),
                            isThreeLine: true,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (onEdit != null)
                                  IconButton(
                                    tooltip: strings.editCustomer,
                                    onPressed: () => onEdit!(customer),
                                    icon: const Icon(Icons.edit_outlined),
                                  ),
                                IconButton(
                                  tooltip: customer.hasPhone
                                      ? strings.phone
                                      : strings.phoneMissing,
                                  onPressed: customer.hasPhone
                                      ? () => onPhone(customer)
                                      : null,
                                  icon: const Icon(Icons.call_outlined),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _CustomerErrorView extends StatelessWidget {
  const _CustomerErrorView({required this.message, required this.onRefresh});

  final String message;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return ResponsivePage(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 80),
            AppStateView.error(
              title: 'Data pelanggan belum bisa dimuat',
              message: message,
              actionLabel: 'Coba Lagi',
              onAction: onRefresh,
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomerInput {
  const _CustomerInput({
    required this.name,
    required this.phone,
    required this.address,
    required this.note,
  });

  final String name;
  final String phone;
  final String address;
  final String note;
}

class _ImportedContact {
  const _ImportedContact({required this.name, required this.phone});

  final String name;
  final String phone;
}

String _messageForError(Object error) {
  if (error is Failure) {
    return error.message;
  }
  if (error is StateError) {
    return error.message;
  }
  return error.toString();
}
