import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/localization/app_language.dart';
import '../core/router/app_router.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/app_snack_bar.dart';
import '../features/app_updates/app_update_widgets.dart';

class IdolaLaundryApp extends ConsumerWidget {
  const IdolaLaundryApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final language = ref.watch(appLanguageProvider);

    return MaterialApp.router(
      title: 'Idola Laundry',
      debugShowCheckedModeBanner: false,
      locale: language.locale,
      scaffoldMessengerKey: appScaffoldMessengerKey,
      theme: AppTheme.light(),
      scrollBehavior: const _IdolaScrollBehavior(),
      routerConfig: router,
      builder: (context, child) => AppUpdateHost(
        child: child ?? const SizedBox.shrink(),
        onShowUpdate: () {
          final navigatorContext =
              router.routerDelegate.navigatorKey.currentContext;
          if (navigatorContext != null) showAppUpdateDialog(navigatorContext);
        },
      ),
    );
  }
}

class _IdolaScrollBehavior extends MaterialScrollBehavior {
  const _IdolaScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}
