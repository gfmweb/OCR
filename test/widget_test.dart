import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ru_passport/application/passport_plaintext_factory.dart';
import 'package:ru_passport/application/recognition_controller.dart';
import 'package:ru_passport/core/constants.dart';
import 'package:ru_passport/crypto/encrypted_passport_payload.dart';
import 'package:ru_passport/crypto/passport_encryption_service.dart';
import 'package:ru_passport/crypto/passport_plaintext.dart';
import 'package:ru_passport/domain/ocr_result.dart';
import 'package:ru_passport/domain/parsed_field.dart';
import 'package:ru_passport/domain/pipeline_step.dart';
import 'package:ru_passport/presentation/home_screen.dart';

void main() {
  const timings = StageTimings(
    imageLoading: 1,
    orientation: 0,
    preprocessing: 0,
    ocr: 20,
    parsing: 1,
    totalMs: 30,
  );

  OcrResult firstSpread() {
    return const OcrResult(
      requestId: 'copy-test',
      lines: [],
      timings: timings,
      imageWidth: 100,
      imageHeight: 80,
      rotationDegrees: 0,
      modelVersion: 'fake-rdocs-1',
      provider: 'fake-rdocs',
      documentType: 'russian_passport',
      documentConfidence: 0.9,
      view: 'first_spread',
      fields: {
        'lastName': ParsedField(
          value: 'ИВАНОВ',
          confidence: 0.9,
          sourceRegion: null,
        ),
        'firstName': ParsedField(
          value: 'ИВАН',
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

  OcrResult registration({String? address}) {
    return OcrResult(
      requestId: 'reg-test',
      lines: const [],
      timings: timings,
      imageWidth: 80,
      imageHeight: 100,
      rotationDegrees: 0,
      modelVersion: 'fake-rdocs-1',
      provider: 'fake-rdocs',
      documentType: 'russian_passport',
      documentConfidence: 0.8,
      view: 'registration',
      warnings: address == null || address.isEmpty
          ? const [
              {
                'code': 'ADDRESS_NOT_RECOGNIZED',
                'field': 'registrationAddress',
              },
            ]
          : const [],
      fields: {
        'number': const ParsedField(
          value: '567890',
          confidence: 0.8,
          sourceRegion: null,
        ),
        if (address != null && address.isNotEmpty)
          'registrationAddress': ParsedField(
            value: address,
            confidence: 0.8,
            sourceRegion: null,
          ),
      },
    );
  }

  void setDesktopView(WidgetTester tester) {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('home screen shows title, steps and drop zone', (tester) async {
    setDesktopView(tester);

    await tester.pumpWidget(PassportApp(controller: RecognitionController()));
    expect(find.text(AppConstants.appTitle), findsOneWidget);
    expect(find.text('Разворот'), findsWidgets);
    expect(find.text('Регистрация'), findsWidgets);
    expect(find.text('Редактирование\nи проверка'), findsOneWidget);
    expect(find.text('Шифрование'), findsOneWidget);
    expect(find.text('Отправка'), findsOneWidget);
    expect(find.text('Перетащите основной разворот паспорта'), findsOneWidget);
    expect(find.text('Выбрать файл'), findsWidgets);
    expect(find.byKey(const Key('snapshot-firstSpread')), findsOneWidget);
    expect(find.byKey(const Key('snapshot-registration')), findsOneWidget);
    expect(
      find.image(const AssetImage(AppConstants.appIconAsset)),
      findsOneWidget,
    );
    expect(find.text('изменено'), findsNothing);
    expect(find.text('отредактировано'), findsNothing);
  });

  testWidgets('locked steps and review stay closed until registration', (
    tester,
  ) async {
    setDesktopView(tester);
    final controller = RecognitionController();
    controller.phase = RecognitionPhase.ready;
    controller.result = firstSpread();
    controller.firstSpreadPath = '/tmp/first.png';
    controller.fieldEdits['lastName'] = 'ИВАНОВ';

    await tester.pumpWidget(PassportApp(controller: controller));
    await tester.tap(find.byKey(const Key('pipeline-step-encryption')));
    await tester.tap(find.byKey(const Key('pipeline-step-send')));
    await tester.tap(find.byKey(const Key('pipeline-step-review')));
    await tester.pump();
    expect(controller.currentStep, PipelineStep.firstSpread);
    expect(find.text('Данные паспорта'), findsNothing);
    expect(find.text('Адрес регистрации'), findsNothing);
    expect(
      tester
          .widget<EditableText>(
            find.descendant(
              of: find.byKey(const ValueKey('copy-test-lastName')),
              matching: find.byType(EditableText),
            ),
          )
          .readOnly,
      isTrue,
    );
    expect(find.text('ИВАНОВ'), findsOneWidget);

    await tester.tap(find.byKey(const Key('pipeline-step-registration')));
    await tester.pump();
    expect(controller.currentStep, PipelineStep.registration);
    expect(find.text('Перетащите страницу регистрации'), findsOneWidget);
  });

  testWidgets('review shows digital copy after registration', (tester) async {
    setDesktopView(tester);
    final controller = RecognitionController();
    controller.phase = RecognitionPhase.ready;
    controller.result = firstSpread();
    controller.firstSpreadPath = '/tmp/first.png';
    controller.registrationPath = '/tmp/reg.png';
    controller.registrationResult = registration(address: 'Г. МОСКВА');
    controller.currentStep = PipelineStep.review;
    controller.fieldEdits['lastName'] = 'ИВАНОВ';
    controller.fieldEdits['firstName'] = 'ИВАН';
    controller.fieldEdits['registrationAddress'] = 'Г. МОСКВА';

    await tester.pumpWidget(PassportApp(controller: controller));
    expect(find.text('Данные паспорта'), findsOneWidget);
    expect(find.text('Фамилия'), findsOneWidget);
    expect(find.textContaining('Заполнено 5 из'), findsOneWidget);
    expect(find.text('Определение ориентации'), findsNothing);
    expect(find.textContaining('Поворот'), findsNothing);
    expect(find.text('Отладка'), findsNothing);
    expect(find.text('Фото не найдено'), findsOneWidget);
    expect(find.text('Подпись не найдена'), findsOneWidget);
    expect(find.text('Адрес регистрации'), findsOneWidget);
  });

  testWidgets('review keeps registration address in the form', (tester) async {
    setDesktopView(tester);
    final controller = RecognitionController();
    controller.phase = RecognitionPhase.ready;
    controller.result = firstSpread();
    controller.firstSpreadPath = '/tmp/first.png';
    controller.registrationPath = '/tmp/reg.png';
    controller.currentStep = PipelineStep.review;
    controller.fieldEdits['lastName'] = 'ИВАНОВ';
    controller.fieldEdits['series'] = '1234';
    controller.fieldEdits['number'] = '567890';
    controller.fieldEdits['registrationAddress'] =
        'Г. МОСКВА, УЛ. ТВЕРСКАЯ Д. 1';
    controller.registrationResult = registration(
      address: 'Г. МОСКВА, УЛ. ТВЕРСКАЯ Д. 1',
    );

    await tester.pumpWidget(PassportApp(controller: controller));
    expect(
      find.text('Не удалось сверить номер паспорта на странице регистрации'),
      findsNothing,
    );
    expect(
      find.text('Номер на странице регистрации не совпадает'),
      findsNothing,
    );
    expect(find.text('Г. МОСКВА, УЛ. ТВЕРСКАЯ Д. 1'), findsOneWidget);
  });

  testWidgets('empty registration address shows warning', (tester) async {
    setDesktopView(tester);
    final controller = RecognitionController();
    controller.phase = RecognitionPhase.ready;
    controller.result = firstSpread();
    controller.firstSpreadPath = '/tmp/first.png';
    controller.registrationPath = '/tmp/reg.png';
    controller.currentStep = PipelineStep.review;
    controller.fieldEdits['lastName'] = 'ИВАНОВ';
    controller.fieldEdits['number'] = '567890';
    controller.fieldEdits['registrationAddress'] = '';
    controller.registrationResult = registration();

    await tester.pumpWidget(PassportApp(controller: controller));
    expect(find.text('Адрес прописки не распознан.'), findsOneWidget);
    expect(find.text('[рукопись]'), findsNothing);
  });

  testWidgets('both snapshot slots stay visible', (tester) async {
    setDesktopView(tester);
    final controller = RecognitionController();
    controller.phase = RecognitionPhase.ready;
    controller.result = firstSpread();
    controller.registrationResult = registration(address: 'Г. МОСКВА');
    controller.firstSpreadPath = '/tmp/first.png';
    controller.registrationPath = '/tmp/reg.png';
    controller.currentStep = PipelineStep.review;

    await tester.pumpWidget(PassportApp(controller: controller));
    expect(find.byKey(const Key('snapshot-firstSpread')), findsOneWidget);
    expect(find.byKey(const Key('snapshot-registration')), findsOneWidget);
    expect(find.text('Снимок добавлен'), findsNWidgets(2));
  });

  testWidgets('registration step keeps address warning only', (tester) async {
    setDesktopView(tester);
    final controller = RecognitionController();
    controller.phase = RecognitionPhase.ready;
    controller.result = firstSpread();
    controller.firstSpreadPath = '/tmp/first.png';
    controller.registrationPath = '/tmp/reg.png';
    controller.registrationResult = registration();
    controller.currentStep = PipelineStep.registration;
    controller.fieldEdits['registrationAddress'] = '';

    await tester.pumpWidget(PassportApp(controller: controller));
    expect(
      find.text('Не удалось сверить номер паспорта на странице регистрации'),
      findsNothing,
    );
    expect(find.text('Адрес прописки не распознан.'), findsOneWidget);
  });

  testWidgets('review field keeps focus while typing', (tester) async {
    setDesktopView(tester);
    final controller = RecognitionController();
    controller.phase = RecognitionPhase.ready;
    controller.result = firstSpread();
    controller.firstSpreadPath = '/tmp/first.png';
    controller.registrationPath = '/tmp/reg.png';
    controller.registrationResult = registration(address: 'Г. МОСКВА');
    controller.currentStep = PipelineStep.review;
    controller.fieldEdits['lastName'] = 'ИВАНОВ';
    controller.fieldEdits['registrationAddress'] = 'Г. МОСКВА';

    await tester.pumpWidget(PassportApp(controller: controller));
    final field = find.byKey(const ValueKey('copy-test-lastName'));
    await tester.tap(field);
    await tester.enterText(field, 'ПЕТРОВ');
    await tester.pump();
    final editable = tester.state<EditableTextState>(
      find.descendant(of: field, matching: find.byType(EditableText)),
    );
    expect(editable.widget.controller.value.text, 'ПЕТРОВ');
    expect(editable.widget.focusNode.hasFocus, isTrue);
  });

  testWidgets('review next encrypts and shows ready to send', (tester) async {
    setDesktopView(tester);
    final controller = RecognitionController(
      encryptionService: _StubEncryptionService(),
      plaintextFactory: PassportPlaintextFactory(
        readPathBytes: (_) async => Uint8List(0),
      ),
    );
    controller.phase = RecognitionPhase.ready;
    controller.result = firstSpread();
    controller.firstSpreadPath = '/tmp/first.png';
    controller.registrationPath = '/tmp/reg.png';
    controller.registrationResult = registration(address: 'Г. МОСКВА');
    controller.currentStep = PipelineStep.review;
    controller.fieldEdits['lastName'] = 'ИВАНОВ';
    controller.fieldEdits['registrationAddress'] = 'Г. МОСКВА';

    await tester.pumpWidget(PassportApp(controller: controller));
    await tester.tap(find.text('Далее'));
    await tester.pump();
    await tester.pump();
    expect(controller.currentStep, PipelineStep.encryption);
    expect(find.text('Данные зашифрованы'), findsOneWidget);
    expect(
      find.text('Всё готово к передаче данных на сервер.'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Этот шаг появится позже. Данные пока остаются только на этом компьютере.',
      ),
      findsNothing,
    );
    expect(find.text('Zg=='), findsNothing);
    await tester.tap(find.byKey(const Key('pipeline-step-send')));
    await tester.pump();
    expect(controller.currentStep, PipelineStep.encryption);
  });

  testWidgets('blocks work while OCR models are loading', (tester) async {
    setDesktopView(tester);
    final controller = RecognitionController(serviceReady: false);
    controller.serviceStage = 'loading_models';
    controller.serviceProgress = 55;
    await tester.pumpWidget(PassportApp(controller: controller));
    expect(find.text('Загрузка моделей'), findsOneWidget);
    expect(controller.canGoNext, isFalse);
    expect(controller.canSelectStep(PipelineStep.registration), isFalse);
  });

  testWidgets('photo caption stays on one line', (tester) async {
    setDesktopView(tester);
    const pixel =
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';
    final controller = RecognitionController();
    controller.phase = RecognitionPhase.ready;
    controller.result = const OcrResult(
      requestId: 'copy-test',
      lines: [],
      timings: timings,
      imageWidth: 100,
      imageHeight: 80,
      rotationDegrees: 0,
      modelVersion: 'fake-rdocs-1',
      provider: 'fake-rdocs',
      documentType: 'russian_passport',
      documentConfidence: 0.9,
      view: 'first_spread',
      fields: {},
      photoJpegBase64: pixel,
    );
    controller.firstSpreadPath = '/tmp/first.png';
    await tester.pumpWidget(PassportApp(controller: controller));
    final caption = find.text('Фотография');
    expect(caption, findsOneWidget);
    expect(tester.getSize(caption).height, lessThan(28));
  });
}

class _StubEncryptionService extends PassportEncryptionService {
  @override
  Future<EncryptedPassportPayload> encrypt(PassportPlaintext plaintext) async {
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
