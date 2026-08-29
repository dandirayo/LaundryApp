import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/preview_data.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/notification_repository.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => NotificationRepository(),
);

final notificationControllerProvider =
    AsyncNotifierProvider<NotificationController, List<PreviewNotification>>(
      NotificationController.new,
    );

class NotificationController extends AsyncNotifier<List<PreviewNotification>> {
  late NotificationRepository _repository;
  RealtimeChannel? _channel;
  String? _subscribedShopId;
  bool _refreshQueued = false;
  bool _disposed = false;

  @override
  Future<List<PreviewNotification>> build() async {
    _repository = ref.watch(notificationRepositoryProvider);
    ref.onDispose(() {
      _disposed = true;
      _removeChannel();
    });
    return _load(subscribe: true);
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(() => _load(subscribe: false));
  }

  Future<void> markRead(String id) async {
    final shopId = _shopId();
    if (shopId != null) {
      await _repository.markRead(id);
      await refresh();
    } else {
      ref.read(previewDataProvider.notifier).markNotificationRead(id);
    }
  }

  Future<void> markAllRead() async {
    final shopId = _shopId();
    if (shopId != null) {
      await _repository.markAllRead(shopId);
      await refresh();
    } else {
      ref.read(previewDataProvider.notifier).markAllNotificationsRead();
    }
  }

  Future<void> delete(String id) async {
    if (_shopId() != null) {
      await _repository.delete(id);
      await refresh();
    } else {
      ref.read(previewDataProvider.notifier).deleteNotification(id);
    }
  }

  Future<List<PreviewNotification>> _load({required bool subscribe}) async {
    final shopId = _shopId();
    if (shopId == null) {
      _removeChannel();
      return ref.read(previewDataProvider).notifications;
    }
    if (subscribe && (_channel == null || _subscribedShopId != shopId)) {
      _removeChannel();
      _subscribedShopId = shopId;
      _channel = _repository.subscribe(
        shopId: shopId,
        onChanged: _queueRefresh,
      );
    }
    return _repository.fetch(shopId);
  }

  String? _shopId() {
    final user = ref.read(authControllerProvider).value?.user;
    if (!_repository.isOnline ||
        user == null ||
        user.shopId.startsWith('preview-shop')) {
      return null;
    }
    return user.shopId;
  }

  void _queueRefresh() {
    if (_disposed || _refreshQueued) return;
    _refreshQueued = true;
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 150), () async {
        _refreshQueued = false;
        if (!_disposed) await refresh();
      }),
    );
  }

  void _removeChannel() {
    final channel = _channel;
    _channel = null;
    _subscribedShopId = null;
    if (channel != null) {
      unawaited(_removeChannelSafely(channel));
    }
  }

  Future<void> _removeChannelSafely(RealtimeChannel channel) async {
    try {
      await _repository.removeChannel(channel);
    } catch (_) {
      // Cleanup is best-effort during logout/provider disposal.
    }
  }
}
