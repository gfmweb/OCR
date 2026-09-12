import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ru_passport/application/recognition_controller.dart';
import 'package:ru_passport/core/constants.dart';
import 'package:ru_passport/domain/ocr_result.dart';
import 'package:ru_passport/domain/parsed_field.dart';
import 'package:ru_passport/domain/passport_number.dart';
import 'package:ru_passport/presentation/home_screen.dart';

void main() {
  testWidgets('home screen shows title and drop zone', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(PassportApp(controller: RecognitionController()));
    expect(find.text(AppConstants.appTitle), findsOneWidget);
    expect(find.text('Перетащите изображение паспорта'), findsOneWidget);
    expect(find.text('Выбрать файл'), findsWidgets);
  });

  testWidgets('ready result shows digital copy fields', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = RecognitionController();
    controller.phase = RecognitionPhase.ready;
    controller.result = const OcrResult(
      requestId: 'copy-test',
      lines: [],
      timings: StageTimings(
        imageLoading: 1,
        orientation: 12,
        preprocessing: 0,
        ocr: 40,
        parsing: 2,
        totalMs: 60,
      ),
      imageWidth: 100,
      imageHeight: 80,
      rotationDegrees: 0,
      modelVersion: 'fake-rdocs-1',
      provider: 'fake-rdocs',
      documentType: 'russian_passport',
      documentConfidence: 0.9,
      view: 'first_spread',
      fields: {
        'lastName': ParsedField(value: 'ИВАНОВ', confidence: 0.9, sourceRegion: null),
        'firstName': ParsedField(value: 'ИВАН', confidence: 0.9, sourceRegion: null),
      },
    );
    controller.fieldEdits['lastName'] = 'ИВАНОВ';
    controller.fieldEdits['firstName'] = 'ИВАН';

    await tester.pumpWidget(PassportApp(controller: controller));
    expect(find.text('Цифровая копия'), findsOneWidget);
    expect(find.text('Фамилия'), findsOneWidget);
    expect(find.textContaining('Заполнено 2 из'), findsOneWidget);
    expect(find.text('Определение ориентации'), findsNothing);
    expect(find.textContaining('Поворот'), findsNothing);
    expect(find.text('Отладка'), findsNothing);
    expect(find.text('Добавить страницу регистрации'), findsOneWidget);
    expect(find.text('Фото не найдено'), findsOneWidget);
    expect(find.text('Подпись не найдена'), findsOneWidget);
    expect(find.text('Адрес регистрации'), findsOneWidget);
  });

  testWidgets('mismatch banner keeps address in the form', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = RecognitionController();
    controller.phase = RecognitionPhase.ready;
    controller.result = const OcrResult(
      requestId: 'copy-test',
      lines: [],
      timings: StageTimings(
        imageLoading: 1,
        orientation: 0,
        preprocessing: 0,
        ocr: 40,
        parsing: 2,
        totalMs: 60,
      ),
      imageWidth: 100,
      imageHeight: 80,
      rotationDegrees: 0,
      modelVersion: 'fake-rdocs-1',
      provider: 'fake-rdocs',
      documentType: 'russian_passport',
      documentConfidence: 0.9,
      view: 'first_spread',
      fields: {
        'lastName': ParsedField(value: 'ИВАНОВ', confidence: 0.9, sourceRegion: null),
        'series': ParsedField(value: '1234', confidence: 0.9, sourceRegion: null),
        'number': ParsedField(value: '567890', confidence: 0.9, sourceRegion: null),
      },
    );
    controller.fieldEdits['lastName'] = 'ИВАНОВ';
    controller.fieldEdits['series'] = '1234';
    controller.fieldEdits['number'] = '567890';
    controller.fieldEdits['registrationAddress'] = 'Г. МОСКВА, УЛ. ТВЕРСКАЯ Д. 1';
    controller.numberMatch = PassportNumberMatch.mismatch;
    controller.registrationResult = const OcrResult(
      requestId: 'reg-test',
      lines: [],
      timings: StageTimings(
        imageLoading: 1,
        orientation: 0,
        preprocessing: 0,
        ocr: 20,
        parsing: 1,
        totalMs: 30,
      ),
      imageWidth: 80,
      imageHeight: 100,
      rotationDegrees: 0,
      modelVersion: 'fake-rdocs-1',
      provider: 'fake-rdocs',
      documentType: 'russian_passport',
      documentConfidence: 0.8,
      view: 'registration',
      fields: {
        'registrationAddress': ParsedField(
          value: 'Г. МОСКВА, УЛ. ТВЕРСКАЯ Д. 1',
          confidence: 0.8,
          sourceRegion: null,
        ),
      },
    );

    await tester.pumpWidget(PassportApp(controller: controller));
    expect(find.text('Номер на странице регистрации не совпадает'), findsOneWidget);
    expect(find.text('Г. МОСКВА, УЛ. ТВЕРСКАЯ Д. 1'), findsOneWidget);
    expect(find.text('Добавить страницу регистрации'), findsOneWidget);
  });

  testWidgets('empty registration address shows warning', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = RecognitionController();
    controller.phase = RecognitionPhase.ready;
    controller.result = const OcrResult(
      requestId: 'copy-test',
      lines: [],
      timings: StageTimings(
        imageLoading: 1,
        orientation: 0,
        preprocessing: 0,
        ocr: 40,
        parsing: 2,
        totalMs: 60,
      ),
      imageWidth: 100,
      imageHeight: 80,
      rotationDegrees: 0,
      modelVersion: 'fake-rdocs-1',
      provider: 'fake-rdocs',
      documentType: 'russian_passport',
      documentConfidence: 0.9,
      view: 'first_spread',
      fields: {
        'lastName': ParsedField(value: 'ИВАНОВ', confidence: 0.9, sourceRegion: null),
        'number': ParsedField(value: '567890', confidence: 0.9, sourceRegion: null),
      },
    );
    controller.fieldEdits['lastName'] = 'ИВАНОВ';
    controller.fieldEdits['number'] = '567890';
    controller.fieldEdits['registrationAddress'] = '';
    controller.registrationResult = const OcrResult(
      requestId: 'reg-empty',
      lines: [],
      timings: StageTimings(
        imageLoading: 1,
        orientation: 0,
        preprocessing: 0,
        ocr: 20,
        parsing: 1,
        totalMs: 30,
      ),
      imageWidth: 80,
      imageHeight: 100,
      rotationDegrees: 0,
      modelVersion: 'fake-rdocs-1',
      provider: 'fake-rdocs',
      documentType: 'russian_passport',
      documentConfidence: 0.8,
      view: 'registration',
      warnings: [
        {'code': 'ADDRESS_NOT_RECOGNIZED', 'field': 'registrationAddress'},
      ],
      fields: const {},
    );

    await tester.pumpWidget(PassportApp(controller: controller));
    expect(find.text('Адрес прописки не распознан.'), findsOneWidget);
    expect(find.text('[рукопись]'), findsNothing);
  });
}
