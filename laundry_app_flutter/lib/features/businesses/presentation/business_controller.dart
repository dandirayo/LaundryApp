import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/preview_data.dart';
import '../../auth/domain/user_role.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/business_repository.dart';
import '../domain/business.dart';

final businessRepositoryProvider = Provider<BusinessRepository>(
  (ref) => BusinessRepository(),
);

final businessControllerProvider =
    AsyncNotifierProvider<BusinessController, BusinessState>(
      BusinessController.new,
    );

class BusinessState {
  const BusinessState({
    required this.businesses,
    required this.assignees,
    required this.assignments,
    required this.isOnline,
    this.selectedBusinessId,
  });

  final List<Business> businesses;
  final List<BusinessAssignee> assignees;
  final Map<String, Set<String>> assignments;
  final bool isOnline;
  final String? selectedBusinessId;

  Business? get selectedBusiness {
    final id = selectedBusinessId;
    if (id == null) return null;
    for (final business in businesses) {
      if (business.id == id) return business;
    }
    return null;
  }

  BusinessState copyWith({
    List<Business>? businesses,
    List<BusinessAssignee>? assignees,
    Map<String, Set<String>>? assignments,
    bool? isOnline,
    String? selectedBusinessId,
    bool clearSelection = false,
  }) => BusinessState(
    businesses: businesses ?? this.businesses,
    assignees: assignees ?? this.assignees,
    assignments: assignments ?? this.assignments,
    isOnline: isOnline ?? this.isOnline,
    selectedBusinessId: clearSelection
        ? null
        : selectedBusinessId ?? this.selectedBusinessId,
  );
}

class BusinessController extends AsyncNotifier<BusinessState> {
  late BusinessRepository _repository;

  @override
  Future<BusinessState> build() async {
    _repository = ref.watch(businessRepositoryProvider);
    final user = ref.watch(authControllerProvider).value?.user;
    if (user == null) {
      return const BusinessState(
        businesses: [],
        assignees: [],
        assignments: {},
        isOnline: false,
      );
    }
    if (!_repository.isOnline || user.shopId.startsWith('preview-shop')) {
      final businesses = [
        Business(
          id: 'preview-laundry',
          shopId: user.shopId,
          ownerId: user.userId,
          name: 'Idola Laundry',
          kind: BusinessKind.laundry,
          isActive: true,
        ),
        Business(
          id: 'preview-tea',
          shopId: user.shopId,
          ownerId: user.userId,
          name: 'Es Teh Manis',
          kind: BusinessKind.beverage,
          isActive: true,
        ),
      ];
      final employees = ref.read(previewDataProvider).employees;
      return BusinessState(
        businesses: businesses,
        assignees: [
          for (final employee in employees)
            BusinessAssignee(
              profileId: 'preview-profile-${employee.id}',
              employeeId: employee.id,
              name: employee.name,
            ),
        ],
        assignments: {
          for (final business in businesses)
            business.id: {
              for (final employee in employees)
                'preview-profile-${employee.id}',
            },
        },
        isOnline: false,
      );
    }
    return _loadOnline(user.shopId, user.role);
  }

  Future<void> refresh() async {
    final user = ref.read(authControllerProvider).value?.user;
    if (user == null || !_repository.isOnline) return;
    final previousSelection = state.value?.selectedBusinessId;
    state = await AsyncValue.guard(() async {
      final next = await _loadOnline(user.shopId, user.role);
      return next.copyWith(selectedBusinessId: previousSelection);
    });
  }

  Future<void> selectBusiness(String id) async {
    final current = state.requireValue;
    final business = current.businesses.where((item) => item.id == id).first;
    if (!business.isActive) return;
    state = AsyncData(current.copyWith(selectedBusinessId: id));
  }

  void clearSelection() {
    state = AsyncData(state.requireValue.copyWith(clearSelection: true));
  }

  Future<void> createBusiness({
    required String name,
    required BusinessKind kind,
  }) async {
    final user = ref.read(authControllerProvider).value?.user;
    if (user == null || user.role != UserRole.owner) return;
    final current = state.requireValue;
    late final Business business;
    if (current.isOnline) {
      business = await _repository.createBusiness(
        shopId: user.shopId,
        ownerId: user.userId,
        name: name,
        kind: kind,
      );
    } else {
      business = Business(
        id: 'preview-${DateTime.now().microsecondsSinceEpoch}',
        shopId: user.shopId,
        ownerId: user.userId,
        name: name.trim(),
        kind: kind,
        isActive: true,
      );
    }
    state = AsyncData(
      current.copyWith(businesses: [...current.businesses, business]),
    );
  }

  Future<void> setBusinessActive(Business business, bool isActive) async {
    final current = state.requireValue;
    if (current.isOnline) {
      await _repository.setBusinessActive(business.id, isActive);
    }
    state = AsyncData(
      current.copyWith(
        businesses: [
          for (final item in current.businesses)
            if (item.id == business.id)
              item.copyWith(isActive: isActive)
            else
              item,
        ],
        clearSelection: !isActive && current.selectedBusinessId == business.id,
      ),
    );
  }

  Future<void> setAssignment({
    required String businessId,
    required String profileId,
    required bool assigned,
  }) async {
    final current = state.requireValue;
    if (current.isOnline) {
      await _repository.setAssignment(
        businessId: businessId,
        profileId: profileId,
        assigned: assigned,
      );
    }
    final assignments = {
      for (final entry in current.assignments.entries)
        entry.key: {...entry.value},
    };
    final members = assignments.putIfAbsent(businessId, () => <String>{});
    assigned ? members.add(profileId) : members.remove(profileId);
    state = AsyncData(current.copyWith(assignments: assignments));
  }

  Future<BusinessState> _loadOnline(String shopId, UserRole role) async {
    final businesses = await _repository.fetchBusinesses();
    if (role != UserRole.owner) {
      return BusinessState(
        businesses: businesses,
        assignees: const [],
        assignments: const {},
        isOnline: true,
      );
    }
    final results = await Future.wait([
      _repository.fetchAssignees(shopId),
      _repository.fetchAssignments([for (final item in businesses) item.id]),
    ]);
    return BusinessState(
      businesses: businesses,
      assignees: results[0] as List<BusinessAssignee>,
      assignments: results[1] as Map<String, Set<String>>,
      isOnline: true,
    );
  }
}
