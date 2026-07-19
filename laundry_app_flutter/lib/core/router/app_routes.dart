import '../../features/auth/domain/user_role.dart';

class AppRoutes {
  const AppRoutes._();

  static const splash = '/splash';
  static const signIn = '/sign-in';
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
    expenses,
    printer,
    backup,
    shopSettings,
  };

  static const employeeOnlyPaths = <String>{
    ordersMine,
    attendanceMine,
    shiftsMine,
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
}
