import '../../features/auth/domain/user_role.dart';

class AppRoutes {
  const AppRoutes._();

  static const splash = '/splash';
  static const signIn = '/sign-in';
  static const businessSelector = '/businesses';
  static const businessManagement = '/businesses/manage';
  static const dashboard = '/dashboard';
  static const orders = '/orders';
  static const ordersMine = '/orders/me';
  static const orderCreate = '/orders/new';
  static const orderDetail = '/orders/:orderId';
  static const customers = '/customers';
  static const more = '/more';
  static const services = '/services';
  static const inventory = '/inventory';
  static const shifts = '/shifts';
  static const shiftsMine = '/shifts/me';
  static const employees = '/employees';
  static const attendance = '/attendance';
  static const attendanceMine = '/attendance/me';
  static const payroll = '/payroll';
  static const requestReview = '/requests/review';
  static const requestsMine = '/requests/me';
  static const reports = '/reports';
  static const cashbook = '/cashbook';
  static const expenses = '/expenses';
  static const notifications = '/notifications';
  static const printer = '/printer';
  static const backup = '/backup';
  static const shopSettings = '/settings/shop';
  static const profile = '/profile';
  static const stockRequest = '/requests/stock';
  static const overtimeRequest = '/requests/overtime';
  static const shiftSwapRequest = '/requests/shift-swap';
  static const leaveRequest = '/requests/leave';
  static const incentiveRequest = '/requests/incentive';
  static const cashAdvanceRequest = '/requests/cash-advance';
  static const changePin = '/account/change-pin';
  static const posHome = '/pos';
  static const posCashier = '/pos/cashier';
  static const posProducts = '/pos/products';
  static const posMore = '/pos/more';

  static const ownerOnlyPaths = <String>{
    services,
    inventory,
    shifts,
    employees,
    attendance,
    payroll,
    requestReview,
    reports,
    cashbook,
    printer,
    backup,
    shopSettings,
    businessManagement,
  };

  static const employeeOnlyPaths = <String>{
    ordersMine,
    attendanceMine,
    shiftsMine,
    requestsMine,
    stockRequest,
    overtimeRequest,
    shiftSwapRequest,
    leaveRequest,
    incentiveRequest,
    cashAdvanceRequest,
    changePin,
  };

  static bool canOpen(String path, UserRole role) {
    if (ownerOnlyPaths.contains(path)) {
      return role == UserRole.owner;
    }
    if (employeeOnlyPaths.contains(path)) {
      return role == UserRole.employee;
    }
    return true;
  }

  /// Safe destination when a page is opened from a notification, deep link,
  /// or restored session without a Navigator stack.
  static String? parentFor(String path, UserRole role) {
    final ordersRoot = role == UserRole.employee ? ordersMine : orders;

    if (path == dashboard || path == posHome || path == businessSelector) {
      return null;
    }
    if (path == orderCreate || path.startsWith('/orders/')) {
      return ordersRoot;
    }
    if (path == orders || path == ordersMine || path == customers) {
      return dashboard;
    }
    if (path == attendance || path == attendanceMine) {
      return dashboard;
    }
    if (path == stockRequest ||
        path == overtimeRequest ||
        path == shiftSwapRequest ||
        path == leaveRequest ||
        path == incentiveRequest ||
        path == cashAdvanceRequest) {
      return requestsMine;
    }
    if (path == posCashier || path == posProducts || path == posMore) {
      return posHome;
    }
    if (path == businessManagement) return businessSelector;
    if (path == more) return dashboard;
    return more;
  }
}
