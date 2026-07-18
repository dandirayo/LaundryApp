import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/config/app_config.dart';
import '../../../core/errors/failure.dart';
import '../domain/app_user.dart';
import '../domain/user_role.dart';

abstract interface class AuthRepository {
  Future<AppUser?> restoreSession();

  Future<AppUser> signInWithEmailPassword({
    required String email,
    required String password,
  });

  Future<AppUser> signInPreview(UserRole role);

  Future<AppUser> updateProfile({required String name, required String phone});

  Future<void> signOut();
}

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository({
    required SupabaseClient? client,
    required FlutterSecureStorage secureStorage,
    required AppConfig config,
  }) : this._(client, secureStorage, config);

  SupabaseAuthRepository._(this._client, this._secureStorage, this._config);

  static const _uuid = Uuid();
  static const _previewPrefix = 'preview_auth_';

  final SupabaseClient? _client;
  final FlutterSecureStorage _secureStorage;
  final AppConfig _config;

  @override
  Future<AppUser?> restoreSession() async {
    if (_config.isSupabaseConfigured && _client != null) {
      final user = _client.auth.currentUser;
      if (user == null) {
        return null;
      }
      return _loadProfile(user.id);
    }

    try {
      final role = await _secureStorage.read(key: '${_previewPrefix}role');
      if (role == null) {
        return null;
      }
      final values = <String, String>{};
      for (final key in [
        'userId',
        'shopId',
        'employeeId',
        'name',
        'role',
        'isActive',
        'photoUrl',
        'phone',
      ]) {
        final value = await _secureStorage.read(key: '$_previewPrefix$key');
        if (value != null) {
          values[key] = value;
        }
      }
      return AppUser.fromStorageMap(values);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<AppUser> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    if (!_config.isSupabaseConfigured || _client == null) {
      throw const Failure(
        code: 'supabase-not-configured',
        message:
            'Supabase belum dikonfigurasi. Isi SUPABASE_URL dan SUPABASE_ANON_KEY.',
      );
    }

    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    final authUser = response.user;
    if (authUser == null) {
      throw const Failure(
        code: 'auth-empty-user',
        message: 'Login berhasil tetapi profil auth tidak ditemukan.',
      );
    }

    final appUser = await _loadProfile(authUser.id);
    if (!appUser.isActive) {
      await _client.auth.signOut();
      throw const Failure(
        code: 'inactive-user',
        message: 'Akun ini tidak aktif. Hubungi Owner.',
      );
    }
    return appUser;
  }

  @override
  Future<AppUser> signInPreview(UserRole role) async {
    final user = AppUser(
      userId: 'preview-${role.storageValue.toLowerCase()}',
      shopId: 'preview-shop-${_uuid.v4()}',
      employeeId: role == UserRole.employee ? 'preview-employee-1' : null,
      name: role == UserRole.owner ? 'Owner Idola' : 'Karyawan 1',
      role: role,
      isActive: true,
      phone: role == UserRole.owner ? '081234567890' : '081234567891',
    );

    try {
      for (final entry in user.toStorageMap().entries) {
        await _secureStorage.write(
          key: '$_previewPrefix${entry.key}',
          value: entry.value,
        );
      }
    } catch (_) {
      // Secure storage can be unavailable in widget tests. The in-memory state
      // is still enough for the current app session.
    }

    return user;
  }

  @override
  Future<AppUser> updateProfile({
    required String name,
    required String phone,
  }) async {
    if (_config.isSupabaseConfigured && _client != null) {
      final authUser = _client.auth.currentUser;
      if (authUser == null) {
        throw const Failure(
          code: 'auth-missing-session',
          message: 'Session tidak ditemukan. Silakan login ulang.',
        );
      }
      await _client
          .from('profiles')
          .update({'full_name': name.trim(), 'phone': phone.trim()})
          .eq('id', authUser.id);
      return _loadProfile(authUser.id);
    }

    final current = await restoreSession();
    if (current == null) {
      throw const Failure(
        code: 'auth-missing-preview-session',
        message: 'Session preview tidak ditemukan. Silakan login ulang.',
      );
    }
    final updated = current.copyWith(name: name.trim(), phone: phone.trim());
    try {
      for (final entry in updated.toStorageMap().entries) {
        await _secureStorage.write(
          key: '$_previewPrefix${entry.key}',
          value: entry.value,
        );
      }
    } catch (_) {
      // The in-memory controller still reflects the edit for this session.
    }
    return updated;
  }

  @override
  Future<void> signOut() async {
    if (_client != null) {
      await _client.auth.signOut();
    }

    try {
      await _secureStorage.deleteAll();
    } catch (_) {
      // Best-effort cleanup; provider state is cleared by AuthController.
    }
  }

  Future<AppUser> _loadProfile(String userId) async {
    final response = await _client!
        .from('profiles')
        .select(
          'id, shop_id, employee_id, full_name, role, is_active, avatar_url, phone',
        )
        .eq('id', userId)
        .single();

    return AppUser.fromProfileMap(response);
  }
}
