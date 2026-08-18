import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  @override
  Future<List<PreviewService>> build() async {
    _repository = ref.watch(serviceRepositoryProvider);
    return _load();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(_load);
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

  Future<List<PreviewService>> _load() async {
    final shopId = _shopId();
    if (shopId == null) return ref.read(previewDataProvider).services;
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
}
