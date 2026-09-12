import 'package:flutter_test/flutter_test.dart';
import 'package:ru_passport/domain/ocr_result.dart';

void main() {
  test('OcrResult.fromJson maps rotation payload without requiring fields', () {
    final result = OcrResult.fromJson({
      'request_id': 'abc',
      'image_width': 100,
      'image_height': 40,
      'rotation_degrees': 90,
      'model_version': 'fake-1',
      'provider': 'fake',
      'document_type': 'unknown',
      'document_confidence': 0,
      'view': 'unknown',
      'error_code': null,
      'timings': {
        'image_loading': 1,
        'orientation': 4,
        'preprocessing': 0,
        'ocr': 0,
        'parsing': 0,
        'total_ms': 5,
      },
      'fields': {},
      'lines': [],
    });
    expect(result.requestId, 'abc');
    expect(result.lines, isEmpty);
    expect(result.fields, isEmpty);
    expect(result.timings.orientation, 4);
    expect(result.rotationDegrees, 90);
    expect(result.documentType, 'unknown');
  });

  test('OcrResult.fromJson maps passport fields from RussianDocsOCR', () {
    final result = OcrResult.fromJson({
      'request_id': 'abc',
      'image_width': 100,
      'image_height': 40,
      'rotation_degrees': 0,
      'model_version': '4.4.1',
      'provider': 'russian_docs_ocr',
      'document_type': 'russian_passport',
      'document_confidence': 0.92,
      'view': 'first_spread',
      'error_code': null,
      'timings': {
        'image_loading': 1,
        'orientation': 4,
        'preprocessing': 0,
        'ocr': 80,
        'parsing': 1,
        'total_ms': 90,
      },
      'fields': {
        'lastName': {'value': 'ИВАНОВ', 'confidence': 0.92, 'raw_value': 'ИВАНОВ'},
        'series': {'value': '1234', 'confidence': 0.92, 'raw_value': '1234'},
      },
      'lines': [],
    });
    expect(result.documentType, 'russian_passport');
    expect(result.fields['lastName']?.value, 'ИВАНОВ');
    expect(result.fields['series']?.value, '1234');
  });

  test('OcrResult.fromJson maps photo, signature and warnings', () {
    final result = OcrResult.fromJson({
      'request_id': 'abc',
      'image_width': 100,
      'image_height': 40,
      'rotation_degrees': 0,
      'model_version': '4.4.1',
      'provider': 'russian_docs_ocr',
      'document_type': 'russian_passport',
      'document_confidence': 0.9,
      'view': 'first_spread',
      'error_code': null,
      'photo_jpeg_base64': 'ZmFrZQ==',
      'signature_jpeg_base64': 'c2lnbg==',
      'warnings': [
        {'code': 'PHOTO_NOT_FOUND', 'field': 'photo'},
      ],
      'timings': {
        'image_loading': 1,
        'orientation': 0,
        'preprocessing': 0,
        'ocr': 10,
        'parsing': 1,
        'total_ms': 12,
      },
      'fields': {
        'registrationAddress': {'value': 'Г. МОСКВА', 'confidence': 0.8},
      },
      'lines': [],
    });
    expect(result.photoJpegBase64, 'ZmFrZQ==');
    expect(result.photoBytes, isNotNull);
    expect(result.signatureJpegBase64, 'c2lnbg==');
    expect(result.hasWarning('PHOTO_NOT_FOUND'), isTrue);
    expect(result.fields['registrationAddress']?.value, 'Г. МОСКВА');
  });
}
