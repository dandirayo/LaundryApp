import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/config/app_config.dart';
import '../../../core/services/supabase_service.dart';
import '../data/auth_repository.dart';
import '../domain/app_user.dart';
import '../domain/user_role.dart';

final secureStorageProvider = Provider<FlutterSecureStorage>(
  (ref) => const FlutterSecureStorage(),
);

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return SupabaseAuthRepository(
    client: SupabaseService.maybeClient,
    secureStorage: ref.watch(secureStorageProvider),
    config: ref.watch(appConfigProvider),
  );
});

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthSessionState>(AuthController.new);

class AuthSessionState {
  const AuthSessionState._({this.user});

  const AuthSessionState.unauthenticated() : this._();

  const AuthSessionState.authenticated(AppUser user) : this._(user: user);

  final AppUser? user;

  bool get isAuthenticated => user != null;
}

class AuthController extends AsyncNotifier<AuthSessionState> {
  @override
  FutureOr<AuthSessionState> build() async {
    final restoredUser = await ref
        .read(authRepositoryProvider)
        .restoreSession();
    if (restoredUser == null) {
      return const AuthSessionState.unauthenticated();
    }
    return AuthSessionState.authenticated(restoredUser);
  }

  Future<void> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final user = await ref
          .read(authRepositoryProvider)
          .signInWithEmailPassword(email: email, password: password);
      return AuthSessionState.authenticated(user);
    });
  }

  Future<void> signInPreview(UserRole role) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final user = await ref.read(authRepositoryProvider).signInPreview(role);
      return AuthSessionState.authenticated(user);
    });
  }

  Future<void> updateProfile({
    required String name,
    required String phone,
  }) async {
    state = await AsyncValue.guard(() async {
      final user = await ref
          .read(authRepositoryProvider)
          .updateProfile(name: name, phone: phone);
      return AuthSessionState.authenticated(user);
    });
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(authRepositoryProvider).signOut();
      return const AuthSessionState.unauthenticated();
    });
  }
}
