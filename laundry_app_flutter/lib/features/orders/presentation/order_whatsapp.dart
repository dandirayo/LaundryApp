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

Future<bool> launchReadyPickupWhatsApp(PreviewOrder order) {
  final phone = PreviewDataController.normalizeIndonesianPhone(
    order.customerPhoneSnapshot,
  ).replaceAll('+', '');
  if (phone.isEmpty) {
    return Future.value(false);
  }

  final uri = Uri.https('wa.me', '/$phone', {
    'text': readyPickupWhatsAppMessage(order),
  });
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}
