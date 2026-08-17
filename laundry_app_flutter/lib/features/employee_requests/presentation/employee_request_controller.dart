import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/preview_data.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/employee_request_repository.dart';

final employeeRequestRepositoryProvider = Provider<EmployeeRequestRepository>(
  (ref) => EmployeeRequestRepository(),
);

final employeeRequestControllerProvider =
    AsyncNotifierProvider<EmployeeRequestController, EmployeeRequestListState>(
      EmployeeRequestController.new,
    );

class EmployeeRequestListState {
  const EmployeeRequestListState({
    required this.requests,
    required this.isOnline,
  });

  final List<PreviewEmployeeRequest> requests;
  final bool isOnline;

  int get pendingCount => requests
      .where((request) => request.status == PreviewRequestStatus.pending)
      .length;
}

class EmployeeRequestController
    extends AsyncNotifier<EmployeeRequestListState> {
  RealtimeChannel? _channel;
  EmployeeRequestRepository? _subscribedRepository;
  String? _subscribedShopId;
  bool _disposeRegistered = false;
  bool _disposed = false;
  bool _realtimeRefreshQueued = false;

  @override
  Future<EmployeeRequestListState> build() async {
    _registerDispose();
    return _load(listen: true);
  }

  Future<void> refresh() async {
    if (state.value == null) {
      state = const AsyncLoading();
    }
    state = await AsyncValue.guard(() => _load(listen: false));
  }

  Future<void> addRequest({
    required String type,
    required String reason,
    required int amount,
    required String employeeId,
    required String employeeName,
  }) async {
    final online = _onlineContext(listen: false);
    if (online != null) {
      await online.repository.createRequest(
        shopId: online.shopId,
        employeeId: employeeId,
        employeeName: employeeName,
        type: type,
        reason: reason,
        amount: amount,
      );
    } else {
      ref
          .read(previewDataProvider.notifier)
          .addRequest(
            type: type,
            reason: reason,
            amount: amount,
            employeeId: employeeId,
          );
    }
    await refresh();
  }

  Future<void> updateStatus({
    required String requestId,
    required PreviewRequestStatus status,
    required String reviewNote,
  }) async {
    final online = _onlineContext(listen: false);
    if (online != null) {
      await online.repository.updateRequestStatus(
        shopId: online.shopId,
        requestId: requestId,
        status: status,
        reviewNote: reviewNote,
      );
    } else {
      final notifier = ref.read(previewDataProvider.notifier);
      if (status == PreviewRequestStatus.paid) {
        notifier.payEmployeeRequest(requestId: requestId, method: 'Tunai');
      } else if (status == PreviewRequestStatus.completed) {
        notifier.completeRequest(requestId);
      } else {
        notifier.reviewRequest(requestId, status, reviewNote: reviewNote);
      }
    }
    await refresh();
  }

  Future<EmployeeRequestListState> _load({required bool listen}) async {
    final online = _onlineContext(listen: listen);
    if (online != null) {
      _subscribeToRealtime(
        repository: online.repository,
        shopId: online.shopId,
      );
      final requests = await online.repository.fetchRequests(
        shopId: online.shopId,
      );
      return EmployeeRequestListState(requests: requests, isOnline: true);
    }

    _unsubscribeFromRealtime();
    final requests = listen
        ? ref.watch(previewDataProvider.select((state) => state.requests))
        : ref.read(previewDataProvider).requests;
    return EmployeeRequestListState(requests: requests, isOnline: false);
  }

  ({EmployeeRequestRepository repository, String shopId})? _onlineContext({
    required bool listen,
  }) {
    final repository = listen
        ? ref.watch(employeeRequestRepositoryProvider)
        : ref.read(employeeRequestRepositoryProvider);
    final session = listen
        ? ref.watch(authControllerProvider).value
        : ref.read(authControllerProvider).value;
    final user = session?.user;
    if (!repository.isOnline ||
        user == null ||
        user.shopId.startsWith('preview-shop')) {
      return null;
    }
    return (repository: repository, shopId: user.shopId);
  }

  void _subscribeToRealtime({
    required EmployeeRequestRepository repository,
    required String shopId,
  }) {
    if (_subscribedShopId == shopId && _channel != null) {
      return;
    }
    _unsubscribeFromRealtime();
    _subscribedRepository = repository;
    _subscribedShopId = shopId;
    _channel = repository.subscribeToRequests(
      shopId: shopId,
      onChanged: _queueRealtimeRefresh,
    );
  }

  void _queueRealtimeRefresh() {
    if (_disposed || _realtimeRefreshQueued) {
      return;
    }
    _realtimeRefreshQueued = true;
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 150), () async {
        _realtimeRefreshQueued = false;
        if (!_disposed) {
          await refresh();
        }
      }),
    );
  }

  void _unsubscribeFromRealtime() {
    final channel = _channel;
    final repository = _subscribedRepository;
    _channel = null;
    _subscribedRepository = null;
    _subscribedShopId = null;
    if (channel != null && repository != null) {
      unawaited(_removeSubscription(repository, channel));
    }
  }

  Future<void> _removeSubscription(
    EmployeeRequestRepository repository,
    RealtimeChannel channel,
  ) async {
    try {
      await repository.removeSubscription(channel);
    } catch (_) {
      // Realtime cleanup is best-effort during logout and provider disposal.
    }
  }

  void _registerDispose() {
    if (_disposeRegistered) {
      return;
    }
    _disposeRegistered = true;
    ref.onDispose(() {
      _disposed = true;
      _unsubscribeFromRealtime();
    });
  }
}
