import 'package:ru_passport/domain/ocr_line.dart';

class ParsedField {
  const ParsedField({
    required this.value,
    required this.confidence,
    required this.sourceRegion,
    this.rawValue,
    this.alternatives = const [],
  });

  final String? rawValue;
  final String? value;
  final double confidence;
  final List<OcrPoint>? sourceRegion;
  final List<Map<String, dynamic>> alternatives;

  factory ParsedField.fromJson(Map<String, dynamic> json) {
    List<OcrPoint>? region;
    final rawRegion = json['source_region'];
    if (rawRegion is List) {
      region = rawRegion.whereType<List<dynamic>>().map(OcrPoint.fromJson).toList();
      if (region.length < 4) {
        region = null;
      }
    } else {
      final box = json['bbox'];
      if (box is Map<String, dynamic>) {
        final x = (box['x'] as num?)?.toDouble() ?? 0;
        final y = (box['y'] as num?)?.toDouble() ?? 0;
        final w = (box['width'] as num?)?.toDouble() ?? 0;
        final h = (box['height'] as num?)?.toDouble() ?? 0;
        region = [OcrPoint(x, y), OcrPoint(x + w, y), OcrPoint(x + w, y + h), OcrPoint(x, y + h)];
      }
    }
    final rawAlternatives = json['alternatives'];
    return ParsedField(
      rawValue: json['raw_value'] as String?,
      value: json['value'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      sourceRegion: region,
      alternatives: rawAlternatives is List
          ? rawAlternatives.whereType<Map<String, dynamic>>().toList()
          : const [],
    );
  }
}

class PassportFormSpec {
  const PassportFormSpec({required this.id, required this.label});

  final String id;
  final String label;
}

const kPassportFormFields = <PassportFormSpec>[
  PassportFormSpec(id: 'lastName', label: 'Фамилия'),
  PassportFormSpec(id: 'firstName', label: 'Имя'),
  PassportFormSpec(id: 'middleName', label: 'Отчество'),
  PassportFormSpec(id: 'gender', label: 'Пол'),
  PassportFormSpec(id: 'birthDate', label: 'Дата рождения'),
  PassportFormSpec(id: 'birthPlace', label: 'Место рождения'),
  PassportFormSpec(id: 'series', label: 'Серия'),
  PassportFormSpec(id: 'number', label: 'Номер'),
  PassportFormSpec(id: 'issueDate', label: 'Дата выдачи'),
  PassportFormSpec(id: 'issuedBy', label: 'Кем выдан'),
  PassportFormSpec(id: 'departmentCode', label: 'Код подразделения'),
  PassportFormSpec(id: 'registrationAddress', label: 'Адрес регистрации'),
];

const kLowFieldConfidence = 0.7;

String displayFieldValue(String id, String? value) {
  if (id == 'gender') {
    return switch (value) {
      'male' => 'муж',
      'female' => 'жен',
      _ => value ?? '',
    };
  }
  if (id == 'birthDate' || id == 'issueDate') {
    return formatDisplayDate(value);
  }
  return value ?? '';
}

String formatDisplayDate(String? value) {
  if (value == null || value.isEmpty) {
    return '';
  }
  final iso = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
  if (iso != null) {
    return '${iso.group(3)}.${iso.group(2)}.${iso.group(1)}';
  }
  return value;
}
