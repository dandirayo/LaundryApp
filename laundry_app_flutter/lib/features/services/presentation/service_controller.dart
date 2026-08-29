import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/preview_data.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/service_repository.dart';

final serviceRepositoryProvider = Provider<ServiceRepository>(
  (ref) => ServiceRepository(),
);

final serviceControllerProvider =
    AsyncNotifierProvider<ServiceController, List<PreviewService>>(
      ServiceController.new,
    );

class ServiceController extends AsyncNotifier<List<PreviewService>> {
  late ServiceRepository _repository;
  RealtimeChannel? _channel;
  String? _subscribedShopId;
  bool _refreshQueued = false;

  @override
  Future<List<PreviewService>> build() async {
    _repository = ref.watch(serviceRepositoryProvider);
    ref.onDispose(_removeChannel);
    return _load(subscribe: true);
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(() => _load(subscribe: false));
  }

  Future<void> add({
    required String name,
    required String itemName,
    required String sizeVariant,
    required String materialVariant,
    required String category,
    required String unit,
    required int price,
    required int estimatedHours,
    required bool isExpress,
  }) async {
    final shopId = _shopId();
    if (shopId != null) {
      await _repository.add(
        shopId: shopId,
        name: name,
        itemName: itemName,
        sizeVariant: sizeVariant,
        materialVariant: materialVariant,
        category: category,
        unit: unit,
        price: price,
        estimatedHours: estimatedHours,
        isExpress: isExpress,
      );
      await refresh();
    } else {
      ref
          .read(previewDataProvider.notifier)
          .addService(
            name: name,
            itemName: itemName,
            sizeVariant: sizeVariant,
            materialVariant: materialVariant,
            category: category,
            unit: unit,
            price: price,
            estimatedHours: estimatedHours,
            isExpress: isExpress,
          );
    }
  }

  Future<List<PreviewService>> _load({required bool subscribe}) async {
    final shopId = _shopId();
    if (shopId == null) {
      _removeChannel();
      return ref.read(previewDataProvider).services;
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
    if (channel != null) unawaited(_repository.removeChannel(channel));
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
}
