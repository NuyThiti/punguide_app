import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';

/// Validates decoded dimensions before upload. Platform codecs convert HEIC
/// when supported; otherwise retain the selection and report an actionable error.
Future<(Uint8List, String)> preparePostPhoto(String path) async {
  final bytes = await XFile(path).readAsBytes();
  if (bytes.length > 15 * 1024 * 1024)
    throw const FormatException(
        'รูปต้องมีขนาดไม่เกิน 15 MiB กรุณาลดขนาดหรือเอารูปนี้ออก');
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  ui.ImageDescriptor? descriptor;
  try {
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    if (descriptor.width * descriptor.height > 40000000)
      throw const FormatException('รูปต้องมีขนาดไม่เกิน 40 ล้าน pixels');
    final jpeg = bytes.length > 2 && bytes[0] == 255 && bytes[1] == 216;
    final png = bytes.length > 8 &&
        bytes[0] == 137 &&
        bytes[1] == 80 &&
        bytes[2] == 78 &&
        bytes[3] == 71;
    final webp = bytes.length > 12 &&
        String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
        String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP';
    if (jpeg || png || webp)
      return (
        bytes,
        jpeg
            ? 'photo.jpg'
            : png
                ? 'photo.png'
                : 'photo.webp'
      );
    final codec = await descriptor.instantiateCodec();
    try {
      final frame = await codec.getNextFrame();
      try {
        final converted =
            await frame.image.toByteData(format: ui.ImageByteFormat.png);
        if (converted == null || converted.lengthInBytes > 15 * 1024 * 1024)
          throw const FormatException(
              'แปลงรูปแล้วเกิน 15 MiB กรุณาเลือกรูป JPEG/PNG/WebP ที่เล็กลง');
        return (converted.buffer.asUint8List(), 'photo.png');
      } finally {
        frame.image.dispose();
      }
    } finally {
      codec.dispose();
    }
  } on FormatException {
    rethrow;
  } catch (_) {
    throw const FormatException(
        'อ่านหรือแปลงรูปไม่สำเร็จ กรุณาใช้ JPEG/PNG/WebP แทน รูปเดิมยังอยู่ในร่าง');
  } finally {
    descriptor?.dispose();
    buffer.dispose();
  }
}
