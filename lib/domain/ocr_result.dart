import 'dart:convert';
import 'dart:typed_data';

import 'package:ru_passport/domain/ocr_line.dart';
import 'package:ru_passport/domain/parsed_field.dart';

class StageTimings {
  const StageTimings({
    required this.imageLoading,
    required this.orientation,
    required this.preprocessing,
    required this.ocr,
    required this.parsing,
    required this.totalMs,
    this.llm = 0,
  });

  final int imageLoading;
  final int orientation;
  final int preprocessing;
  final int ocr;
  final int parsing;
  final int llm;
  final int totalMs;

  factory StageTimings.fromJson(Map<String, dynamic> json) {
    return StageTimings(
      imageLoading: (json['image_loading'] as num?)?.toInt() ?? 0,
      orientation: (json['orientation'] as num?)?.toInt() ?? 0,
      preprocessing: (json['preprocessing'] as num?)?.toInt() ?? 0,
      ocr: (json['ocr'] as num?)?.toInt() ?? 0,
      parsing: (json['parsing'] as num?)?.toInt() ?? 0,
      llm: (json['llm'] as num?)?.toInt() ?? 0,
      totalMs: (json['total_ms'] as num?)?.toInt() ?? 0,
    );
  }
}

class OcrResult {
  const OcrResult({
    required this.requestId,
    required this.lines,
    required this.timings,
    required this.imageWidth,
    required this.imageHeight,
    required this.rotationDegrees,
    required this.modelVersion,
    required this.provider,
    required this.documentType,
    required this.documentConfidence,
    required this.view,
    required this.fields,
    this.errorCode,
    this.warnings = const [],
    this.photoJpegBase64,
    this.signatureJpegBase64,
  });

  final String requestId;
  final List<OcrLine> lines;
  final StageTimings timings;
  final int imageWidth;
  final int imageHeight;
  final int rotationDegrees;
  final String modelVersion;
  final String provider;
  final String documentType;
  final double documentConfidence;
  final String view;
  final String? errorCode;
  final Map<String, ParsedField> fields;
  final List<Map<String, dynamic>> warnings;
  final String? photoJpegBase64;
  final String? signatureJpegBase64;

  bool get isRussianPassport => documentType == 'russian_passport';

  Uint8List? get photoBytes => _decodeJpeg(photoJpegBase64);

  Uint8List? get signatureBytes => _decodeJpeg(signatureJpegBase64);

  bool hasWarning(String code) {
    return warnings.any((item) => item['code'] == code);
  }

  factory OcrResult.fromJson(Map<String, dynamic> json) {
    final lines = (json['lines'] as List<dynamic>? ?? const [])
        .map((item) => OcrLine.fromJson(_stringKeyedMap(item)))
        .toList();
    final rawFields = _stringKeyedMap(json['fields']);
    final fields = <String, ParsedField>{
      for (final entry in rawFields.entries)
        if (entry.value is Map)
          entry.key: ParsedField.fromJson(_stringKeyedMap(entry.value)),
    };
    final rawWarnings = json['warnings'];
    return OcrResult(
      requestId: json['request_id'] as String? ?? '',
      lines: lines,
      timings: StageTimings.fromJson(_stringKeyedMap(json['timings'])),
      imageWidth: (json['image_width'] as num?)?.toInt() ?? 0,
      imageHeight: (json['image_height'] as num?)?.toInt() ?? 0,
      rotationDegrees: (json['rotation_degrees'] as num?)?.toInt() ?? 0,
      modelVersion: json['model_version'] as String? ?? '',
      provider: json['provider'] as String? ?? '',
      documentType: json['document_type'] as String? ?? 'unknown',
      documentConfidence: (json['document_confidence'] as num?)?.toDouble() ?? 0,
      view: json['view'] as String? ?? 'unknown',
      errorCode: json['error_code'] as String?,
      fields: fields,
      warnings: rawWarnings is List
          ? rawWarnings.whereType<Map>().map(_stringKeyedMap).toList()
          : const [],
      photoJpegBase64: json['photo_jpeg_base64'] as String?,
      signatureJpegBase64: json['signature_jpeg_base64'] as String?,
    );
  }
}

Uint8List? _decodeJpeg(String? raw) {
  if (raw == null || raw.isEmpty) {
    return null;
  }
  try {
    return base64Decode(raw);
  } catch (_) {
    return null;
  }
}

Map<String, dynamic> _stringKeyedMap(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return {for (final entry in value.entries) entry.key.toString(): entry.value};
  }
  return const {};
}
