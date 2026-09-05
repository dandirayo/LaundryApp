import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:laundry_app_flutter/features/app_updates/app_update_service.dart';
import 'package:laundry_app_flutter/features/app_updates/app_update_controller.dart';
import 'package:laundry_app_flutter/features/app_updates/app_update_widgets.dart';

final base = Uri.parse('https://sqydcdhvsmmkvlpsjzgx.supabase.co');
Map<String, dynamic> manifest() => {
  'schema': 1,
  'package': 'com.idolalaundry.laundry_app_flutter',
  'build': 5,
  'version': '1.0.4',
  'notes': 'Perbaikan pesanan',
  'assets': {
    'arm64-v8a': {
      'url': '$base/storage/v1/object/public/app-releases/android/5/arm64.apk',
      'size': 1000,
      'sha256': 'a' * 64,
    },
  },
};
AppRelease? parse(Map<String, dynamic> json, {int installed = 4}) =>
    AppRelease.newerFrom(
      json,
      installedBuild: installed,
      abis: ['arm64-v8a', 'armeabi-v7a'],
      base: base,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('new build is offered; equal and older builds are not', () {
    expect(parse(manifest())!.version, '1.0.4');
    expect(parse(manifest(), installed: 5), isNull);
    expect(parse(manifest(), installed: 6), isNull);
  });
  test('untrusted release URLs and malformed assets are rejected', () {
    for (final url in [
      'http://sqydcdhvsmmkvlpsjzgx.supabase.co/file.apk',
      'https://evil.example/update.apk',
      '$base/storage/v1/object/public/attendance-photos/f.apk',
    ]) {
      final json = manifest();
      (json['assets']['arm64-v8a'] as Map)['url'] = url;
      expect(() => parse(json), throwsFormatException);
    }
    final invalidHash = manifest();
    invalidHash['assets']['arm64-v8a']['sha256'] = 'invalid';
    expect(() => parse(invalidHash), throwsFormatException);
    final wrongPackage = manifest()..['package'] = 'another.app';
    expect(() => parse(wrongPackage), throwsFormatException);
  });
  test(
    'manifest request uses installed Android build and disables caching',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            updateChannel,
            (_) async => {
              'build': 4,
              'abis': ['arm64-v8a'],
            },
          );
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(updateChannel, null),
      );
      final client = MockClient((request) async {
        expect(request.url.queryParameters.containsKey('t'), isTrue);
        expect(request.headers['Cache-Control'], 'no-cache');
        return http.Response(jsonEncode(manifest()), 200);
      });
      expect(
        (await AppUpdateService(
          baseUrl: base.toString(),
          client: client,
        ).check())!.build,
        5,
      );
    },
  );
  test('offline failure retains offer; later retraction clears it', () async {
    final fake = _Service();
    final container = ProviderContainer(
      overrides: [appUpdateServiceProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);
    final controller = container.read(appUpdateControllerProvider.notifier);
    await controller.check(manual: true);
    fake.fail = true;
    await controller.check(manual: true);
    expect(container.read(appUpdateControllerProvider).release, isNotNull);
    expect(container.read(appUpdateControllerProvider).failed, isTrue);
    fake.fail = false;
    fake.release = null;
    await controller.check(manual: true);
    expect(container.read(appUpdateControllerProvider).release, isNull);
  });
  testWidgets(
    'banner opens dialog and update requires user click; permission can retry',
    (tester) async {
      final fake = _Service();
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appUpdateServiceProvider.overrideWithValue(fake)],
          child: MaterialApp(
            navigatorKey: navigator,
            theme: ThemeData(splashFactory: InkRipple.splashFactory),
            builder: (context, child) => AppUpdateHost(
              child: child!,
              onShowUpdate: () =>
                  showAppUpdateDialog(navigator.currentContext!),
            ),
            home: const Scaffold(body: Text('Pesanan tetap tersedia')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Update 1.0.4 tersedia'), findsOneWidget);
      expect(fake.installs, 0);
      await tester.tap(find.text('Lihat'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Update'));
      await tester.pumpAndSettle();
      expect(fake.installs, 1);
      expect(find.textContaining('Izinkan pembaruan'), findsOneWidget);
      fake.result = 'installer_opened';
      await tester.tap(find.text('Update'));
      await tester.pumpAndSettle();
      expect(fake.installs, 2);
      await tester.tap(find.text('Tutup'));
      await tester.pumpAndSettle();
      expect(find.text('Pesanan tetap tersedia'), findsOneWidget);
      expect(find.text('Update 1.0.4 tersedia'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

class _Service extends AppUpdateService {
  _Service() : super(baseUrl: base.toString());
  bool fail = false;
  AppRelease? release = parse(manifest());
  int installs = 0;
  String result = 'permission_required';
  @override
  bool get supported => true;
  @override
  Future<AppRelease?> check() async {
    if (fail) throw const FormatException('offline');
    return release;
  }

  @override
  Future<String?> install(
    AppRelease release,
    ValueChanged<int> onProgress,
  ) async {
    installs++;
    onProgress(50);
    return result;
  }
}
