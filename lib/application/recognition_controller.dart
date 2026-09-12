import 'package:flutter/foundation.dart';
import 'package:ru_passport/core/errors.dart';
import 'package:ru_passport/domain/ocr_result.dart';
import 'package:ru_passport/domain/parsed_field.dart';
import 'package:ru_passport/domain/passport_number.dart';
import 'package:ru_passport/domain/pipeline_step.dart';
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
  PipelineStep currentStep = PipelineStep.firstSpread;
  String? firstSpreadPath;
  String? registrationPath;
  OcrResult? result;
  OcrResult? registrationResult;
  String? errorMessage;
  String? registrationError;
  PassportNumberMatch numberMatch = PassportNumberMatch.none;
  final Map<String, String> fieldEdits = {};
  final Map<String, String> fieldOriginals = {};

  String? get imagePath => firstSpreadPath;

  bool get isBusy =>
      phase == RecognitionPhase.startingService ||
      phase == RecognitionPhase.preparingImage ||
      phase == RecognitionPhase.ocr;

  bool get hasSuccessfulFirstSpread {
    final current = result;
    return current != null && current.view == 'first_spread' && current.errorCode == null;
  }

  bool get hasSuccessfulRegistration {
    final current = registrationResult;
    return current != null && current.view == 'registration' && current.errorCode == null;
  }

  bool get canAddRegistration =>
      hasSuccessfulFirstSpread && phase == RecognitionPhase.ready;

  bool get canGoBack => currentStep.previous != null && !isBusy;

  bool get canGoNext {
    if (isBusy) {
      return false;
    }
    return switch (currentStep) {
      PipelineStep.firstSpread => hasSuccessfulFirstSpread,
      PipelineStep.registration => hasSuccessfulRegistration,
      PipelineStep.review || PipelineStep.encryption || PipelineStep.send => false,
    };
  }

  String get statusLabel => switch (phase) {
    RecognitionPhase.idle => 'Выберите изображение паспорта',
    RecognitionPhase.startingService => 'Запуск сервиса',
    RecognitionPhase.preparingImage => 'Подготовка изображения',
    RecognitionPhase.ocr => 'Распознавание',
    RecognitionPhase.ready => result == null ? 'Готово' : _readyLabel(result!),
    RecognitionPhase.error => errorMessage ?? 'Ошибка',
  };

  bool isFieldEdited(String id) {
    return (fieldEdits[id] ?? '').trim() != (fieldOriginals[id] ?? '').trim();
  }

  Set<String> get editedFieldIds {
    return {
      for (final spec in kPassportFormFields)
        if (isFieldEdited(spec.id)) spec.id,
    };
  }

  bool canSelectStep(PipelineStep step) {
    if (step.isPlaceholder || isBusy) {
      return false;
    }
    return switch (step) {
      PipelineStep.firstSpread => true,
      PipelineStep.registration => hasSuccessfulFirstSpread,
      PipelineStep.review => hasSuccessfulRegistration,
      PipelineStep.encryption || PipelineStep.send => false,
    };
  }

  void selectStep(PipelineStep step) {
    if (!canSelectStep(step) || step == currentStep) {
      return;
    }
    currentStep = step;
    notifyListeners();
  }

  void goBack() {
    final previous = currentStep.previous;
    if (previous == null || !canSelectStep(previous)) {
      return;
    }
    selectStep(previous);
  }

  void goNext() {
    final next = currentStep.next;
    if (!canGoNext || next == null || !canSelectStep(next)) {
      return;
    }
    selectStep(next);
  }

  Future<void> recognize(String path) async {
    firstSpreadPath = path;
    result = null;
    registrationPath = null;
    registrationResult = null;
    errorMessage = null;
    registrationError = null;
    numberMatch = PassportNumberMatch.none;
    fieldEdits.clear();
    fieldOriginals.clear();
    currentStep = PipelineStep.firstSpread;
    _setPhase(RecognitionPhase.startingService);
    try {
      await _client.ensureStarted();
      _setPhase(RecognitionPhase.preparingImage);
      _setPhase(RecognitionPhase.ocr);
      final next = await _client.recognizeFile(path);
      result = next;
      _snapshotAllFields(next);
      if (next.errorCode != null) {
        errorMessage = next.errorCode == 'NOT_FIRST_SPREAD' || next.errorCode == 'NOT_RUSSIAN_PASSPORT'
            ? 'Это не первый разворот внутреннего паспорта РФ.'
            : 'Не удалось собрать цифровую копию.';
        _setPhase(RecognitionPhase.error);
        return;
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
    if (!hasSuccessfulFirstSpread) {
      return;
    }
    registrationPath = path;
    registrationError = null;
    currentStep = PipelineStep.registration;
    _setPhase(RecognitionPhase.ocr);
    try {
      await _client.ensureStarted();
      final next = await _client.recognizeFile(path, page: 'registration');
      if (next.errorCode != null) {
        registrationResult = null;
        registrationError = next.errorCode == 'NOT_REGISTRATION_PAGE'
            ? 'Это не страница регистрации.'
            : 'Не удалось прочитать страницу регистрации.';
        numberMatch = PassportNumberMatch.none;
        _snapshotField('registrationAddress', '');
        _setPhase(RecognitionPhase.ready);
        return;
      }
      registrationResult = next;
      _snapshotField(
        'registrationAddress',
        next.fields['registrationAddress']?.value ?? '',
      );
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

  void _snapshotAllFields(OcrResult next) {
    for (final spec in kPassportFormFields) {
      _snapshotField(
        spec.id,
        displayFieldValue(spec.id, next.fields[spec.id]?.value),
      );
    }
  }

  void _snapshotField(String id, String value) {
    fieldOriginals[id] = value;
    fieldEdits[id] = value;
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
    return 'Данные паспорта · $filled полей';
  }
}
