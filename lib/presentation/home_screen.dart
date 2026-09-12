import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:ru_passport/application/recognition_controller.dart';
import 'package:ru_passport/core/constants.dart';
import 'package:ru_passport/domain/ocr_result.dart';
import 'package:ru_passport/domain/parsed_field.dart';
import 'package:ru_passport/domain/passport_number.dart';
import 'package:ru_passport/domain/pipeline_step.dart';
import 'package:ru_passport/presentation/theme/app_theme.dart';
import 'package:ru_passport/presentation/theme/tokens.dart';
import 'package:ru_passport/presentation/widgets/glass_panel.dart';
import 'package:ru_passport/presentation/widgets/image_drop_zone.dart';
import 'package:ru_passport/presentation/widgets/snapshot_strip.dart';
import 'package:ru_passport/presentation/widgets/step_rail.dart';

class PassportApp extends StatelessWidget {
  const PassportApp({super.key, this.controller});

  final RecognitionController? controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: HomeScreen(controller: controller),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.controller});

  final RecognitionController? controller;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final RecognitionController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? RecognitionController();
    _controller.addListener(_onUpdate);
  }

  @override
  void dispose() {
    _controller.removeListener(_onUpdate);
    if (_ownsController) {
      _controller.disposeClient();
      _controller.dispose();
    }
    super.dispose();
  }

  void _onUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<String?> _pickImagePath() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const [
        'jpg',
        'jpeg',
        'png',
        'webp',
        'bmp',
        'tif',
        'tiff',
      ],
    );
    return picked?.files.single.path;
  }

  Future<void> _pickFirstSpread() async {
    final path = await _pickImagePath();
    if (path != null) {
      await _controller.recognize(path);
    }
  }

  Future<void> _pickRegistration() async {
    final path = await _pickImagePath();
    if (path != null) {
      await _controller.recognizeRegistration(path);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: AppTheme.background,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Image.asset(
                      AppConstants.appIconAsset,
                      width: 32,
                      height: 32,
                      filterQuality: FilterQuality.high,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      AppConstants.appTitle,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                GlassPanel(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.sm,
                  ),
                  child: StepRail(
                    current: _controller.currentStep,
                    canSelect: _controller.canSelectStep,
                    isComplete: (step) => switch (step) {
                      PipelineStep.firstSpread =>
                        _controller.hasSuccessfulFirstSpread,
                      PipelineStep.registration =>
                        _controller.hasSuccessfulRegistration,
                      PipelineStep.review =>
                        _controller.hasEncryptedDocument ||
                            _controller.currentStep == PipelineStep.encryption,
                      PipelineStep.encryption =>
                        _controller.hasEncryptedDocument,
                      PipelineStep.send => false,
                    },
                    onSelect: _controller.selectStep,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                SnapshotStrip(
                  firstSpreadPath: _controller.firstSpreadPath,
                  registrationPath: _controller.registrationPath,
                  currentStep: _controller.currentStep,
                  canSelect: _controller.canSelectStep,
                  onSelect: _controller.selectStep,
                ),
                const SizedBox(height: AppSpacing.md),
                Expanded(child: _stepBody()),
                const SizedBox(height: AppSpacing.md),
                _navBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _stepBody() {
    return switch (_controller.currentStep) {
      PipelineStep.firstSpread => _firstSpreadStep(),
      PipelineStep.registration => _captureStep(
        title: 'Перетащите страницу регистрации',
        subtitle: 'Страница с адресом прописки',
        hasFile: _controller.registrationPath != null,
        onDrop: _controller.recognizeRegistration,
        onPick: _pickRegistration,
        errorText: _controller.registrationError,
        successText: _controller.hasSuccessfulRegistration
            ? 'Страница регистрации распознана. Проверьте данные на следующем шаге.'
            : null,
        extra: _registrationNotices(),
      ),
      PipelineStep.review => _reviewStep(),
      PipelineStep.encryption => _encryptionStep(),
      PipelineStep.send => const _PlaceholderStep(
        title: 'Отправка пакета',
        message:
            'Отправка будет добавлена позже. Сейчас пакет никуда не уходит.',
      ),
    };
  }

  Widget _firstSpreadStep() {
    if (_controller.firstSpreadPath == null && !_controller.isBusy) {
      return ImageDropZone(
        title: 'Перетащите основной разворот паспорта',
        subtitle: 'Страницы 2–3 внутреннего паспорта РФ',
        onPath: _controller.recognize,
        onPickFile: _pickFirstSpread,
      );
    }
    if (_controller.hasSuccessfulFirstSpread) {
      return _firstSpreadPreview();
    }
    return _captureStep(
      title: 'Перетащите основной разворот паспорта',
      subtitle: 'Страницы 2–3 внутреннего паспорта РФ',
      hasFile: true,
      onDrop: _controller.recognize,
      onPick: _pickFirstSpread,
      errorText: _controller.phase == RecognitionPhase.error
          ? _controller.errorMessage
          : null,
    );
  }

  Widget _firstSpreadPreview() {
    final result = _controller.result!;
    return SizedBox.expand(
      child: GlassPanel(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _identityImages(result),
                    for (final spec in kPassportFormFields)
                      if (spec.id != 'registrationAddress')
                        _fieldEditor(spec, result, readOnly: true),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _controller.isBusy ? null : _pickFirstSpread,
                icon: const Icon(Icons.swap_horiz),
                label: const Text('Заменить снимок'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _captureStep({
    required String title,
    required String subtitle,
    required bool hasFile,
    required ValueChanged<String> onDrop,
    required VoidCallback onPick,
    String? errorText,
    String? successText,
    Widget? extra,
  }) {
    if (!hasFile && !_controller.isBusy) {
      return ImageDropZone(
        title: title,
        subtitle: subtitle,
        onPath: onDrop,
        onPickFile: onPick,
      );
    }
    return SizedBox.expand(
      child: GlassPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _controller.statusLabel,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            if (_controller.isBusy) const LinearProgressIndicator(),
            if (errorText != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Text(
                  errorText,
                  style: const TextStyle(color: AppColors.danger),
                ),
              ),
            if (successText != null && !_controller.isBusy)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Text(
                  successText,
                  style: const TextStyle(color: AppColors.success),
                ),
              ),
            ?extra,
            const Spacer(),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _controller.isBusy ? null : onPick,
                icon: const Icon(Icons.swap_horiz),
                label: const Text('Заменить снимок'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _registrationNotices() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_controller.numberMatch == PassportNumberMatch.match ||
            _controller.numberMatch == PassportNumberMatch.mismatch)
          _numberMatchBanner(),
        if (_isRegistrationAddressMissing)
          const Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.md),
            child: Text(
              'Адрес прописки не распознан.',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
      ],
    );
  }

  Widget _reviewStep() {
    final result = _controller.result;
    if (result == null) {
      return const _PlaceholderStep(
        title: 'Редактирование и проверка',
        message:
            'Сначала распознайте основной разворот и страницу регистрации.',
      );
    }
    return SizedBox.expand(
      child: GlassPanel(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Данные паспорта',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                _resultSummary(result),
                style: const TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: AppSpacing.md),
              if (result.view == 'first_spread' && result.errorCode == null)
                _identityImages(result),
              if (_controller.numberMatch != PassportNumberMatch.none)
                _numberMatchBanner(),
              if (_isRegistrationAddressMissing)
                const Padding(
                  padding: EdgeInsets.only(bottom: AppSpacing.md),
                  child: Text(
                    'Адрес прописки не распознан.',
                    style: TextStyle(color: AppColors.danger),
                  ),
                ),
              for (final spec in kPassportFormFields)
                _fieldEditor(spec, result),
            ],
          ),
        ),
      ),
    );
  }

  Widget _encryptionStep() {
    final ready = _controller.hasEncryptedDocument;
    final failed = _controller.encryptionPhase == EncryptionPhase.error;
    final encrypting = !ready && !failed;
    return SizedBox.expand(
      child: GlassPanel(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              ready
                  ? Icons.check_circle_outline
                  : failed
                  ? Icons.error_outline
                  : Icons.lock_outline,
              size: 36,
              color: ready
                  ? AppColors.success
                  : failed
                  ? AppColors.danger
                  : AppColors.muted,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              ready
                  ? 'Данные зашифрованы'
                  : failed
                  ? 'Не удалось зашифровать'
                  : 'Шифрование данных',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              ready
                  ? 'Всё готово к передаче данных на сервер.'
                  : failed
                  ? (_controller.encryptionError ??
                        'Не удалось зашифровать документ.')
                  : 'Документ шифруется на этом компьютере.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: failed ? AppColors.danger : AppColors.muted,
              ),
            ),
            if (encrypting) ...[
              const SizedBox(height: AppSpacing.lg),
              const SizedBox(width: 240, child: LinearProgressIndicator()),
            ],
            if (failed) ...[
              const SizedBox(height: AppSpacing.lg),
              OutlinedButton(
                onPressed: _controller.isBusy
                    ? null
                    : () => _controller.encryptDocument(force: true),
                child: const Text('Повторить'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _navBar() {
    return Row(
      children: [
        OutlinedButton(
          onPressed: _controller.canGoBack ? _controller.goBack : null,
          child: const Text('Назад'),
        ),
        const Spacer(),
        FilledButton(
          onPressed: _controller.canGoNext ? _controller.goNext : null,
          child: const Text('Далее'),
        ),
      ],
    );
  }

  Widget _fieldEditor(
    PassportFormSpec spec,
    OcrResult result, {
    bool readOnly = false,
  }) {
    final field = result.fields[spec.id];
    final lowConfidence =
        (field?.confidence ?? 0) > 0 &&
        (field?.confidence ?? 0) < kLowFieldConfidence;
    final text =
        _controller.fieldEdits[spec.id] ??
        displayFieldValue(spec.id, field?.value);
    final multiline = spec.id == 'registrationAddress';
    final missing = _isUnrecognized(spec, text);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: TextFormField(
        key: ValueKey('${result.requestId}-${spec.id}'),
        initialValue: text,
        readOnly: readOnly,
        maxLines: multiline ? 4 : 1,
        decoration: InputDecoration(
          labelText: spec.label,
          isDense: true,
          filled: true,
          fillColor: missing ? AppColors.missingFill : AppColors.glassStrong,
          enabledBorder: missing
              ? const OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.danger),
                )
              : null,
          focusedBorder: missing
              ? const OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.danger, width: 2),
                )
              : null,
          suffixIcon: lowConfidence
              ? const Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.warning,
                )
              : null,
        ),
        onChanged: readOnly
            ? null
            : (value) => _controller.updateField(spec.id, value),
      ),
    );
  }

  bool get _isRegistrationAddressMissing {
    if (_controller.registrationResult == null) {
      return false;
    }
    return (_controller.fieldEdits['registrationAddress'] ?? '').trim().isEmpty;
  }

  bool _isUnrecognized(PassportFormSpec spec, String text) {
    if (_controller.result?.errorCode != null) {
      return false;
    }
    if (spec.id == 'registrationAddress' &&
        _controller.registrationResult == null) {
      return false;
    }
    return text.trim().isEmpty;
  }

  Widget _identityImages(OcrResult result) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _imageFrame(bytes: result.photoBytes, icon: Icons.person_outline),
              const SizedBox(width: AppSpacing.lg),
              _imageFrame(
                bytes: result.signatureBytes,
                icon: Icons.draw_outlined,
                width: 120,
                height: 56,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              SizedBox(
                width: 72,
                child: Text(
                  result.photoBytes == null ? 'Фото не найдено' : 'Фотография',
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              SizedBox(
                width: 120,
                child: Text(
                  result.signatureBytes == null
                      ? 'Подпись не найдена'
                      : 'Подпись',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _imageFrame({
    required Uint8List? bytes,
    required IconData icon,
    double width = 72,
    double height = 96,
  }) {
    final missing = bytes == null;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: missing ? Border.all(color: AppColors.danger) : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: missing
            ? Container(
                width: width,
                height: height,
                color: AppColors.missingFill,
                child: Icon(icon, color: AppColors.danger),
              )
            : Image.memory(
                bytes,
                width: width,
                height: height,
                fit: BoxFit.contain,
              ),
      ),
    );
  }

  Widget _numberMatchBanner() {
    final (text, color) = switch (_controller.numberMatch) {
      PassportNumberMatch.match => (
        'Номер совпадает с первым разворотом',
        AppColors.success,
      ),
      PassportNumberMatch.mismatch => (
        'Номер на странице регистрации не совпадает',
        AppColors.danger,
      ),
      PassportNumberMatch.missing => (
        'Не удалось сверить номер паспорта на странице регистрации',
        AppColors.warning,
      ),
      PassportNumberMatch.none => ('', AppColors.muted),
    };
    if (text.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Text(text, style: TextStyle(color: color)),
    );
  }

  String _resultSummary(OcrResult result) {
    final filled = kPassportFormFields.where((spec) {
      final edited = _controller.fieldEdits[spec.id];
      if (edited != null) {
        return edited.trim().isNotEmpty;
      }
      return (result.fields[spec.id]?.value ?? '').trim().isNotEmpty;
    }).length;
    return 'Заполнено $filled из ${kPassportFormFields.length}';
  }
}

class _PlaceholderStep extends StatelessWidget {
  const _PlaceholderStep({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock_outline, size: 36, color: AppColors.muted),
          const SizedBox(height: AppSpacing.md),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}
