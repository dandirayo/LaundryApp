import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/failure.dart';
import '../../../core/errors/user_error_message.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/ui_action_queue.dart';
import '../../../core/widgets/app_bottom_sheet_body.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../core/widgets/responsive_page.dart';
import '../../auth/domain/user_role.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/device_contact_repository.dart';
import '../domain/customer.dart';
import '../domain/contact_import.dart';
import 'customer_controller.dart';
import 'contact_account_picker.dart';

class CustomersPage extends ConsumerStatefulWidget {
  const CustomersPage({super.key});

  @override
  ConsumerState<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends ConsumerState<CustomersPage> {
  final _deviceContacts = DeviceContactRepository();
  String _query = '';
  var _isSyncingContacts = false;

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customerControllerProvider);
    final role = ref.watch(authControllerProvider).value?.user?.role;
    final strings = ref.strings;
    final canImportContacts = role != null;
    final title = customersAsync.value == null
        ? strings.customers
        : strings.customersWithCount(customersAsync.value!.totalCount);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (canImportContacts)
            IconButton(
              tooltip: strings.syncPhoneContacts,
              onPressed: _isSyncingContacts
                  ? null
                  : () => _syncContacts(context),
              icon: _isSyncingContacts
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync),
            ),
          IconButton(
            tooltip: strings.addCustomer,
            onPressed: () => _showAddCustomerOptions(context),
            icon: const Icon(Icons.person_add_alt_1),
          ),
        ],
      ),
      floatingActionButton: customersAsync.value?.customers.isEmpty ?? true
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _showAddCustomerOptions(context),
              icon: const Icon(Icons.add),
              label: Text(strings.addCustomer),
            ),
      body: customersAsync.when(
        data: (state) => _CustomerListBody(
          state: state,
          query: _query,
          onQueryChanged: (value) => setState(() => _query = value),
          onRefresh: _refresh,
          onAdd: () => _showAddCustomerOptions(context),
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

  Future<void> _showAddCustomerOptions(BuildContext context) async {
    final selection = await showAppModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => AppBottomSheetBody(
        children: [
          Text(
            'Tambah Pelanggan',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Pilih cara menambahkan pelanggan.',
            style: TextStyle(color: AppColors.secondaryText),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(child: Icon(Icons.edit_outlined)),
            title: const Text('Isi Manual'),
            subtitle: const Text('Masukkan pelanggan baru secara manual.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).pop('manual'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(child: Icon(Icons.contacts_outlined)),
            title: const Text('Ambil dari Kontak'),
            subtitle: const Text('Pilih dari kontak perangkat.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).pop('contacts'),
          ),
          const SizedBox(height: 8),
          const Text(
            'Kontak Google akan tampil jika sudah tersinkron ke kontak perangkat.',
            style: TextStyle(color: AppColors.secondaryText, fontSize: 12),
          ),
        ],
      ),
    );
    if (!context.mounted) return;
    if (selection == 'manual') {
      await _showCustomerDialog(context);
    } else if (selection == 'contacts') {
      await _importContact(context);
    }
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
    final candidates = await _loadDeviceContactCandidates(context);
    if (candidates == null || !context.mounted) return;

    final candidate = await _showContactPicker(context, candidates);
    if (candidate == null || !context.mounted) {
      return;
    }
    final selectedPhone = await _selectContactPhone(context, candidate);
    if (selectedPhone == null || !context.mounted) return;
    final selected = ContactImportSelection(
      name: candidate.name,
      phone: selectedPhone,
      address: candidate.address,
    );
    final duplicate = findCustomerWithNormalizedPhone(
      ref.read(customerControllerProvider).value?.customers ?? const [],
      selected.phone,
    );
    if (duplicate != null) {
      await _showDuplicateContactDialog(context, duplicate);
      return;
    }
    if (!await _confirmContactImport(context, selected) || !context.mounted) {
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
            address: selected.address,
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

  Future<void> _syncContacts(BuildContext context) async {
    if (_isSyncingContacts) return;
    setState(() => _isSyncingContacts = true);
    try {
      final candidates = await _loadDeviceContactCandidates(context);
      if (candidates == null || !context.mounted) return;
      if (!await confirmContactSync(context, candidates.length) ||
          !context.mounted) {
        return;
      }
      final result = await ref
          .read(customerControllerProvider.notifier)
          .syncContacts(candidates);
      if (context.mounted) {
        _showSnack(_contactSyncMessage(result));
      }
    } catch (error) {
      if (context.mounted) {
        _showSnack(
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
        _showSnack(
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
      final candidates = await fetchContactsFromSelectedAccount(
        context,
        _deviceContacts,
      );
      if (candidates == null) return null;
      if (candidates.isEmpty && context.mounted) {
        _showSnack('Daftar kontak perangkat kosong.');
      }
      return candidates.isEmpty ? null : candidates;
    } catch (error) {
      if (context.mounted) {
        _showSnack(
          userErrorMessage(
            error,
            fallback: 'Kontak perangkat gagal dimuat. Coba lagi.',
          ),
        );
      }
      return null;
    }
  }

  Future<ContactImportCandidate?> _showContactPicker(
    BuildContext context,
    List<ContactImportCandidate> contacts,
  ) {
    var query = '';
    return showAppModalBottomSheet<ContactImportCandidate>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = contacts.where((contact) {
              final text = '${contact.name} ${contact.phones.join(' ')}'
                  .toLowerCase();
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
                              leading: CircleAvatar(
                                child: Text(
                                  contact.name.characters.first.toUpperCase(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              title: Text(contact.name),
                              subtitle: Text(
                                contact.primaryPhone.isEmpty
                                    ? 'Tanpa nomor telepon'
                                    : contact.primaryPhone,
                              ),
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

  Future<String?> _selectContactPhone(
    BuildContext context,
    ContactImportCandidate contact,
  ) async {
    if (contact.phones.isEmpty) return '';
    if (contact.phones.length == 1) return contact.phones.single;
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Pilih nomor ${contact.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final phone in contact.phones)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.phone_outlined),
                title: Text(phone),
                onTap: () => Navigator.of(context).pop(phone),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Batal'),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmContactImport(
    BuildContext context,
    ContactImportSelection contact,
  ) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Tambahkan sebagai pelanggan?'),
            content: Text(
              contact.phone.isEmpty
                  ? '${contact.name}\nTanpa nomor telepon'
                  : '${contact.name}\n${contact.phone}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Batal'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Tambahkan'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _showDuplicateContactDialog(
    BuildContext context,
    Customer customer,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pelanggan sudah tersedia'),
        content: Text(
          'Pelanggan dengan nomor ini sudah tersedia.\n\n${customer.name}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() => _query = customer.name);
            },
            child: const Text('Buka Pelanggan'),
          ),
        ],
      ),
    );
  }

  Future<void> _showContactPermissionDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Izin kontak diperlukan'),
        content: const Text(
          'Izin kontak diperlukan untuk memilih pelanggan dari daftar kontak.',
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

  void _showSnack(String message) {
    showAppSnackBar(message);
  }
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

String _messageForError(Object error) {
  if (error is Failure) {
    return error.message;
  }
  if (error is StateError) {
    return error.message;
  }
  return userErrorMessage(
    error,
    fallback: 'Data pelanggan belum bisa diproses. Coba lagi.',
  );
}
