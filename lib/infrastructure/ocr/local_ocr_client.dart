import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:ru_passport/core/constants.dart';
import 'package:ru_passport/core/errors.dart';
import 'package:ru_passport/domain/ocr_result.dart';

class LocalOcrClient {
  LocalOcrClient({
    http.Client? httpClient,
    this.externalBaseUrl,
    this.externalToken,
  }) : _http = httpClient ?? http.Client();

  final http.Client _http;
  final String? externalBaseUrl;
  final String? externalToken;

  Process? _process;
  String _token = '';
  Uri _baseUri = Uri.parse(
    'http://${AppConstants.defaultHost}:${AppConstants.defaultPort}',
  );
  bool _started = false;

  String get token => _token;

  Uri get baseUri => _baseUri;

  Future<void> ensureStarted() async {
    if (_started) {
      await _waitHealthy();
      return;
    }
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
      await _waitHealthy();
      _started = true;
      return;
    }

    final python = await _pythonExecutable();
    _token = _generateToken();
    _baseUri = Uri(
      scheme: 'http',
      host: AppConstants.defaultHost,
      port: AppConstants.defaultPort,
    );
    _process = await Process.start(
      python,
      const ['-m', 'app'],
      workingDirectory: _pythonServiceDir().path,
      environment: {
        ...Platform.environment,
        'OCR_SESSION_TOKEN': _token,
        'OCR_API_HOST': AppConstants.defaultHost,
        'OCR_API_PORT': '${AppConstants.defaultPort}',
        'PYTHONUNBUFFERED': '1',
      },
    );
    _process!.stdout.listen((_) {});
    _process!.stderr.listen((_) {});
    try {
      await _waitHealthy();
    } catch (error) {
      await dispose();
      throw OcrException(
        'Python OCR-сервис не стал ready. $error',
        code: 'OCR_FAILED',
      );
    }
    _started = true;
  }

  Future<OcrResult> recognizeFile(String filePath, {String page = 'first_spread'}) async {
    await ensureStarted();
    final request = http.MultipartRequest('POST', _baseUri.resolve('/api/v1/recognize'))
      ..headers['Authorization'] = 'Bearer $_token'
      ..fields['page'] = page
      ..files.add(await http.MultipartFile.fromPath('image', filePath));
    final streamed = await _http.send(request).timeout(AppConstants.recognizeTimeout);
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
    final process = _process;
    _process = null;
    if (process != null) {
      process.kill();
      await process.exitCode.timeout(
        const Duration(seconds: 5),
        onTimeout: () => -1,
      );
    }
    _http.close();
  }

  Future<void> _waitHealthy() async {
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
          if (payload['status'] == 'ready') {
            return;
          }
        }
        lastError = 'HTTP ${response.statusCode}';
      } catch (error) {
        lastError = error;
      }
      await Future<void>.delayed(AppConstants.healthPollInterval);
    }
    throw OcrException(
      'Таймаут ожидания OCR-сервиса. $lastError',
      code: 'OCR_FAILED',
    );
  }

  Future<String> _pythonExecutable() async {
    final serviceDir = _pythonServiceDir();
    final candidates = [
      p.join(serviceDir.path, '.venv', 'bin', 'python'),
      p.join(serviceDir.path, '.venv', 'Scripts', 'python.exe'),
    ];
    for (final candidate in candidates) {
      if (File(candidate).existsSync()) {
        return candidate;
      }
    }
    throw const OcrException(
      'Не найден python_service/.venv. Выполните: cd python_service && uv sync --python 3.12',
    );
  }

  Directory _pythonServiceDir() {
    var dir = Directory.current;
    for (var i = 0; i < 8; i++) {
      final service = Directory(p.join(dir.path, 'python_service'));
      final pubspec = File(p.join(dir.path, 'pubspec.yaml'));
      if (service.existsSync() && pubspec.existsSync()) {
        return service;
      }
      dir = dir.parent;
    }
    throw const OcrException('Не найден каталог python_service рядом с pubspec.yaml.');
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
