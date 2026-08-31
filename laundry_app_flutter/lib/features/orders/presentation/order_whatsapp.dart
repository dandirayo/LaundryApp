import 'package:url_launcher/url_launcher.dart';

import '../../../core/extensions/currency_extensions.dart';
import '../../../shared/preview_data.dart';

String readyPickupWhatsAppMessage(PreviewOrder order) {
  final remainingText = order.remainingAmount <= 0
      ? 'Sudah lunas'
      : 'Sisa pembayaran ${order.remainingAmount.toRupiah()}';

  return 'Halo ${order.customerNameSnapshot}, pesanan ${order.orderNumber} '
      'sudah selesai dan siap diambil di Idola Laundry.\n\n'
      'Total: ${order.totalPrice.toRupiah()}\n'
      '$remainingText\n\n'
      'Terima kasih.';
}

bool orderHasReadyPickupWhatsApp(PreviewOrder order) {
  return order.customerNameSnapshot.trim().isNotEmpty;
}

Future<bool> launchReadyPickupWhatsApp(PreviewOrder order) async {
  final phone = PreviewDataController.normalizeIndonesianPhone(
    order.customerPhoneSnapshot,
  ).replaceAll('+', '');
  final message = readyPickupWhatsAppMessage(order);
  if (phone.length >= 8) {
    final native = Uri.parse(
      'whatsapp://send?phone=$phone&text=${Uri.encodeComponent(message)}',
    );
    if (await _tryLaunch(native)) return true;

    final web = Uri.https('wa.me', '/$phone', {'text': message});
    if (await _tryLaunch(web)) return true;
  }

  final manualChat = Uri.parse(
    'whatsapp://send?text=${Uri.encodeComponent(message)}',
  );
  if (await _tryLaunch(manualChat)) return true;

  final webManualChat = Uri.https('api.whatsapp.com', '/send', {
    'text': message,
  });
  return _tryLaunch(webManualChat);
}

Future<bool> _tryLaunch(Uri uri) async {
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}
