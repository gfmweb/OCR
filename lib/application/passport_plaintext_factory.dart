import 'dart:io';
import 'dart:typed_data';

import 'package:ru_passport/crypto/crypto_exception.dart';
import 'package:ru_passport/crypto/passport_plaintext.dart';
import 'package:ru_passport/domain/parsed_field.dart';

typedef PathBytesReader = Future<Uint8List> Function(String path);

class PassportPlaintextFactory {
  const PassportPlaintextFactory({this.readPathBytes});

  final PathBytesReader? readPathBytes;

  Future<PassportPlaintext> fromSources({
    required Map<String, String> originals,
    required Map<String, String> edits,
    String? firstSpreadPath,
    String? registrationPath,
    Uint8List? portraitBytes,
    Uint8List? signatureBytes,
  }) async {
    final fields = <String, PassportFieldPair>{
      for (final spec in kPassportFormFields)
        spec.id: PassportFieldPair(
          original: originals[spec.id] ?? '',
          edited: edits[spec.id] ?? '',
        ),
    };
    final photos = <PhotoPlaintext>[
      PhotoPlaintext(
        kind: PhotoKind.firstSpread,
        bytes: await _readOptionalPath(firstSpreadPath),
      ),
      PhotoPlaintext(
        kind: PhotoKind.registration,
        bytes: await _readOptionalPath(registrationPath),
      ),
      PhotoPlaintext(kind: PhotoKind.portrait, bytes: _orEmpty(portraitBytes)),
      PhotoPlaintext(
        kind: PhotoKind.signature,
        bytes: _orEmpty(signatureBytes),
      ),
    ];
    return PassportPlaintext(fields: fields, photos: photos);
  }

  Future<Uint8List> _readOptionalPath(String? path) async {
    if (path == null || path.isEmpty) {
      return Uint8List(0);
    }
    try {
      final reader = readPathBytes ?? _readFileBytes;
      return await reader(path);
    } catch (_) {
      throw const CryptoException(
        'Не удалось прочитать изображение документа.',
      );
    }
  }

  static Future<Uint8List> _readFileBytes(String path) {
    return File(path).readAsBytes();
  }

  static Uint8List _orEmpty(Uint8List? bytes) => bytes ?? Uint8List(0);
}
