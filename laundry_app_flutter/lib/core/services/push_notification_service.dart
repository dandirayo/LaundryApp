import '../errors/failure.dart';

class PushNotificationService {
  const PushNotificationService();

  Future<void> initialize() async {
    throw const Failure(
      code: 'fcm-not-configured',
      message: 'FCM belum dikonfigurasi. Hubungkan Firebase pada Phase 5.',
    );
  }
}
