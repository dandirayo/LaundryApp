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

  Future<void> printStyledLines(
    List<ThermalPrintLine> lines, {
    int paperWidth = 80,
  }) => _exclusive(() async {
    await _connect();
    final sent = await PrintBluetoothThermal.writeBytes(
      styledReceiptBytes(lines, paperWidth: paperWidth),
    );
    if (!sent) {
      await PrintBluetoothThermal.disconnect;
      throw const Failure(
        message:
            'Pengiriman gagal. Periksa printer dan kertas sebelum mencoba lagi agar struk tidak tercetak ganda.',
      );
    }
  });
}

enum ThermalTextAlign { left, center, right }

class ThermalPrintLine {
  const ThermalPrintLine(
    this.text, {
    this.bold = false,
    this.large = false,
    this.align = ThermalTextAlign.left,
  });

  final String text;
  final bool bold;
  final bool large;
  final ThermalTextAlign align;
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

/// Styled ESC/POS output used by laundry labels. Large text uses double width
/// and double height so the order identity remains readable on 58/80 mm paper.
List<int> styledReceiptBytes(
  List<ThermalPrintLine> lines, {
  int paperWidth = 80,
}) {
  final columns = paperWidth == 80 ? 48 : 32;
  final bytes = <int>[27, 64, 27, 77, 0];
  for (final line in lines) {
    bytes.addAll([27, 97, line.align.index, 27, 69, line.bold ? 1 : 0]);
    bytes.addAll([29, 33, line.large ? 17 : 0]);
    final lineColumns = line.large ? columns ~/ 2 : columns;
    for (final segment in _wrapPrintableWords(line.text, lineColumns)) {
      bytes.addAll(segment.codeUnits);
      bytes.add(10);
    }
  }
  bytes.addAll([27, 69, 0, 29, 33, 0, 27, 97, 0, 10, 10, 10]);
  return bytes;
}

List<String> _wrapPrintableWords(String text, int columns) {
  final safe = String.fromCharCodes(
    text.runes.map(
      (character) => character >= 32 && character <= 126 ? character : 32,
    ),
  ).trim();
  if (safe.isEmpty) return const [''];
  final result = <String>[];
  var current = '';
  for (var word in safe.split(RegExp(r'\s+'))) {
    while (word.length > columns) {
      if (current.isNotEmpty) {
        result.add(current);
        current = '';
      }
      result.add(word.substring(0, columns));
      word = word.substring(columns);
    }
    if (word.isEmpty) continue;
    if (current.isEmpty) {
      current = word;
    } else if (current.length + word.length + 1 <= columns) {
      current = '$current $word';
    } else {
      result.add(current);
      current = word;
    }
  }
  if (current.isNotEmpty) result.add(current);
  return result;
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

  bool isDark(int x, int y) {
    final offset = (y * image.width + x) * 4;
    final red = rgba.getUint8(offset);
    final green = rgba.getUint8(offset + 1);
    final blue = rgba.getUint8(offset + 2);
    final alpha = rgba.getUint8(offset + 3) / 255;
    final luminance =
        ((0.299 * red) + (0.587 * green) + (0.114 * blue)) * alpha +
        (255 * (1 - alpha));
    return luminance < 175;
  }

  // Crop whitespace embedded in the logo asset before sending it to paper.
  var left = image.width;
  var top = image.height;
  var right = -1;
  var bottom = -1;
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      if (!isDark(x, y)) continue;
      if (x < left) left = x;
      if (x > right) right = x;
      if (y < top) top = y;
      if (y > bottom) bottom = y;
    }
  }
  if (right < left || bottom < top) {
    image.dispose();
    codec.dispose();
    return const [];
  }
  left = (left - 3).clamp(0, image.width - 1);
  right = (right + 3).clamp(0, image.width - 1);
  top = (top - 3).clamp(0, image.height - 1);
  bottom = (bottom + 3).clamp(0, image.height - 1);
  final widthBytes = (right - left + 8) ~/ 8;
  final imageHeight = bottom - top + 1;
  final raster = List<int>.filled(widthBytes * imageHeight, 0);
  for (var y = top; y <= bottom; y++) {
    for (var x = left; x <= right; x++) {
      if (isDark(x, y)) {
        raster[((y - top) * widthBytes) + ((x - left) ~/ 8)] |=
            0x80 >> ((x - left) % 8);
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
