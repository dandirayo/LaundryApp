import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../errors/failure.dart';

class BluetoothReceiptPrinter {
  BluetoothReceiptPrinter._();
  static final instance = BluetoothReceiptPrinter._();
  static const _addressKey = 'thermal_printer_address';
  static const _nameKey = 'thermal_printer_name';
  bool _busy = false;

  Future<T> _exclusive<T>(Future<T> Function() action) async {
    if (_busy) {
      throw const Failure(message: 'Printer sedang bekerja. Tunggu sebentar.');
    }
    _busy = true;
    try {
      return await action();
    } finally {
      _busy = false;
    }
  }

  Future<void> _ready() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      throw const Failure(
        message: 'Koneksi printer tersedia di aplikasi Android.',
      );
    }
    if (!await PrintBluetoothThermal.isPermissionBluetoothGranted) {
      throw const Failure(
        message:
            'Izinkan Perangkat di sekitar pada pengaturan izin aplikasi, lalu coba lagi.',
      );
    }
    if (!await PrintBluetoothThermal.bluetoothEnabled) {
      throw const Failure(message: 'Aktifkan Bluetooth di HP terlebih dahulu.');
    }
  }

  Future<String?> selectedName() async =>
      (await SharedPreferences.getInstance()).getString(_nameKey);

  Future<List<BluetoothInfo>> devices() => _exclusive(() async {
    await _ready();
    return PrintBluetoothThermal.pairedBluetooths;
  });

  Future<void> select(BluetoothInfo device) => _exclusive(() async {
    await _ready();
    await PrintBluetoothThermal.disconnect;
    if (!await PrintBluetoothThermal.connect(
      macPrinterAddress: device.macAdress,
    )) {
      throw const Failure(
        message:
            'Tidak dapat terhubung. Pastikan printer menyala dan tidak dipakai HP lain.',
      );
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_addressKey, device.macAdress);
    await prefs.setString(_nameKey, device.name);
  });

  Future<void> _connect() async {
    await _ready();
    final address = (await SharedPreferences.getInstance()).getString(
      _addressKey,
    );
    if (address == null) {
      throw const Failure(
        message: 'Pilih printer terlebih dahulu di menu Lainnya > Printer.',
      );
    }
    if (await PrintBluetoothThermal.connectionStatus) return;
    if (!await PrintBluetoothThermal.connect(macPrinterAddress: address)) {
      throw const Failure(
        message:
            'Printer tidak terhubung. Periksa daya dan jarak printer, lalu coba lagi.',
      );
    }
  }

  Future<void> testConnection() => _exclusive(_connect);

  Future<void> printLines(
    List<String> lines, {
    int paperWidth = 80,
    String? logoAsset,
  }) => _exclusive(() async {
    await _connect();
    final payload = logoAsset == null
        ? receiptBytes(lines, paperWidth: paperWidth)
        : await receiptBytesWithLogo(
            lines,
            paperWidth: paperWidth,
            logoAsset: logoAsset,
          );
    final sent = await PrintBluetoothThermal.writeBytes(payload);
    if (!sent) {
      await PrintBluetoothThermal.disconnect;
      throw const Failure(
        message:
            'Pengiriman gagal. Periksa printer dan kertas sebelum mencoba lagi agar struk tidak tercetak ganda.',
      );
    }
  });
}

/// ESC/POS text, font A: 32 columns on 58 mm, 48 on 80 mm.
/// Strip control characters so customer text cannot inject printer commands.
List<int> receiptBytes(List<String> lines, {int paperWidth = 80}) {
  final columns = paperWidth == 80 ? 48 : 32;
  final bytes = <int>[27, 64, 27, 77, 0, 27, 97, 0];
  for (final line in lines) {
    final safe = line.runes.map((c) => c >= 32 && c <= 126 ? c : 32).toList();
    for (var start = 0; start < safe.length; start += columns) {
      bytes.addAll(
        safe.sublist(start, (start + columns).clamp(0, safe.length)),
      );
      bytes.add(10);
    }
    if (safe.isEmpty) bytes.add(10);
  }
  bytes.addAll([10, 10, 10]);
  return bytes;
}

Future<List<int>> receiptBytesWithLogo(
  List<String> lines, {
  int paperWidth = 80,
  required String logoAsset,
}) async {
  final logo = await _logoRasterBytes(
    logoAsset,
    targetWidth: paperWidth == 80 ? 320 : 224,
  );
  return <int>[
    27,
    64,
    27,
    97,
    1,
    ...logo,
    10,
    27,
    97,
    0,
    ...receiptBytes(lines, paperWidth: paperWidth).skip(8),
  ];
}

Future<List<int>> _logoRasterBytes(
  String assetPath, {
  required int targetWidth,
}) async {
  final asset = await rootBundle.load(assetPath);
  final codec = await ui.instantiateImageCodec(
    asset.buffer.asUint8List(),
    targetWidth: targetWidth,
  );
  final frame = await codec.getNextFrame();
  final image = frame.image;
  final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  if (rgba == null) return const [];

  final imageHeight = image.height;
  final widthBytes = (image.width + 7) ~/ 8;
  final raster = List<int>.filled(widthBytes * imageHeight, 0);
  for (var y = 0; y < imageHeight; y++) {
    for (var x = 0; x < image.width; x++) {
      final offset = (y * image.width + x) * 4;
      final red = rgba.getUint8(offset);
      final green = rgba.getUint8(offset + 1);
      final blue = rgba.getUint8(offset + 2);
      final alpha = rgba.getUint8(offset + 3) / 255;
      final luminance =
          ((0.299 * red) + (0.587 * green) + (0.114 * blue)) * alpha +
          (255 * (1 - alpha));
      if (luminance < 175) {
        raster[(y * widthBytes) + (x ~/ 8)] |= 0x80 >> (x % 8);
      }
    }
  }
  image.dispose();
  codec.dispose();
  return [
    29,
    118,
    48,
    0,
    widthBytes & 0xff,
    (widthBytes >> 8) & 0xff,
    imageHeight & 0xff,
    (imageHeight >> 8) & 0xff,
    ...raster,
  ];
}
