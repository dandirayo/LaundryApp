import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Central navigation actions keep primary destinations and detail pages
/// predictable. Primary workspace changes replace the current location, while
/// detail/utility pages are pushed so the AppBar and Android back actions both
/// return to the page that opened them.
class AppNavigation {
  const AppNavigation._();

  static void open(BuildContext context, String path) {
    if (GoRouterState.of(context).uri.toString() == path) return;
    context.push(path);
  }

  static void replace(BuildContext context, String path) {
    if (GoRouterState.of(context).uri.toString() == path) return;
    context.go(path);
  }

  static void back(BuildContext context, {String? fallback}) {
    final router = GoRouter.of(context);
    if (router.canPop()) {
      context.pop();
      return;
    }
    if (fallback != null) context.go(fallback);
  }
}
