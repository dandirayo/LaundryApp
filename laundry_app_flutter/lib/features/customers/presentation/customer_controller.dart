import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/preview_data.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/customer_repository.dart';
import '../domain/contact_import.dart';
import '../domain/customer.dart';

final customerRepositoryProvider = Provider<CustomerRepository>(
  (ref) => CustomerRepository(),
);

final customerControllerProvider =
    AsyncNotifierProvider<CustomerController, CustomerListState>(
      CustomerController.new,
    );

class CustomerListState {
  const CustomerListState({
    required this.customers,
    required this.totalCount,
    required this.isOnline,
  });

  final List<Customer> customers;
  final int totalCount;
  final bool isOnline;

  List<Customer> latest({int limit = 5}) {
    final sorted = [...customers]
      ..sort((first, second) => second.createdAt.compareTo(first.createdAt));
    return sorted.take(limit).toList(growable: false);
  }
}

class CustomerController extends AsyncNotifier<CustomerListState> {
  RealtimeChannel? _channel;
  CustomerRepository? _subscribedRepository;
  String? _subscribedShopId;
  bool _disposeRegistered = false;
  bool _disposed = false;
  bool _realtimeRefreshQueued = false;

  @override
  Future<CustomerListState> build() async {
    _registerDispose();
    return _load(listen: true);
  }

  Future<void> refresh() async {
    if (state.value == null) {
      state = const AsyncLoading();
    }
    state = await AsyncValue.guard(() => _load(listen: false));
  }

  Future<void> addCustomer({
    required String name,
    required String phone,
    required String address,
    required String note,
  }) async {
    final online = _onlineContext(listen: false);
    if (online != null) {
      await online.repository.createCustomer(
        shopId: online.shopId,
        name: name,
        phone: phone,
        address: address,
        note: note,
      );
    } else {
      ref
          .read(previewDataProvider.notifier)
          .addCustomer(name: name, phone: phone, address: address, note: note);
    }
    await refresh();
  }

  Future<void> updateCustomer({
    required String id,
    required String name,
    required String phone,
    required String address,
    required String note,
  }) async {
    final online = _onlineContext(listen: false);
    if (online != null) {
      await online.repository.updateCustomer(
        shopId: online.shopId,
        id: id,
        name: name,
        phone: phone,
        address: address,
        note: note,
      );
    } else {
      ref
          .read(previewDataProvider.notifier)
          .updateCustomer(
            id: id,
            name: name,
            phone: phone,
            address: address,
            note: note,
          );
    }
    await refresh();
  }

  Future<ContactSyncResult> syncContacts(
    List<ContactImportCandidate> candidates,
  ) async {
    final current = state.value ?? await _load(listen: false);
    final plan = buildContactImportPlan(
      candidates: candidates,
      existingCustomers: current.customers,
    );
    var importedCount = 0;
    var duplicatePhoneCount = plan.duplicatePhoneCount;

    final online = _onlineContext(listen: false);
    if (online != null) {
      importedCount = await online.repository.importCustomers(
        shopId: online.shopId,
        contacts: plan.selections,
        note: 'Sinkron kontak HP',
      );
      duplicatePhoneCount += plan.importableCount - importedCount;
    } else {
      final preview = ref.read(previewDataProvider.notifier);
      for (final contact in plan.selections) {
        try {
          preview.addCustomer(
            name: contact.name,
            phone: contact.phone,
            address: contact.address,
            note: 'Sinkron kontak HP',
          );
          importedCount++;
        } on StateError {
          duplicatePhoneCount++;
        }
      }
    }

    await refresh();
    return ContactSyncResult(
      importedCount: importedCount,
      duplicatePhoneCount: duplicatePhoneCount,
      invalidPhoneCount: plan.invalidPhoneCount,
      noPhoneCount: plan.noPhoneCount,
    );
  }

  Future<CustomerListState> _load({required bool listen}) async {
    final online = _onlineContext(listen: listen);
    if (online != null) {
      _subscribeToRealtime(
        repository: online.repository,
        shopId: online.shopId,
      );
      final customers = await online.repository.fetchCustomers(
        shopId: online.shopId,
      );
      return CustomerListState(
        customers: customers,
        totalCount: customers.length,
        isOnline: true,
      );
    }

    _unsubscribeFromRealtime();
    final user = listen
        ? ref.watch(authControllerProvider).value?.user
        : ref.read(authControllerProvider).value?.user;
    final shopId = user?.shopId ?? 'preview-shop';
    final previewCustomers = listen
        ? ref.watch(previewDataProvider.select((state) => state.customers))
        : ref.read(previewDataProvider).customers;
    final customers = [
      for (final customer in previewCustomers)
        Customer(
          id: customer.id,
          shopId: shopId,
          name: customer.name,
          phone: Customer.phoneFromInput(customer.phone),
          normalizedPhone: customer.normalizedPhone.trim().isEmpty
              ? null
              : customer.normalizedPhone.trim(),
          address: customer.address,
          note: customer.note,
          createdAt: customer.createdAt,
        ),
    ]..sort((first, second) => second.createdAt.compareTo(first.createdAt));

    return CustomerListState(
      customers: customers,
      totalCount: customers.length,
      isOnline: false,
    );
  }

  ({CustomerRepository repository, String shopId})? _onlineContext({
    required bool listen,
  }) {
    final repository = listen
        ? ref.watch(customerRepositoryProvider)
        : ref.read(customerRepositoryProvider);
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
    required CustomerRepository repository,
    required String shopId,
  }) {
    if (_subscribedShopId == shopId && _channel != null) {
      return;
    }
    _unsubscribeFromRealtime();
    _subscribedRepository = repository;
    _subscribedShopId = shopId;
    _channel = repository.subscribeToCustomers(
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
    CustomerRepository repository,
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
