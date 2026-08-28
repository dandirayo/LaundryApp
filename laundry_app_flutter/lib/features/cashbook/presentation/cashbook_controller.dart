import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/preview_data.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/cashbook_repository.dart';

final cashbookRepositoryProvider = Provider<CashbookRepository>(
  (ref) => CashbookRepository(),
);

final cashbookControllerProvider =
    AsyncNotifierProvider<CashbookController, CashbookState>(
      CashbookController.new,
    );

class CashbookState {
  const CashbookState({
    required this.transactions,
    required this.isOnline,
  });

  final List<PreviewCashTransaction> transactions;
  final bool isOnline;
}

class CashbookController extends AsyncNotifier<CashbookState> {
  late CashbookRepository _repository;
  RealtimeChannel? _channel;
  bool _refreshQueued = false;

  @override
  Future<CashbookState> build() async {
    _repository = ref.watch(cashbookRepositoryProvider);
    ref.onDispose(_removeChannel);
    return _load(subscribe: true);
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(() => _load(subscribe: false));
  }

  Future<void> addTransaction({
    required String type,
    required String category,
    required String description,
    required int amount,
    required String method,
  }) async {
    final shopId = _onlineShopId();
    if (shopId != null) {
      await _repository.addTransaction(
        shopId: shopId,
        type: type,
        category: category,
        description: description,
        amount: amount,
        method: method,
      );
    } else {
      // Fallback for preview/offline mode - add to preview data
      final now = DateTime.now();
      ref.read(previewDataProvider.notifier).state = ref.read(previewDataProvider).copyWith(
        cashTransactions: [
          PreviewCashTransaction(
            id: 'local-${now.millisecondsSinceEpoch}',
            referenceId: '',
            referenceType: '',
            type: type,
            category: category,
            description: description,
            amount: amount,
            method: method,
            createdAt: now,
          ),
          ...ref.read(previewDataProvider).cashTransactions,
        ],
      );
    }
    await refresh();
  }

  Future<CashbookState> _load({required bool subscribe}) async {
    final shopId = _onlineShopId();
    if (shopId == null) {
      final data = ref.read(previewDataProvider);
      return CashbookState(
        transactions: data.cashTransactions,
        isOnline: false,
      );
    }
    if (subscribe && _channel == null) {
      _channel = _repository.subscribe(
        shopId: shopId,
        onChanged: _queueRefresh,
      );
    }
    final transactions = await _repository.fetch(shopId: shopId);
    return CashbookState(
      transactions: transactions,
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
