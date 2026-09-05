import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_update_service.dart';

final appUpdateControllerProvider =
    NotifierProvider<AppUpdateController, UpdateState>(AppUpdateController.new);

@immutable
class UpdateState {
  const UpdateState({
    this.release,
    this.checking = false,
    this.installing = false,
    this.progress = 0,
    this.message,
    this.failed = false,
  });
  final AppRelease? release;
  final bool checking, installing, failed;
  final int progress;
  final String? message;
}

class AppUpdateController extends Notifier<UpdateState> {
  DateTime? _lastCheck;
  @override
  UpdateState build() => const UpdateState();

  Future<void> check({bool manual = false}) async {
    final service = ref.read(appUpdateServiceProvider);
    if (!service.supported || state.checking || state.installing) return;
    if (!manual &&
        _lastCheck != null &&
        DateTime.now().difference(_lastCheck!) < const Duration(minutes: 1)) {
      return;
    }
    _lastCheck = DateTime.now();
    final previous = state.release;
    state = UpdateState(release: previous, checking: true);
    try {
      final release = await service.check();
      if (!ref.mounted) return;
      state = UpdateState(
        release: release,
        message: manual && release == null
            ? 'Aplikasi sudah versi terbaru.'
            : null,
      );
    } catch (_) {
      if (!ref.mounted) return;
      state = UpdateState(
        release: previous,
        failed: true,
        message: manual
            ? 'Belum dapat mengecek update. Periksa koneksi lalu coba lagi.'
            : null,
      );
    }
  }

  Future<void> install() async {
    final release = state.release;
    if (release == null || state.installing || state.checking) return;
    state = UpdateState(release: release, installing: true);
    try {
      final result = await ref.read(appUpdateServiceProvider).install(release, (
        progress,
      ) {
        if (ref.mounted) {
          state = UpdateState(
            release: release,
            installing: true,
            progress: progress,
          );
        }
      });
      if (!ref.mounted) return;
      state = UpdateState(
        release: release,
        message: result == 'permission_required'
            ? 'Izinkan pembaruan dari Idola One di pengaturan HP, kembali ke sini lalu tekan Update lagi.'
            : 'Selesaikan konfirmasi Android. Jika dibatalkan, tekan Update untuk mencoba lagi.',
      );
    } catch (_) {
      if (!ref.mounted) return;
      state = UpdateState(
        release: release,
        failed: true,
        message:
            'Update belum berhasil. Periksa koneksi dan ruang penyimpanan, lalu coba lagi.',
      );
    }
  }
}
