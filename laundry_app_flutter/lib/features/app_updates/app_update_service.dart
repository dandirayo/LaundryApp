import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../core/config/app_config.dart';

const updateChannel = MethodChannel('idola/app_updates');
final appUpdateServiceProvider = Provider(
  (ref) => AppUpdateService(baseUrl: ref.watch(appConfigProvider).supabaseUrl),
);

class AppRelease {
  const AppRelease({
    required this.build,
    required this.version,
    required this.notes,
    required this.url,
    required this.sha256,
    required this.size,
  });
  final int build;
  final String version, notes, sha256;
  final Uri url;
  final int size;

  static AppRelease? newerFrom(
    Map<String, dynamic> json, {
    required int installedBuild,
    required List<String> abis,
    required Uri base,
  }) {
    if (json['schema'] != 1 ||
        json['package'] != 'com.idolalaundry.laundry_app_flutter') {
      throw const FormatException('Invalid release manifest');
    }
    final build = json['build'] as int;
    if (build <= installedBuild) return null;
    final assets = json['assets'] as Map<String, dynamic>;
    final abi = abis.where(assets.containsKey).firstOrNull;
    if (abi == null) throw const FormatException('Unsupported device');
    final asset = assets[abi] as Map<String, dynamic>;
    final url = Uri.parse(asset['url'] as String);
    final hash = asset['sha256'] as String;
    final size = asset['size'] as int;
    if (url.scheme != 'https' ||
        url.origin != base.origin ||
        url.userInfo.isNotEmpty ||
        !url.path.startsWith(
          '/storage/v1/object/public/app-releases/android/',
        ) ||
        !RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(hash) ||
        size <= 0 ||
        size > 100000000) {
      throw const FormatException('Invalid release asset');
    }
    return AppRelease(
      build: build,
      version: json['version'] as String,
      notes: json['notes'] as String? ?? '',
      url: url,
      sha256: hash,
      size: size,
    );
  }
}

class AppUpdateService {
  AppUpdateService({required this.baseUrl, this.client});
  final String baseUrl;
  final http.Client? client;
  bool get supported =>
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android &&
      baseUrl.isNotEmpty;

  Future<AppRelease?> check() async {
    final info = await updateChannel.invokeMapMethod<String, dynamic>('info');
    final base = Uri.parse(baseUrl);
    final uri = base
        .resolve('/storage/v1/object/public/app-releases/android/latest.json')
        .replace(
          queryParameters: {
            't': DateTime.now().millisecondsSinceEpoch.toString(),
          },
        );
    final requestClient = client ?? http.Client();
    try {
      final response = await requestClient
          .get(uri, headers: {'Cache-Control': 'no-cache'})
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200 || response.bodyBytes.length > 65536) {
        throw const FormatException('Release unavailable');
      }
      return AppRelease.newerFrom(
        jsonDecode(response.body) as Map<String, dynamic>,
        installedBuild: info!['build'] as int,
        abis: (info['abis'] as List).cast<String>(),
        base: base,
      );
    } finally {
      if (client == null) requestClient.close();
    }
  }

  Future<String?> install(
    AppRelease release,
    ValueChanged<int> onProgress,
  ) async {
    updateChannel.setMethodCallHandler((call) async {
      if (call.method == 'progress') onProgress(call.arguments as int);
    });
    try {
      return await updateChannel.invokeMethod<String>('install', {
        'url': release.url.toString(),
        'sha256': release.sha256,
        'size': release.size,
        'build': release.build,
      });
    } finally {
      updateChannel.setMethodCallHandler(null);
    }
  }
}
