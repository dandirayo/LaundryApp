import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/preview_data.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/expense_repository.dart';

final expenseRepositoryProvider = Provider<ExpenseRepository>(
  (ref) => ExpenseRepository(),
);

final expenseControllerProvider =
    AsyncNotifierProvider<ExpenseController, ExpenseState>(
      ExpenseController.new,
    );

class ExpenseState {
  const ExpenseState({
    required this.expenses,
    required this.isOnline,
  });

  final List<PreviewExpense> expenses;
  final bool isOnline;
}

class ExpenseController extends AsyncNotifier<ExpenseState> {
  late ExpenseRepository _repository;
  RealtimeChannel? _channel;
  bool _refreshQueued = false;

  @override
  Future<ExpenseState> build() async {
    _repository = ref.watch(expenseRepositoryProvider);
    ref.onDispose(_removeChannel);
    return _load(subscribe: true);
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(() => _load(subscribe: false));
  }

  Future<void> addExpense({
    required String description,
    required String category,
    required int amount,
    required String method,
  }) async {
    final shopId = _onlineShopId();
    if (shopId != null) {
      final user = ref.read(authControllerProvider).value?.user;
      await _repository.add(
        shopId: shopId,
        description: description,
        category: category,
        amount: amount,
        method: method,
        createdBy: user?.employeeId,
      );
    } else {
      ref.read(previewDataProvider.notifier).addExpense(
        description: description,
        category: category,
        amount: amount,
        method: method,
      );
    }
    await refresh();
  }

  Future<ExpenseState> _load({required bool subscribe}) async {
    final shopId = _onlineShopId();
    if (shopId == null) {
      final data = ref.read(previewDataProvider);
      return ExpenseState(
        expenses: data.expenses,
        isOnline: false,
      );
    }
    if (subscribe && _channel == null) {
      _channel = _repository.subscribe(
        shopId: shopId,
        onChanged: _queueRefresh,
      );
    }
    final expenses = await _repository.fetch(shopId: shopId);
    return ExpenseState(
      expenses: expenses,
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
