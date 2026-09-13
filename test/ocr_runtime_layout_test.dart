import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:ru_passport/core/errors.dart';
import 'package:ru_passport/infrastructure/ocr/ocr_runtime_layout.dart';

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('nacta-ocr-layout-');
  });

  tearDown(() {
    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
  });

  test('prefers NACTA_HOME over the repository walk', () {
    final bundled = Directory(
      p.join(root.path, 'opt', 'nacta-passport', 'python_service'),
    )..createSync(recursive: true);
    File(
      p.join(bundled.path, '.venv', 'bin', 'python'),
    ).createSync(recursive: true);

    final repo = Directory(p.join(root.path, 'repo'))..createSync();
    File(
      p.join(repo.path, 'pubspec.yaml'),
    ).writeAsStringSync('name: ru_passport\n');
    Directory(
      p.join(repo.path, 'python_service', '.venv', 'bin'),
    ).createSync(recursive: true);
    File(
      p.join(repo.path, 'python_service', '.venv', 'bin', 'python'),
    ).createSync();

    final layout = OcrRuntimeLayout(
      nactaHome: p.join(root.path, 'opt', 'nacta-passport'),
      executablePath: p.join(root.path, 'somewhere', 'ru_passport'),
      currentDirectory: repo,
    );
    expect(layout.pythonServiceDir().path, bundled.path);
    expect(
      layout.pythonExecutable(),
      p.join(bundled.path, '.venv', 'bin', 'python'),
    );
  });

  test('uses python_service next to the executable when venv exists', () {
    final bundle = Directory(p.join(root.path, 'bundle'))..createSync();
    final service = Directory(
      p.join(bundle.path, 'python_service', '.venv', 'bin'),
    )..createSync(recursive: true);
    File(p.join(service.path, 'python')).createSync();

    final layout = OcrRuntimeLayout(
      executablePath: p.join(bundle.path, 'ru_passport'),
      currentDirectory: Directory(p.join(root.path, 'empty'))..createSync(),
    );
    expect(
      layout.pythonServiceDir().path,
      p.join(bundle.path, 'python_service'),
    );
  });

  test('falls back to pubspec.yaml plus python_service for flutter run', () {
    final repo = Directory(p.join(root.path, 'project'))..createSync();
    File(
      p.join(repo.path, 'pubspec.yaml'),
    ).writeAsStringSync('name: ru_passport\n');
    Directory(p.join(repo.path, 'python_service')).createSync();
    File(
      p.join(repo.path, 'python_service', '.venv', 'bin', 'python'),
    ).createSync(recursive: true);

    final layout = OcrRuntimeLayout(
      currentDirectory: Directory(p.join(repo.path, 'lib'))..createSync(),
    );
    expect(layout.pythonServiceDir().path, p.join(repo.path, 'python_service'));
  });

  test('uses Windows venv next to the executable', () {
    final bundle = Directory(p.join(root.path, 'win-bundle'))..createSync();
    File(
      p.join(bundle.path, 'python_service', '.venv', 'Scripts', 'python.exe'),
    ).createSync(recursive: true);

    final layout = OcrRuntimeLayout(
      executablePath: p.join(bundle.path, 'ru_passport.exe'),
      currentDirectory: Directory(p.join(root.path, 'empty-win'))..createSync(),
    );
    expect(
      layout.pythonServiceDir().path,
      p.join(bundle.path, 'python_service'),
    );
    expect(
      layout.pythonExecutable(),
      p.join(bundle.path, 'python_service', '.venv', 'Scripts', 'python.exe'),
    );
  });

  test('NACTA_HOME prefers Windows venv python.exe', () {
    final home = Directory(p.join(root.path, 'nacta-home'))..createSync();
    File(
      p.join(home.path, 'python_service', '.venv', 'Scripts', 'python.exe'),
    ).createSync(recursive: true);

    final layout = OcrRuntimeLayout(
      nactaHome: home.path,
      executablePath: p.join(root.path, 'elsewhere', 'ru_passport.exe'),
      currentDirectory: Directory(p.join(root.path, 'empty-home'))..createSync(),
    );
    expect(
      layout.pythonExecutable(),
      p.join(home.path, 'python_service', '.venv', 'Scripts', 'python.exe'),
    );
  });

  test('bundled layout without venv asks to reinstall the package', () {
    Directory(
      p.join(root.path, 'opt', 'nacta-passport', 'python_service'),
    ).createSync(recursive: true);
    final layout = OcrRuntimeLayout(
      nactaHome: p.join(root.path, 'opt', 'nacta-passport'),
      currentDirectory: Directory(p.join(root.path, 'empty'))..createSync(),
    );
    expect(() => layout.pythonExecutable(), throwsA(isA<OcrException>()));
  });
}
