import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ru_passport/application/passport_plaintext_factory.dart';
import 'package:ru_passport/application/recognition_controller.dart';
import 'package:ru_passport/crypto/encrypted_passport_payload.dart';
import 'package:ru_passport/crypto/passport_encryption_service.dart';
import 'package:ru_passport/crypto/passport_plaintext.dart';
import 'package:ru_passport/domain/ocr_result.dart';
import 'package:ru_passport/domain/parsed_field.dart';
import 'package:ru_passport/domain/pipeline_step.dart';

void main() {
  const timings = StageTimings(
    imageLoading: 1,
    orientation: 0,
    preprocessing: 0,
    ocr: 10,
    parsing: 1,
    totalMs: 12,
  );

  OcrResult firstSpread() {
    return const OcrResult(
      requestId: 'first',
      lines: [],
      timings: timings,
      imageWidth: 100,
      imageHeight: 80,
      rotationDegrees: 0,
      modelVersion: 'fake',
      provider: 'fake',
      documentType: 'russian_passport',
      documentConfidence: 0.9,
      view: 'first_spread',
      fields: {
        'lastName': ParsedField(
          value: 'ИВАНОВ',
          confidence: 0.9,
          sourceRegion: null,
        ),
        'series': ParsedField(
          value: '1234',
          confidence: 0.9,
          sourceRegion: null,
        ),
        'number': ParsedField(
          value: '567890',
          confidence: 0.9,
          sourceRegion: null,
        ),
      },
    );
  }

  OcrResult registration() {
    return const OcrResult(
      requestId: 'reg',
      lines: [],
      timings: timings,
      imageWidth: 80,
      imageHeight: 100,
      rotationDegrees: 0,
      modelVersion: 'fake',
      provider: 'fake',
      documentType: 'russian_passport',
      documentConfidence: 0.8,
      view: 'registration',
      fields: {
        'number': ParsedField(
          value: '567890',
          confidence: 0.8,
          sourceRegion: null,
        ),
        'registrationAddress': ParsedField(
          value: 'Г. МОСКВА',
          confidence: 0.8,
          sourceRegion: null,
        ),
      },
    );
  }

  test('canAddRegistration only after a successful first spread', () {
    final controller = RecognitionController();
    expect(controller.canAddRegistration, isFalse);
    controller.phase = RecognitionPhase.ready;
    controller.result = firstSpread();
    expect(controller.canAddRegistration, isTrue);
    controller.result = const OcrResult(
      requestId: 'bad',
      lines: [],
      timings: timings,
      imageWidth: 100,
      imageHeight: 80,
      rotationDegrees: 0,
      modelVersion: 'fake',
      provider: 'fake',
      documentType: 'unknown',
      documentConfidence: 0,
      view: 'unknown',
      errorCode: 'NOT_FIRST_SPREAD',
      fields: {},
    );
    expect(controller.canAddRegistration, isFalse);
  });

  test(
    'unlocks registration after first spread and review after registration',
    () {
      final controller = RecognitionController();
      controller.phase = RecognitionPhase.ready;
      expect(controller.canSelectStep(PipelineStep.registration), isFalse);
      expect(controller.canSelectStep(PipelineStep.review), isFalse);
      expect(controller.canSelectStep(PipelineStep.encryption), isFalse);
      expect(controller.canSelectStep(PipelineStep.send), isFalse);

      controller.result = firstSpread();
      expect(controller.canSelectStep(PipelineStep.registration), isTrue);
      expect(controller.canSelectStep(PipelineStep.review), isFalse);
      expect(controller.canGoNext, isTrue);

      controller.registrationResult = registration();
      expect(controller.canSelectStep(PipelineStep.review), isTrue);
      expect(controller.canSelectStep(PipelineStep.encryption), isTrue);
      expect(controller.canSelectStep(PipelineStep.send), isFalse);
      controller.currentStep = PipelineStep.review;
      expect(controller.canGoNext, isTrue);
    },
  );

  test('going back without replacing a file keeps edits', () {
    final controller = RecognitionController();
    controller.phase = RecognitionPhase.ready;
    controller.result = firstSpread();
    controller.registrationResult = registration();
    controller.fieldEdits['lastName'] = 'ИВАНОВ';
    controller.fieldEdits['registrationAddress'] = 'Г. МОСКВА';
    controller.currentStep = PipelineStep.review;

    controller.selectStep(PipelineStep.firstSpread);
    expect(controller.currentStep, PipelineStep.firstSpread);
    expect(controller.fieldEdits['lastName'], 'ИВАНОВ');
    expect(controller.fieldEdits['registrationAddress'], 'Г. МОСКВА');
    expect(controller.registrationResult, isNotNull);

    controller.goNext();
    expect(controller.currentStep, PipelineStep.registration);
    controller.goNext();
    expect(controller.currentStep, PipelineStep.review);
    controller.goBack();
    expect(controller.currentStep, PipelineStep.registration);
  });

  test(
    'tracks edits against the recognized original without exposing them in UI',
    () {
      final controller = RecognitionController();
      controller.fieldOriginals['lastName'] = 'ИВАНОВ';
      controller.fieldEdits['lastName'] = 'ИВАНОВ';
      controller.fieldOriginals['firstName'] = 'ИВАН';
      controller.fieldEdits['firstName'] = 'ИВАН';
      expect(controller.isFieldEdited('lastName'), isFalse);
      expect(controller.editedFieldIds, isEmpty);

      controller.updateField('lastName', 'ПЕТРОВ');
      expect(controller.isFieldEdited('lastName'), isTrue);
      expect(controller.editedFieldIds, {'lastName'});
      expect(controller.fieldOriginals['lastName'], 'ИВАНОВ');

      controller.updateField('lastName', 'ИВАНОВ');
      expect(controller.isFieldEdited('lastName'), isFalse);
      expect(controller.editedFieldIds, isEmpty);
    },
  );

  test('new registration address replaces only that original', () {
    final controller = RecognitionController();
    controller.fieldOriginals['lastName'] = 'ИВАНОВ';
    controller.fieldEdits['lastName'] = 'ПЕТРОВ';
    controller.fieldOriginals['registrationAddress'] = '';
    controller.fieldEdits['registrationAddress'] = '';

    controller.fieldOriginals['registrationAddress'] = 'Г. МОСКВА';
    controller.fieldEdits['registrationAddress'] = 'Г. МОСКВА';

    expect(controller.fieldOriginals['lastName'], 'ИВАНОВ');
    expect(controller.fieldEdits['lastName'], 'ПЕТРОВ');
    expect(controller.isFieldEdited('lastName'), isTrue);
    expect(controller.isFieldEdited('registrationAddress'), isFalse);
    expect(controller.fieldOriginals['registrationAddress'], 'Г. МОСКВА');
  });

  test('review next encrypts and stays off the send step', () async {
    final encryption = _StubEncryptionService();
    final controller = RecognitionController(
      encryptionService: encryption,
      plaintextFactory: PassportPlaintextFactory(
        readPathBytes: (_) async => Uint8List(0),
      ),
    );
    controller.phase = RecognitionPhase.ready;
    controller.result = firstSpread();
    controller.registrationResult = registration();
    controller.currentStep = PipelineStep.review;

    controller.goNext();
    await controller.encryptDocument();
    expect(controller.currentStep, PipelineStep.encryption);
    expect(controller.hasEncryptedDocument, isTrue);
    expect(encryption.encryptCalls, 1);
    expect(controller.canSelectStep(PipelineStep.send), isFalse);
    expect(controller.canGoNext, isFalse);

    controller.updateField('lastName', 'ПЕТРОВ');
    expect(controller.hasEncryptedDocument, isFalse);
    expect(controller.encryptionPhase, EncryptionPhase.idle);
  });
}

class _StubEncryptionService extends PassportEncryptionService {
  int encryptCalls = 0;

  @override
  Future<EncryptedPassportPayload> encrypt(PassportPlaintext plaintext) async {
    encryptCalls++;
    return const EncryptedPassportPayload(
      version: 1,
      keyAlgorithm: 'RSA-OAEP-SHA256',
      dataAlgorithm: 'AES-256-GCM',
      encryptedKey: 'Zg==',
      passport: EncryptedBlob(ciphertext: 'YQ==', nonce: 'Yg==', tag: 'Yw=='),
      photos: [],
    );
  }
}
