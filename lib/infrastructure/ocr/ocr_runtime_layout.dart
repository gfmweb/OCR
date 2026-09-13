import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:ru_passport/core/errors.dart';

const kNactaHomeEnv = 'NACTA_HOME';

class OcrRuntimeLayout {
  const OcrRuntimeLayout({
    this.nactaHome,
    this.executablePath,
    this.currentDirectory,
  });

  factory OcrRuntimeLayout.platform() {
    return OcrRuntimeLayout(
      nactaHome: Platform.environment[kNactaHomeEnv],
      executablePath: Platform.resolvedExecutable,
      currentDirectory: Directory.current,
    );
  }

  final String? nactaHome;
  final String? executablePath;
  final Directory? currentDirectory;

  Directory pythonServiceDir() {
    final home = nactaHome?.trim();
    if (home != null && home.isNotEmpty) {
      final bundled = Directory(p.join(home, 'python_service'));
      if (bundled.existsSync()) {
        return bundled;
      }
    }

    final executable = executablePath;
    if (executable != null && executable.isNotEmpty) {
      final bundleRoot = Directory(p.dirname(executable));
      final bundled = Directory(p.join(bundleRoot.path, 'python_service'));
      if (_hasVenv(bundled)) {
        return bundled;
      }
    }

    var dir = currentDirectory ?? Directory.current;
    for (var i = 0; i < 8; i++) {
      final service = Directory(p.join(dir.path, 'python_service'));
      final pubspec = File(p.join(dir.path, 'pubspec.yaml'));
      if (service.existsSync() && pubspec.existsSync()) {
        return service;
      }
      dir = dir.parent;
    }
    throw const OcrException('Не найден каталог python_service.');
  }

  String pythonExecutable() {
    final serviceDir = pythonServiceDir();
    final candidates = [
      p.join(serviceDir.path, '.venv', 'bin', 'python'),
      p.join(serviceDir.path, '.venv', 'Scripts', 'python.exe'),
    ];
    for (final candidate in candidates) {
      if (File(candidate).existsSync()) {
        return candidate;
      }
    }
    if (_isBundledLayout(serviceDir)) {
      throw const OcrException(
        'Не найден встроенный Python OCR. Переустановите пакет nacta-passport.',
      );
    }
    throw const OcrException(
      'Не найден python_service/.venv. Выполните: cd python_service && uv sync --python 3.12',
    );
  }

  bool _isBundledLayout(Directory serviceDir) {
    final home = nactaHome?.trim();
    if (home != null && home.isNotEmpty) {
      return p.equals(serviceDir.path, p.join(home, 'python_service'));
    }
    final executable = executablePath;
    if (executable == null || executable.isEmpty) {
      return false;
    }
    return p.equals(
      serviceDir.path,
      p.join(p.dirname(executable), 'python_service'),
    );
  }

  static bool _hasVenv(Directory service) {
    return File(p.join(service.path, '.venv', 'bin', 'python')).existsSync() ||
        File(
          p.join(service.path, '.venv', 'Scripts', 'python.exe'),
        ).existsSync();
  }
}
