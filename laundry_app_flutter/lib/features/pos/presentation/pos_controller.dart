import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_controller.dart';
import '../../businesses/domain/business.dart';
import '../../businesses/presentation/business_controller.dart';
import '../data/pos_repository.dart';
import '../domain/pos_models.dart';

final posRepositoryProvider = Provider<PosRepository>((ref) => PosRepository());

final posControllerProvider = AsyncNotifierProvider<PosController, PosState>(
  PosController.new,
);

class PosState {
  const PosState({
    required this.businessId,
    required this.products,
    required this.todaySales,
    required this.isOpenToday,
    required this.isOnline,
  });

  final String businessId;
  final List<PosProduct> products;
  final List<PosSale> todaySales;
  final bool isOpenToday;
  final bool isOnline;

  int get todayRevenue => todaySales.fold(0, (sum, sale) => sum + sale.total);

  PosState copyWith({
    List<PosProduct>? products,
    List<PosSale>? todaySales,
    bool? isOpenToday,
  }) => PosState(
    businessId: businessId,
    products: products ?? this.products,
    todaySales: todaySales ?? this.todaySales,
    isOpenToday: isOpenToday ?? this.isOpenToday,
    isOnline: isOnline,
  );
}

class PosController extends AsyncNotifier<PosState> {
  late PosRepository _repository;

  @override
  Future<PosState> build() async {
    _repository = ref.watch(posRepositoryProvider);
    final business = ref.watch(
      businessControllerProvider.select(
        (state) => state.value?.selectedBusiness,
      ),
    );
    if (business == null || business.kind != BusinessKind.beverage) {
      return const PosState(
        businessId: '',
        products: [],
        todaySales: [],
        isOpenToday: false,
        isOnline: false,
      );
    }
    if (!_repository.isOnline || business.id.startsWith('preview-')) {
      return PosState(
        businessId: business.id,
        products: _previewProducts(business.id),
        todaySales: const [],
        isOpenToday: true,
        isOnline: false,
      );
    }
    return _load(business.id);
  }

  Future<void> refresh() async {
    final businessId = state.value?.businessId;
    if (businessId == null || businessId.isEmpty || !_repository.isOnline) {
      return;
    }
    state = await AsyncValue.guard(() => _load(businessId));
  }

  Future<void> setOpenToday(bool isOpen) async {
    final current = state.requireValue;
    final user = ref.read(authControllerProvider).value?.user;
    if (current.isOnline && user != null) {
      await _repository.setTodayOpen(
        businessId: current.businessId,
        profileId: user.userId,
        isOpen: isOpen,
      );
    }
    state = AsyncData(current.copyWith(isOpenToday: isOpen));
  }

  Future<void> saveProduct({
    PosProduct? product,
    required String name,
    required String category,
    required int price,
    required bool isActive,
  }) async {
    final current = state.requireValue;
    late PosProduct saved;
    if (current.isOnline) {
      saved = await _repository.saveProduct(
        businessId: current.businessId,
        id: product?.id,
        name: name,
        category: category,
        price: price,
        isActive: isActive,
      );
    } else {
      saved = PosProduct(
        id: product?.id ?? 'preview-${DateTime.now().microsecondsSinceEpoch}',
        businessId: current.businessId,
        name: name.trim(),
        category: category.trim(),
        price: price,
        isActive: isActive,
      );
    }
    final products = [...current.products];
    final index = products.indexWhere((item) => item.id == saved.id);
    index < 0 ? products.add(saved) : products[index] = saved;
    state = AsyncData(current.copyWith(products: products));
  }

  Future<String> checkout({
    required Map<String, int> quantities,
    required String paymentMethod,
    required String notes,
  }) async {
    final current = state.requireValue;
    if (current.isOnline) {
      final saleId = await _repository.createSale(
        businessId: current.businessId,
        paymentMethod: paymentMethod,
        notes: notes,
        quantities: quantities,
      );
      state = AsyncData(await _load(current.businessId));
      return saleId;
    }
    final total = quantities.entries.fold<int>(0, (sum, entry) {
      final product = current.products.firstWhere(
        (item) => item.id == entry.key,
      );
      return sum + (product.price * entry.value);
    });
    final id = 'preview-sale-${DateTime.now().microsecondsSinceEpoch}';
    final sale = PosSale(
      id: id,
      businessId: current.businessId,
      saleNumber: 'POS-PREVIEW',
      total: total,
      paymentMethod: paymentMethod,
      createdAt: DateTime.now(),
    );
    state = AsyncData(
      current.copyWith(todaySales: [sale, ...current.todaySales]),
    );
    return id;
  }

  Future<PosState> _load(String businessId) async {
    final results = await Future.wait([
      _repository.fetchProducts(businessId),
      _repository.fetchTodaySales(businessId),
      _repository.fetchTodayOpen(businessId),
    ]);
    return PosState(
      businessId: businessId,
      products: results[0] as List<PosProduct>,
      todaySales: results[1] as List<PosSale>,
      isOpenToday: results[2] as bool,
      isOnline: true,
    );
  }

  List<PosProduct> _previewProducts(String businessId) => [
    PosProduct(
      id: 'tea-1',
      businessId: businessId,
      name: 'Es Teh Manis',
      category: 'Minuman',
      price: 5000,
      isActive: true,
    ),
    PosProduct(
      id: 'tea-2',
      businessId: businessId,
      name: 'Es Teh Jumbo',
      category: 'Minuman',
      price: 7000,
      isActive: true,
    ),
    PosProduct(
      id: 'tea-3',
      businessId: businessId,
      name: 'Es Teh Lemon',
      category: 'Minuman',
      price: 8000,
      isActive: true,
    ),
    PosProduct(
      id: 'tea-4',
      businessId: businessId,
      name: 'Teh Tawar',
      category: 'Minuman',
      price: 3000,
      isActive: true,
    ),
  ];
}
