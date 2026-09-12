import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:ru_passport/application/recognition_controller.dart';
import 'package:ru_passport/core/constants.dart';
import 'package:ru_passport/domain/ocr_result.dart';
import 'package:ru_passport/domain/parsed_field.dart';
import 'package:ru_passport/domain/passport_number.dart';
import 'package:ru_passport/presentation/widgets/image_drop_zone.dart';
import 'package:ru_passport/presentation/widgets/ocr_overlay.dart';

class PassportApp extends StatelessWidget {
  const PassportApp({super.key, this.controller});

  final RecognitionController? controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appTitle,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1F4E79),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
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
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'bmp', 'tif', 'tiff'],
    );
    return picked?.files.single.path;
  }

  Future<void> _pickFile() async {
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
    return Scaffold(
      appBar: AppBar(title: const Text(AppConstants.appTitle)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(flex: 3, child: _preview()),
            const SizedBox(width: 16),
            Expanded(flex: 2, child: _sidePanel()),
          ],
        ),
      ),
    );
  }

  Widget _preview() {
    final path = _controller.imagePath;
    final result = _controller.result;
    if (path == null) {
      return ImageDropZone(onPath: _controller.recognize, onPickFile: _pickFile);
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD0D7DE)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: result == null
            ? Image.file(File(path), fit: BoxFit.contain)
            : OcrOverlay(
                imageFile: File(path),
                imageSize: Size(
                  result.imageWidth.toDouble(),
                  result.imageHeight.toDouble(),
                ),
                lines: const [],
                rotationDegrees: 0,
              ),
      ),
    );
  }

  Widget _sidePanel() {
    final result = _controller.result;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _progressCard(),
        const SizedBox(height: 12),
        if (_controller.phase == RecognitionPhase.error)
          Card(
            color: const Color(0xFFFFF1F0),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(_controller.errorMessage ?? 'Ошибка'),
            ),
          ),
        if (result != null) Expanded(child: _digitalCopy(result)),
        if (result == null) const Spacer(),
        if (_controller.result?.view == 'first_spread' && _controller.result?.errorCode == null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: FilledButton(
              onPressed: _controller.canAddRegistration ? _pickRegistration : null,
              child: const Text('Добавить страницу регистрации'),
            ),
          ),
        OutlinedButton(
          onPressed: _pickFile,
          child: const Text('Попробовать другое изображение'),
        ),
        const SizedBox(height: 8),
        FilledButton.tonal(onPressed: _pickFile, child: const Text('Выбрать файл')),
      ],
    );
  }

  Widget _digitalCopy(OcrResult result) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (result.errorCode == 'NOT_FIRST_SPREAD' ||
                result.errorCode == 'NOT_RUSSIAN_PASSPORT')
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'Это не первый разворот внутреннего паспорта РФ.',
                  style: TextStyle(color: Color(0xFFCF222E)),
                ),
              ),
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('Цифровая копия', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            if (result.view == 'first_spread' && result.errorCode == null) _identityImages(result),
            if (_controller.registrationError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _controller.registrationError!,
                  style: const TextStyle(color: Color(0xFFCF222E)),
                ),
              ),
            if (_controller.numberMatch != PassportNumberMatch.none) _numberMatchBanner(),
            if (_isRegistrationAddressMissing)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'Адрес прописки не распознан.',
                  style: TextStyle(color: Color(0xFFCF222E)),
                ),
              ),
            for (final spec in kPassportFormFields) _fieldEditor(spec, result),
          ],
        ),
      ),
    );
  }

  Widget _fieldEditor(PassportFormSpec spec, OcrResult result) {
    final field = result.fields[spec.id];
    final lowConfidence = (field?.confidence ?? 0) > 0 && (field?.confidence ?? 0) < kLowFieldConfidence;
    final text =
        _controller.fieldEdits[spec.id] ?? displayFieldValue(spec.id, field?.value);
    final multiline = spec.id == 'registrationAddress';
    final missing = _isUnrecognized(spec, text);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextFormField(
        key: ValueKey('${result.requestId}-${spec.id}-$text'),
        initialValue: text,
        maxLines: multiline ? 4 : 1,
        decoration: InputDecoration(
          labelText: spec.label,
          isDense: true,
          filled: missing,
          fillColor: missing ? const Color(0xFFFFF1F0) : null,
          enabledBorder: missing
              ? const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFCF222E)))
              : null,
          focusedBorder: missing
              ? const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFCF222E), width: 2))
              : null,
          suffixIcon: lowConfidence
              ? const Icon(Icons.warning_amber_rounded, color: Color(0xFF9A6700))
              : null,
        ),
        onChanged: (value) => _controller.updateField(spec.id, value),
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
    if (spec.id == 'registrationAddress' && _controller.registrationResult == null) {
      return false;
    }
    return text.trim().isEmpty;
  }

  Widget _identityImages(OcrResult result) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Wrap(
        spacing: 16,
        runSpacing: 12,
        children: [
          _imageChip(
            bytes: result.photoBytes,
            emptyLabel: 'Фото не найдено',
            foundLabel: 'Фотография',
            icon: Icons.person_outline,
          ),
          _imageChip(
            bytes: result.signatureBytes,
            emptyLabel: 'Подпись не найдена',
            foundLabel: 'Подпись',
            icon: Icons.draw_outlined,
            width: 120,
            height: 56,
          ),
        ],
      ),
    );
  }

  Widget _imageChip({
    required Uint8List? bytes,
    required String emptyLabel,
    required String foundLabel,
    required IconData icon,
    double width = 72,
    double height = 96,
  }) {
    final missing = bytes == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: missing ? Border.all(color: const Color(0xFFCF222E)) : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: missing
                ? Container(
                    width: width,
                    height: height,
                    color: const Color(0xFFFFF1F0),
                    child: Icon(icon, color: const Color(0xFFCF222E)),
                  )
                : Image.memory(bytes, width: width, height: height, fit: BoxFit.contain),
          ),
        ),
        const SizedBox(height: 4),
        Text(missing ? emptyLabel : foundLabel),
      ],
    );
  }

  Widget _numberMatchBanner() {
    final (text, color) = switch (_controller.numberMatch) {
      PassportNumberMatch.match => (
        'Номер совпадает с первым разворотом',
        const Color(0xFF1A7F37),
      ),
      PassportNumberMatch.mismatch => (
        'Номер на странице регистрации не совпадает',
        const Color(0xFFCF222E),
      ),
      PassportNumberMatch.missing => (
        'Не удалось сверить номер паспорта на странице регистрации',
        const Color(0xFF9A6700),
      ),
      PassportNumberMatch.none => ('', const Color(0xFF57606A)),
    };
    if (text.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(text, style: TextStyle(color: color)),
    );
  }

  Widget _progressCard() {
    final phases = <RecognitionPhase, String>{
      RecognitionPhase.startingService: 'Запуск сервиса',
      RecognitionPhase.preparingImage: 'Подготовка изображения',
      RecognitionPhase.ocr: 'Распознавание',
      RecognitionPhase.ready: 'Готово',
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_controller.statusLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            for (final entry in phases.entries)
              _stageRow(entry.value, _stageState(entry.key)),
            if (_controller.result != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _resultSummary(_controller.result!),
                  style: const TextStyle(color: Color(0xFF57606A)),
                ),
              ),
          ],
        ),
      ),
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

  _StageState _stageState(RecognitionPhase stage) {
    const order = [
      RecognitionPhase.startingService,
      RecognitionPhase.preparingImage,
      RecognitionPhase.ocr,
      RecognitionPhase.ready,
    ];
    final current = order.indexOf(_controller.phase);
    final target = order.indexOf(stage);
    if (_controller.phase == RecognitionPhase.idle) {
      return _StageState.pending;
    }
    if (_controller.phase == RecognitionPhase.error) {
      return target <= current ? _StageState.error : _StageState.pending;
    }
    if (current < 0) {
      return _StageState.pending;
    }
    if (target < current) {
      return _StageState.done;
    }
    if (target == current) {
      return _StageState.active;
    }
    return _StageState.pending;
  }

  Widget _stageRow(String label, _StageState state) {
    final icon = switch (state) {
      _StageState.done => Icons.check_circle,
      _StageState.active => Icons.autorenew,
      _StageState.error => Icons.error_outline,
      _StageState.pending => Icons.radio_button_unchecked,
    };
    final color = switch (state) {
      _StageState.done => Colors.green.shade700,
      _StageState.active => Theme.of(context).colorScheme.primary,
      _StageState.error => Colors.red.shade700,
      _StageState.pending => const Color(0xFF8C959F),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: color)),
        ],
      ),
    );
  }
}

enum _StageState { pending, active, done, error }
