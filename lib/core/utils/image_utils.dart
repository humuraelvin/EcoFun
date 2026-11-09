import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';

abstract final class ImageUtils {
  /// Downscale + re-encode natively (fast and light even on low-end phones).
  /// Keeps photos ~60–150 KB so uploads and AI analysis stay quick on mobile data.
  static Future<Uint8List> compressForUpload(String path, {int side = 960, int quality = 74}) async {
    final out = await FlutterImageCompress.compressWithFile(
      path,
      minWidth: side,
      minHeight: side,
      quality: quality,
      format: CompressFormat.jpeg,
      keepExif: false,
    );
    if (out != null && out.isNotEmpty) return out;
    return File(path).readAsBytes();
  }

  /// Smaller version for the vision model (inline images must stay well under ~180 KB).
  static Future<Uint8List> compressForAi(String path) async {
    var bytes = await compressForUpload(path, side: 720, quality: 72);
    if (bytes.lengthInBytes > 140 * 1024) {
      bytes = await compressForUpload(path, side: 560, quality: 62);
    }
    return bytes;
  }
}
