import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/preview_data.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/inventory_repository.dart';

final inventoryRepositoryProvider = Provider<InventoryRepository>(
  (ref) => InventoryRepository(),
);

final inventoryControllerProvider =
    AsyncNotifierProvider<InventoryController, InventoryState>(
      InventoryController.new,
    );

class InventoryState {
  const InventoryState({
    required this.items,
    required this.movements,
    required this.isOnline,
  });

  final List<PreviewInventoryItem> items;
  final List<PreviewInventoryMovement> movements;
  final bool isOnline;
}

class InventoryController extends AsyncNotifier<InventoryState> {
  late InventoryRepository _repository;
  RealtimeChannel? _channel;
  bool _refreshQueued = false;

  @override
  Future<InventoryState> build() async {
    _repository = ref.watch(inventoryRepositoryProvider);
    ref.onDispose(_removeChannel);
    return _load(subscribe: true);
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(() => _load(subscribe: false));
  }

  Future<void> addItem({
    required String name,
    required double stock,
    required String unit,
    required double minStock,
    required int purchasePrice,
    required String note,
  }) async {
    final shopId = _onlineShopId();
    if (shopId != null) {
      await _repository.addItem(
        shopId: shopId,
        name: name,
        stock: stock,
        unit: unit,
        minStock: minStock,
        purchasePrice: purchasePrice,
        note: note,
      );
    } else {
      ref
          .read(previewDataProvider.notifier)
          .addInventoryItem(
            name: name,
            stock: stock,
            unit: unit,
            minStock: minStock,
            purchasePrice: purchasePrice,
            note: note,
          );
    }
    await refresh();
  }

  Future<void> adjust({
    required String itemId,
    required double quantity,
    required String type,
    required String note,
  }) async {
    if (_onlineShopId() != null) {
      await _repository.adjust(
        itemId: itemId,
        quantity: quantity,
        type: type,
        note: note,
      );
    } else {
      ref
          .read(previewDataProvider.notifier)
          .adjustStock(
            itemId: itemId,
            quantity: quantity,
            type: type,
            note: note,
          );
    }
    await refresh();
  }

  Future<InventoryState> _load({required bool subscribe}) async {
    final shopId = _onlineShopId();
    if (shopId == null) {
      final data = ref.read(previewDataProvider);
      return InventoryState(
        items: data.inventory,
        movements: data.inventoryMovements,
        isOnline: false,
      );
    }
    if (subscribe && _channel == null) {
      _channel = _repository.subscribe(
        shopId: shopId,
        onChanged: _queueRefresh,
      );
    }
    final result = await _repository.fetch(shopId: shopId);
    return InventoryState(
      items: result.items,
      movements: result.movements,
      isOnline: true,
    );
  }

  String? _onlineShopId() {
    final user = ref.read(authControllerProvider).value?.user;
    if (!_repository.isOnline ||
        user == null ||
        user.shopId.startsWith('preview-shop')) {
      return null;
    }
    return user.shopId;
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
    if (channel != null) unawaited(_repository.removeChannel(channel));
  }
}
