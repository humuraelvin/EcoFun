import 'dart:convert';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';

enum WasteType { biodegradable, nonBiodegradable, uncertain }

class WasteClassification {
  const WasteClassification({
    required this.type,
    required this.detectedLabel,
    required this.reason,
    required this.confidence,
  });

  final WasteType type;
  final String detectedLabel;
  final String reason;
  final double confidence;

  String get displayName => switch (type) {
    WasteType.biodegradable => 'Biodegradable',
    WasteType.nonBiodegradable => 'Non-biodegradable',
    WasteType.uncertain => 'Could not classify',
  };
}

class WasteClassifier {
  static Future<WasteClassification> classifyFile(String path) async {
    final file = File(path);
    final bytes = await file.readAsBytes();
    if (bytes.length > 5 * 1024 * 1024) {
      throw const FormatException('Choose an image smaller than 5 MB.');
    }
    final name = path.toLowerCase();
    final mimeType = name.endsWith('.png')
        ? 'image/png'
        : name.endsWith('.webp')
        ? 'image/webp'
        : 'image/jpeg';
    final callable = FirebaseFunctions.instance.httpsCallable(
      'classifyWastePhoto',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 90)),
    );
    final result = await callable.call({
      'imageBase64': base64Encode(bytes),
      'mimeType': mimeType,
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    final type = switch (data['category']) {
      'biodegradable' => WasteType.biodegradable,
      'non_biodegradable' => WasteType.nonBiodegradable,
      _ => WasteType.uncertain,
    };
    return WasteClassification(
      type: type,
      detectedLabel: data['item'] as String? ?? 'Unknown item',
      reason: data['reason'] as String? ?? '',
      confidence: (data['confidence'] as num?)?.toDouble() ?? 0,
    );
  }
}
