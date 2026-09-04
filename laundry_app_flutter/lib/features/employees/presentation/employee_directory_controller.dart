import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/preview_data.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/employee_repository.dart';

final employeeRepositoryProvider = Provider<EmployeeRepository>(
  (ref) => EmployeeRepository(),
);

final employeeDirectoryProvider =
    AsyncNotifierProvider<EmployeeDirectoryController, List<PreviewEmployee>>(
      EmployeeDirectoryController.new,
    );

class EmployeeDirectoryController extends AsyncNotifier<List<PreviewEmployee>> {
  late EmployeeRepository _repository;
  RealtimeChannel? _channel;
  String? _subscribedShopId;
  bool _refreshQueued = false;

  @override
  Future<List<PreviewEmployee>> build() async {
    _repository = ref.watch(employeeRepositoryProvider);
    final user = ref.watch(authControllerProvider).value?.user;
    ref.onDispose(_removeChannel);
    if (!_repository.isOnline ||
        user == null ||
        user.shopId.startsWith('preview-shop')) {
      return ref.read(previewDataProvider).employees;
    }
    _subscribe(user.shopId);
    return _repository.fetchEmployees(shopId: user.shopId);
  }

  Future<void> refresh() async {
    final user = ref.read(authControllerProvider).value?.user;
    if (!_repository.isOnline ||
        user == null ||
        user.shopId.startsWith('preview-shop')) {
      state = AsyncData(ref.read(previewDataProvider).employees);
      return;
    }
    state = await AsyncValue.guard(
      () => _repository.fetchEmployees(shopId: user.shopId),
    );
  }

  void _subscribe(String shopId) {
    if (_channel != null && _subscribedShopId == shopId) return;
    _removeChannel();
    _subscribedShopId = shopId;
    _channel = _repository.subscribe(shopId: shopId, onChanged: _queueRefresh);
  }

  void _queueRefresh() {
    if (_refreshQueued) return;
    _refreshQueued = true;
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 150), () async {
        _refreshQueued = false;
        await refresh();
      }),
    );
  }

  void _removeChannel() {
    final channel = _channel;
    _channel = null;
    _subscribedShopId = null;
    if (channel != null) {
      unawaited(_repository.removeChannel(channel));
    }
  }
}
