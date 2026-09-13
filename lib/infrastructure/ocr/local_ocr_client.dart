import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:ru_passport/core/constants.dart';
import 'package:ru_passport/core/errors.dart';
import 'package:ru_passport/domain/ocr_result.dart';
import 'package:ru_passport/infrastructure/ocr/ocr_runtime_layout.dart';
import 'package:ru_passport/infrastructure/ocr/ocr_service_status.dart';

typedef OcrStatusCallback = void Function(OcrServiceStatus status);

class LocalOcrClient {
  LocalOcrClient({
    http.Client? httpClient,
    this.externalBaseUrl,
    this.externalToken,
    this.shutdownWait = const Duration(seconds: 8),
    this.killWait = const Duration(seconds: 2),
  }) : _http = httpClient ?? http.Client();

  final http.Client _http;
  final String? externalBaseUrl;
  final String? externalToken;
  final Duration shutdownWait;
  final Duration killWait;

  Process? _process;
  String _token = '';
  Uri _baseUri = Uri.parse(
    'http://${AppConstants.defaultHost}:${AppConstants.defaultPort}',
  );
  bool _started = false;
  bool _httpClosed = false;
  bool _ownsProcess = false;

  String get token => _token;

  Uri get baseUri => _baseUri;

  @visibleForTesting
  void debugAttachOwnedProcess({
    required Process process,
    required Uri baseUri,
    required String token,
  }) {
    _process = process;
    _ownsProcess = true;
    _baseUri = baseUri;
    _token = token;
    _started = true;
  }

  Future<void> ensureStarted({OcrStatusCallback? onStatus}) async {
    if (_started) {
      await _waitHealthy(onStatus: onStatus);
      return;
    }
    onStatus?.call(
      const OcrServiceStatus(
        stage: 'starting_server',
        progress: 10,
        ready: false,
      ),
    );
    final envUrl = externalBaseUrl ?? Platform.environment['OCR_SERVICE_URL'];
    final envToken = externalToken ?? Platform.environment['OCR_SESSION_TOKEN'];
    if (envUrl != null && envUrl.isNotEmpty) {
      _baseUri = Uri.parse(envUrl);
      _token = envToken ?? '';
      if (_token.isEmpty) {
        throw const OcrException(
          'Задан OCR_SERVICE_URL, но нет OCR_SESSION_TOKEN.',
        );
      }
      await _waitHealthy(onStatus: onStatus);
      _started = true;
      return;
    }

    final layout = OcrRuntimeLayout.platform();
    final python = layout.pythonExecutable();
    _token = _generateToken();
    _baseUri = Uri(
      scheme: 'http',
      host: AppConstants.defaultHost,
      port: AppConstants.defaultPort,
    );
    _process = await Process.start(
      python,
      const ['-m', 'app'],
      workingDirectory: layout.pythonServiceDir().path,
      environment: {
        ...Platform.environment,
        'OCR_SESSION_TOKEN': _token,
        'OCR_API_HOST': AppConstants.defaultHost,
        'OCR_API_PORT': '${AppConstants.defaultPort}',
        'PYTHONUNBUFFERED': '1',
      },
    );
    _ownsProcess = true;
    _process!.stdout.listen((_) {});
    _process!.stderr.listen((_) {});
    try {
      await _waitHealthy(onStatus: onStatus);
    } catch (error) {
      await dispose();
      throw OcrException(
        'Python OCR-сервис не стал ready. $error',
        code: 'OCR_FAILED',
      );
    }
    _started = true;
  }

  Future<OcrResult> recognizeFile(
    String filePath, {
    String page = 'first_spread',
  }) async {
    await ensureStarted();
    final request =
        http.MultipartRequest('POST', _baseUri.resolve('/api/v1/recognize'))
          ..headers['Authorization'] = 'Bearer $_token'
          ..fields['page'] = page
          ..files.add(await http.MultipartFile.fromPath('image', filePath));
    final streamed = await _http
        .send(request)
        .timeout(AppConstants.recognizeTimeout);
    final body = await streamed.stream.bytesToString();
    if (streamed.statusCode != 200) {
      throw OcrException(
        _errorMessage(body),
        code: _errorCode(body) ?? 'OCR_FAILED',
      );
    }
    return OcrResult.fromJson(jsonDecode(body) as Map<String, dynamic>);
  }

  Future<void> dispose() async {
    _started = false;
    await _requestShutdown();
    final process = _process;
    _process = null;
    if (_ownsProcess && process != null) {
      try {
        await process.exitCode.timeout(shutdownWait);
      } on TimeoutException {
        process.kill(ProcessSignal.sigkill);
        await process.exitCode.timeout(killWait, onTimeout: () => -1);
      }
    }
    _ownsProcess = false;
    if (!_httpClosed) {
      _http.close();
      _httpClosed = true;
    }
  }

  Future<void> _requestShutdown() async {
    if (_httpClosed || _token.isEmpty) {
      return;
    }
    try {
      await _http
          .post(
            _baseUri.resolve('/shutdown'),
            headers: {'Authorization': 'Bearer $_token'},
          )
          .timeout(const Duration(seconds: 2));
    } catch (_) {}
  }

  Future<void> _waitHealthy({OcrStatusCallback? onStatus}) async {
    final deadline = DateTime.now().add(AppConstants.serviceReadyTimeout);
    Object? lastError;
    while (DateTime.now().isBefore(deadline)) {
      try {
        final response = await _http
            .get(
              _baseUri.resolve('/health'),
              headers: {'Authorization': 'Bearer $_token'},
            )
            .timeout(const Duration(seconds: 2));
        if (response.statusCode == 200) {
          final payload = jsonDecode(response.body) as Map<String, dynamic>;
          final status = payload['status'] as String? ?? '';
          final stage = payload['stage'] as String? ?? 'starting_server';
          final progress = (payload['progress'] as num?)?.toInt() ?? 15;
          onStatus?.call(
            OcrServiceStatus(
              stage: stage,
              progress: progress.clamp(0, 100),
              ready: status == 'ready',
            ),
          );
          if (status == 'ready') {
            return;
          }
          if (status == 'error') {
            throw const OcrException('Не удалось загрузить модели OCR.');
          }
        }
        lastError = 'HTTP ${response.statusCode}';
      } catch (error) {
        if (error is OcrException) {
          rethrow;
        }
        lastError = error;
      }
      await Future<void>.delayed(AppConstants.healthPollInterval);
    }
    throw OcrException(
      'Таймаут ожидания OCR-сервиса. $lastError',
      code: 'OCR_FAILED',
    );
  }

  String _generateToken() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  String _errorMessage(String body) {
    final code = _errorCode(body);
    return switch (code) {
      'IMAGE_DECODE_FAILED' => 'Не удалось прочитать изображение.',
      'IMAGE_TOO_LARGE' => 'Изображение слишком большое.',
      'SERVICE_STARTING' => 'Модели OCR ещё загружаются.',
      'OCR_FAILED' => 'Не удалось распознать текст.',
      _ => 'Не удалось распознать текст.',
    };
  }

  String? _errorCode(String body) {
    try {
      final payload = jsonDecode(body);
      if (payload is Map<String, dynamic>) {
        final detail = payload['detail'];
        if (detail is Map<String, dynamic>) {
          return detail['error_code'] as String?;
        }
      }
    } catch (_) {}
    return null;
  }
}
