import 'package:flutter/foundation.dart';
import 'package:ru_passport/core/errors.dart';
import 'package:ru_passport/domain/ocr_result.dart';
import 'package:ru_passport/domain/parsed_field.dart';
import 'package:ru_passport/domain/passport_number.dart';
import 'package:ru_passport/infrastructure/ocr/local_ocr_client.dart';

enum RecognitionPhase {
  idle,
  startingService,
  preparingImage,
  ocr,
  ready,
  error,
}

class RecognitionController extends ChangeNotifier {
  RecognitionController({LocalOcrClient? client}) : _client = client ?? LocalOcrClient();

  final LocalOcrClient _client;

  RecognitionPhase phase = RecognitionPhase.idle;
  String? imagePath;
  OcrResult? result;
  OcrResult? registrationResult;
  String? errorMessage;
  String? registrationError;
  PassportNumberMatch numberMatch = PassportNumberMatch.none;
  final Map<String, String> fieldEdits = {};

  bool get canAddRegistration {
    final current = result;
    return current != null &&
        current.view == 'first_spread' &&
        current.errorCode == null &&
        phase == RecognitionPhase.ready;
  }

  String get statusLabel => switch (phase) {
    RecognitionPhase.idle => 'Выберите изображение паспорта',
    RecognitionPhase.startingService => 'Запуск сервиса',
    RecognitionPhase.preparingImage => 'Подготовка изображения',
    RecognitionPhase.ocr => 'Распознавание',
    RecognitionPhase.ready => result == null ? 'Готово' : _readyLabel(result!),
    RecognitionPhase.error => errorMessage ?? 'Ошибка',
  };

  Future<void> recognize(String path) async {
    imagePath = path;
    result = null;
    registrationResult = null;
    errorMessage = null;
    registrationError = null;
    numberMatch = PassportNumberMatch.none;
    fieldEdits.clear();
    _setPhase(RecognitionPhase.startingService);
    try {
      await _client.ensureStarted();
      _setPhase(RecognitionPhase.preparingImage);
      _setPhase(RecognitionPhase.ocr);
      final next = await _client.recognizeFile(path);
      result = next;
      for (final spec in kPassportFormFields) {
        fieldEdits[spec.id] = displayFieldValue(spec.id, next.fields[spec.id]?.value);
      }
      _setPhase(RecognitionPhase.ready);
    } on OcrException catch (error) {
      errorMessage = error.message;
      _setPhase(RecognitionPhase.error);
    } catch (_) {
      errorMessage = 'Не удалось собрать цифровую копию.';
      _setPhase(RecognitionPhase.error);
    }
  }

  Future<void> recognizeRegistration(String path) async {
    if (result == null || result!.view != 'first_spread' || result!.errorCode != null) {
      return;
    }
    registrationError = null;
    _setPhase(RecognitionPhase.ocr);
    try {
      await _client.ensureStarted();
      final next = await _client.recognizeFile(path, page: 'registration');
      if (next.errorCode != null) {
        registrationError = next.errorCode == 'NOT_REGISTRATION_PAGE'
            ? 'Это не страница регистрации.'
            : 'Не удалось прочитать страницу регистрации.';
        numberMatch = PassportNumberMatch.none;
        _setPhase(RecognitionPhase.ready);
        return;
      }
      registrationResult = next;
      fieldEdits['registrationAddress'] = next.fields['registrationAddress']?.value ?? '';
      numberMatch = matchPassportNumbers(
        firstNumber: fieldEdits['number'] ?? '',
        registrationNumber: next.fields['number']?.value ?? '',
      );
      _setPhase(RecognitionPhase.ready);
    } on OcrException catch (error) {
      registrationError = error.message;
      _setPhase(RecognitionPhase.ready);
    } catch (_) {
      registrationError = 'Не удалось прочитать страницу регистрации.';
      _setPhase(RecognitionPhase.ready);
    }
  }

  Future<void> disposeClient() => _client.dispose();

  void updateField(String id, String value) {
    fieldEdits[id] = value;
    notifyListeners();
  }

  void _setPhase(RecognitionPhase next) {
    phase = next;
    notifyListeners();
  }

  String _readyLabel(OcrResult current) {
    if (current.errorCode == 'NOT_FIRST_SPREAD' || current.errorCode == 'NOT_RUSSIAN_PASSPORT') {
      return 'Это не первый разворот паспорта';
    }
    final filled = kPassportFormFields.where((spec) {
      return (fieldEdits[spec.id] ?? displayFieldValue(spec.id, current.fields[spec.id]?.value))
          .trim()
          .isNotEmpty;
    }).length;
    return 'Цифровая копия · $filled полей';
  }
}
