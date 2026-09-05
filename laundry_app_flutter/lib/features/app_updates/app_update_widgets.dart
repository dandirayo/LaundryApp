import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_update_controller.dart';
import 'app_update_service.dart';

/// Lives above the router, so checks and downloads survive tab changes.
class AppUpdateHost extends ConsumerStatefulWidget {
  const AppUpdateHost({
    required this.child,
    required this.onShowUpdate,
    super.key,
  });
  final Widget child;
  final VoidCallback onShowUpdate;
  @override
  ConsumerState<AppUpdateHost> createState() => _AppUpdateHostState();
}

class _AppUpdateHostState extends ConsumerState<AppUpdateHost>
    with WidgetsBindingObserver {
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    if (!ref.read(appUpdateServiceProvider).supported) return;
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _check();
    });
    _timer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        _check();
      }
    });
  }

  void _check() =>
      unawaited(ref.read(appUpdateControllerProvider.notifier).check());
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final update = ref.watch(appUpdateControllerProvider);
    return Column(
      children: [
        if (update.release != null)
          Material(
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.system_update),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        update.installing
                            ? 'Mengunduh update ${update.progress}%'
                            : 'Update ${update.release!.version} tersedia',
                      ),
                    ),
                    TextButton(
                      onPressed: widget.onShowUpdate,
                      child: const Text('Lihat'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Expanded(child: widget.child),
      ],
    );
  }
}

class AppUpdateTile extends ConsumerWidget {
  const AppUpdateTile({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(appUpdateServiceProvider).supported) {
      return const SizedBox.shrink();
    }
    return ListTile(
      leading: const Icon(Icons.system_update),
      title: const Text('Pembaruan aplikasi'),
      subtitle: const Text('Cek versi terbaru dari cloud'),
      onTap: () {
        unawaited(
          ref.read(appUpdateControllerProvider.notifier).check(manual: true),
        );
        showAppUpdateDialog(context);
      },
    );
  }
}

Future<void> showAppUpdateDialog(BuildContext context) => showDialog<void>(
  context: context,
  builder: (context) => Consumer(
    builder: (context, ref, _) {
      final update = ref.watch(appUpdateControllerProvider);
      final release = update.release;
      return AlertDialog(
        title: Text(
          release == null
              ? 'Pembaruan aplikasi'
              : 'Update ${release.version} tersedia',
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (update.checking) const LinearProgressIndicator(),
              if (release != null) ...[
                Text(release.notes),
                const SizedBox(height: 12),
                Text(
                  'Unduhan ${(release.size / 1048576).toStringAsFixed(1)} MB. Data aplikasi tetap tersimpan. Android akan meminta konfirmasi pemasangan.',
                ),
              ],
              if (update.installing) ...[
                const SizedBox(height: 12),
                LinearProgressIndicator(value: update.progress / 100),
                Text('${update.progress}% — Mengunduh dan memeriksa APK'),
              ],
              if (update.message != null) ...[
                const SizedBox(height: 12),
                Text(update.message!),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
          if (release == null)
            TextButton(
              onPressed: update.checking
                  ? null
                  : () => ref
                        .read(appUpdateControllerProvider.notifier)
                        .check(manual: true),
              child: const Text('Cek Lagi'),
            ),
          if (release != null)
            FilledButton(
              onPressed: update.installing || update.checking
                  ? null
                  : () => ref
                        .read(appUpdateControllerProvider.notifier)
                        .install(),
              child: const Text('Update'),
            ),
        ],
      );
    },
  ),
);
