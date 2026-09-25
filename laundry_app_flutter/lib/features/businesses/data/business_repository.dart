import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';
import '../domain/business.dart';

class BusinessRepository {
  BusinessRepository({SupabaseClient? client})
    : _client = client ?? SupabaseService.maybeClient;

  final SupabaseClient? _client;

  bool get isOnline => _client != null;

  Future<List<Business>> fetchBusinesses() async {
    final rows = await _requireClient()
        .from('businesses')
        .select('id, shop_id, owner_id, name, kind, status')
        .order('kind')
        .order('name');
    return [for (final row in rows) Business.fromMap(row)];
  }

  Future<List<BusinessAssignee>> fetchAssignees(String shopId) async {
    final rows = await _requireClient()
        .from('profiles')
        .select('id, employee_id, full_name')
        .eq('shop_id', shopId)
        .eq('role', 'EMPLOYEE')
        .eq('is_active', true)
        .order('full_name');
    return [
      for (final row in rows)
        BusinessAssignee(
          profileId: row['id'] as String,
          employeeId: row['employee_id'] as String?,
          name: (row['full_name'] ?? 'Karyawan') as String,
        ),
    ];
  }

  Future<Map<String, Set<String>>> fetchAssignments(
    List<String> businessIds,
  ) async {
    if (businessIds.isEmpty) return const {};
    final rows = await _requireClient()
        .from('business_members')
        .select('business_id, profile_id')
        .inFilter('business_id', businessIds)
        .eq('is_active', true);
    final result = <String, Set<String>>{};
    for (final row in rows) {
      result
          .putIfAbsent(row['business_id'] as String, () => <String>{})
          .add(row['profile_id'] as String);
    }
    return result;
  }

  Future<Business> createBusiness({
    required String shopId,
    required String ownerId,
    required String name,
    required BusinessKind kind,
  }) async {
    final row = await _requireClient()
        .from('businesses')
        .insert({
          'shop_id': shopId,
          'owner_id': ownerId,
          'name': name.trim(),
          'kind': kind.storageValue,
          'status': 'active',
        })
        .select('id, shop_id, owner_id, name, kind, status')
        .single();
    return Business.fromMap(row);
  }

  Future<void> setBusinessActive(String id, bool isActive) async {
    await _requireClient()
        .from('businesses')
        .update({'status': isActive ? 'active' : 'inactive'})
        .eq('id', id);
  }

  Future<void> setAssignment({
    required String businessId,
    required String profileId,
    required bool assigned,
  }) async {
    final existing = await _requireClient()
        .from('business_members')
        .select('id')
        .eq('business_id', businessId)
        .eq('profile_id', profileId)
        .maybeSingle();
    if (existing == null) {
      await _requireClient().from('business_members').insert({
        'business_id': businessId,
        'profile_id': profileId,
        'is_active': assigned,
      });
      return;
    }
    await _requireClient()
        .from('business_members')
        .update({'is_active': assigned})
        .eq('id', existing['id'] as String);
  }

  SupabaseClient _requireClient() => _client!;
}
