import 'package:flutter_test/flutter_test.dart';
import 'package:ru_passport/application/recognition_controller.dart';
import 'package:ru_passport/domain/ocr_result.dart';
import 'package:ru_passport/domain/parsed_field.dart';

void main() {
  OcrResult firstSpread() {
    return const OcrResult(
      requestId: 'first',
      lines: [],
      timings: StageTimings(
        imageLoading: 1,
        orientation: 0,
        preprocessing: 0,
        ocr: 10,
        parsing: 1,
        totalMs: 12,
      ),
      imageWidth: 100,
      imageHeight: 80,
      rotationDegrees: 0,
      modelVersion: 'fake',
      provider: 'fake',
      documentType: 'russian_passport',
      documentConfidence: 0.9,
      view: 'first_spread',
      fields: {
        'series': ParsedField(value: '1234', confidence: 0.9, sourceRegion: null),
        'number': ParsedField(value: '567890', confidence: 0.9, sourceRegion: null),
      },
    );
  }

  test('canAddRegistration only after a successful first spread', () {
    final controller = RecognitionController();
    expect(controller.canAddRegistration, isFalse);
    controller.phase = RecognitionPhase.ready;
    controller.result = firstSpread();
    expect(controller.canAddRegistration, isTrue);
    controller.result = OcrResult(
      requestId: 'bad',
      lines: const [],
      timings: const StageTimings(
        imageLoading: 1,
        orientation: 0,
        preprocessing: 0,
        ocr: 10,
        parsing: 1,
        totalMs: 12,
      ),
      imageWidth: 100,
      imageHeight: 80,
      rotationDegrees: 0,
      modelVersion: 'fake',
      provider: 'fake',
      documentType: 'unknown',
      documentConfidence: 0,
      view: 'unknown',
      errorCode: 'NOT_FIRST_SPREAD',
      fields: const {},
    );
    expect(controller.canAddRegistration, isFalse);
  });
}
