import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:ru_passport/infrastructure/ocr/local_ocr_client.dart';

void main() {
  test('dispose posts shutdown then SIGKILLs a stuck process', () async {
    final httpClient = _RecordingClient();
    final process = _FakeProcess();
    final client = LocalOcrClient(
      httpClient: httpClient,
      shutdownWait: const Duration(milliseconds: 40),
      killWait: const Duration(milliseconds: 40),
    );
    client.debugAttachOwnedProcess(
      process: process,
      baseUri: Uri.parse('http://127.0.0.1:8765'),
      token: 'test-token',
    );

    await client.dispose();

    expect(httpClient.paths, contains('/shutdown'));
    expect(process.lastSignal, ProcessSignal.sigkill);
    expect(process.killCount, 1);
  });

  test('dispose waits for exit and does not SIGKILL', () async {
    final httpClient = _RecordingClient();
    final process = _FakeProcess()..complete(0);
    final client = LocalOcrClient(
      httpClient: httpClient,
      shutdownWait: const Duration(seconds: 2),
    );
    client.debugAttachOwnedProcess(
      process: process,
      baseUri: Uri.parse('http://127.0.0.1:8765'),
      token: 'test-token',
    );

    await client.dispose();

    expect(httpClient.paths, contains('/shutdown'));
    expect(process.killCount, 0);
  });
}

class _RecordingClient extends http.BaseClient {
  final List<String> paths = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    paths.add(request.url.path);
    final body = utf8.encode('{"status":"shutting_down"}');
    return http.StreamedResponse(
      Stream<List<int>>.value(body),
      200,
      headers: {'content-type': 'application/json'},
    );
  }
}

class _FakeProcess implements Process {
  _FakeProcess();

  final Completer<int> _exit = Completer<int>();
  ProcessSignal? lastSignal;
  int killCount = 0;

  void complete(int code) {
    if (!_exit.isCompleted) {
      _exit.complete(code);
    }
  }

  @override
  Future<int> get exitCode => _exit.future;

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    lastSignal = signal;
    killCount += 1;
    if (!_exit.isCompleted) {
      _exit.complete(signal == ProcessSignal.sigkill ? -9 : 0);
    }
    return true;
  }

  @override
  int get pid => 4242;

  @override
  IOSink get stdin => throw UnimplementedError();

  @override
  Stream<List<int>> get stdout => const Stream.empty();

  @override
  Stream<List<int>> get stderr => const Stream.empty();
}
