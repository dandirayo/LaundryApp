import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

import '../data/device_contact_repository.dart';
import '../domain/contact_import.dart';

Future<List<ContactImportCandidate>?> fetchContactsFromSelectedAccount(
  BuildContext context,
  DeviceContactRepository repository,
) async {
  final accounts = await repository.fetchAccounts();
  if (!context.mounted) return null;
  if (accounts.isEmpty) {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Akun kontak belum tersedia'),
        content: const Text(
          'Aktifkan sinkronisasi kontak akun Google yang diinginkan pada pengaturan HP, lalu coba lagi. Kontak tidak akan diimpor dari semua akun secara otomatis.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
    return null;
  }
  final account = await showDialog<Account>(
    context: context,
    builder: (context) => SimpleDialog(
      title: const Text('Pilih akun sumber kontak'),
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Text(
            'Hanya kontak dari akun yang dipilih akan dibaca. Akun Google harus sudah tersinkron ke HP.',
          ),
        ),
        for (final account in accounts)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, account),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.account_circle_outlined),
              title: Text(
                account.name.isEmpty ? 'Kontak perangkat' : account.name,
              ),
              subtitle: Text(
                account.type == 'com.google' ? 'Google Contacts' : account.type,
              ),
            ),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
      ],
    ),
  );
  if (account == null) return null;
  return repository.fetchContactCandidates(account: account);
}

Future<bool> confirmContactSync(BuildContext context, int count) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Impor kontak akun terpilih?'),
        content: Text(
          '$count kontak ditemukan. Kontak dengan nomor yang sudah terdaftar akan dilewati. Kontak lama dari akun lain yang sudah diimpor tidak akan dihapus.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Impor'),
          ),
        ],
      ),
    ) ??
    false;
