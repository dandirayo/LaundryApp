import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app_bootstrap.dart';
import 'app/idola_laundry_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppBootstrap.initialize();

  runApp(const ProviderScope(child: IdolaLaundryApp()));
}
