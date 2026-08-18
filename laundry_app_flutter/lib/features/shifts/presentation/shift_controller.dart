import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/preview_data.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/shift_repository.dart';

final shiftRepositoryProvider = Provider<ShiftRepository>(
  (ref) => ShiftRepository(),
);

final shiftControllerProvider =
    AsyncNotifierProvider<ShiftController, ShiftListState>(ShiftController.new);

class ShiftListState {
  const ShiftListState({required this.shifts, required this.isOnline});

  final List<PreviewShift> shifts;
  final bool isOnline;
}

class ShiftController extends AsyncNotifier<ShiftListState> {
  RealtimeChannel? _channel;
  bool _refreshQueued = false;
  late ShiftRepository _repository;

  @override
  Future<ShiftListState> build() async {
    _repository = ref.watch(shiftRepositoryProvider);
    ref.onDispose(_removeChannel);
    return _load(subscribe: true);
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(() => _load(subscribe: false));
  }

  Future<void> save({
    String? id,
    required String employeeId,
    required String employeeName,
    required String day,
    required String startTime,
    required String endTime,
    required bool isDayOff,
  }) async {
    final online = _onlineContext();
    if (online != null) {
      if (id == null) {
        await online.repository.createShift(
          shopId: online.shopId,
          employeeId: employeeId,
          employeeName: employeeName,
          day: day,
          startTime: startTime,
          endTime: endTime,
          isDayOff: isDayOff,
        );
      } else {
        await online.repository.updateShift(
          shopId: online.shopId,
          id: id,
          employeeName: employeeName,
          day: day,
          startTime: startTime,
          endTime: endTime,
          isDayOff: isDayOff,
        );
      }
    } else if (id == null) {
      ref
          .read(previewDataProvider.notifier)
          .addShift(
            employeeId: employeeId,
            day: day,
            startTime: startTime,
            endTime: endTime,
          );
    } else {
      ref
          .read(previewDataProvider.notifier)
          .updateShift(
            id: id,
            day: day,
            startTime: startTime,
            endTime: endTime,
          );
    }
    await refresh();
  }

  Future<void> delete(String id) async {
    final online = _onlineContext();
    if (online != null) {
      await online.repository.deleteShift(shopId: online.shopId, id: id);
    } else {
      ref.read(previewDataProvider.notifier).deleteShift(id);
    }
    await refresh();
  }

  Future<ShiftListState> _load({required bool subscribe}) async {
    final online = _onlineContext();
    if (online == null) {
      return ShiftListState(
        shifts: ref.read(previewDataProvider).shifts,
        isOnline: false,
      );
    }
    if (subscribe && _channel == null) {
      _channel = online.repository.subscribe(
        shopId: online.shopId,
        onChanged: _queueRefresh,
      );
    }
    return ShiftListState(
      shifts: await online.repository.fetchShifts(shopId: online.shopId),
      isOnline: true,
    );
  }

  ({ShiftRepository repository, String shopId})? _onlineContext() {
    final repository = _repository;
    final user = ref.read(authControllerProvider).value?.user;
    if (!repository.isOnline ||
        user == null ||
        user.shopId.startsWith('preview-shop')) {
      return null;
    }
    return (repository: repository, shopId: user.shopId);
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
    if (channel != null) {
      unawaited(_repository.removeChannel(channel));
    }
  }
}
