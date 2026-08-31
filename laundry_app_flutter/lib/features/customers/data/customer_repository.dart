import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/failure.dart';
import '../../../core/services/supabase_service.dart';
import '../domain/contact_import.dart';
import '../domain/customer.dart';

final class CustomerRepository {
  CustomerRepository({SupabaseClient? client})
    : _client = client ?? SupabaseService.maybeClient;

  final SupabaseClient? _client;

  bool get isOnline => _client != null;

  Future<List<Customer>> fetchCustomers({required String shopId}) async {
    final rows = await _requireClient()
        .from('customers')
        .select(_selectColumns)
        .eq('shop_id', shopId)
        .isFilter('deleted_at', null)
        .order('created_at', ascending: false);

    return [for (final row in rows) Customer.fromMap(row)];
  }

  Future<Customer> createCustomer({
    required String shopId,
    required String name,
    required String phone,
    required String address,
    required String note,
  }) async {
    final phoneValue = Customer.phoneFromInput(phone);
    final normalizedPhone = Customer.normalizeIndonesianPhone(phone);
    try {
      final row = await _requireClient()
          .from('customers')
          .insert({
            'shop_id': shopId,
            'name': name.trim(),
            'phone': phoneValue,
            'normalized_phone': normalizedPhone,
            'address': address.trim(),
            'note': note.trim(),
          })
          .select(_selectColumns)
          .single();

      return Customer.fromMap(row);
    } on PostgrestException catch (error) {
      throw _mapPostgrestException(error);
    }
  }

  Future<int> importCustomers({
    required String shopId,
    required List<ContactImportSelection> contacts,
    required String note,
  }) async {
    if (contacts.isEmpty) {
      return 0;
    }

    try {
      final rows = await _requireClient()
          .from('customers')
          .upsert(
            [
              for (final contact in contacts)
                {
                  'shop_id': shopId,
                  'name': contact.name.trim(),
                  'phone': Customer.phoneFromInput(contact.phone),
                  'normalized_phone': contact.normalizedPhone,
                  'address': contact.address.trim(),
                  'note': note.trim(),
                },
            ],
            onConflict: 'shop_id,normalized_phone',
            ignoreDuplicates: true,
          )
          .select('id');
      return rows.length;
    } on PostgrestException catch (error) {
      throw _mapPostgrestException(error);
    }
  }

  Future<Customer> updateCustomer({
    required String shopId,
    required String id,
    required String name,
    required String phone,
    required String address,
    required String note,
  }) async {
    final phoneValue = Customer.phoneFromInput(phone);
    final normalizedPhone = Customer.normalizeIndonesianPhone(phone);
    try {
      final row = await _requireClient()
          .from('customers')
          .update({
            'name': name.trim(),
            'phone': phoneValue,
            'normalized_phone': normalizedPhone,
            'address': address.trim(),
            'note': note.trim(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', id)
          .eq('shop_id', shopId)
          .select(_selectColumns)
          .single();

      return Customer.fromMap(row);
    } on PostgrestException catch (error) {
      throw _mapPostgrestException(error);
    }
  }

  RealtimeChannel subscribeToCustomers({
    required String shopId,
    required void Function() onChanged,
  }) {
    return _requireClient()
        .channel('public:customers:$shopId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'customers',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'shop_id',
            value: shopId,
          ),
          callback: (_) => onChanged(),
        )
        .subscribe();
  }

  Future<void> removeSubscription(RealtimeChannel channel) async {
    await _requireClient().removeChannel(channel);
  }

  SupabaseClient _requireClient() {
    final client = _client;
    if (client == null) {
      throw const Failure(
        code: 'supabase-not-configured',
        message: 'Supabase belum dikonfigurasi.',
      );
    }
    return client;
  }

  Failure _mapPostgrestException(PostgrestException error) {
    if (error.code == '23505') {
      return const Failure(
        code: 'customer-phone-duplicate',
        message: 'Nomor telepon sudah terdaftar.',
      );
    }
    return Failure(
      code: error.code ?? 'customer-save-failed',
      message: 'Data pelanggan gagal disimpan: ${error.message}',
      details: error,
    );
  }
}

const _selectColumns =
    'id, shop_id, name, phone, normalized_phone, address, note, created_at, updated_at';
