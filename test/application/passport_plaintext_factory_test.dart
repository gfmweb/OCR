import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ru_passport/application/passport_plaintext_factory.dart';
import 'package:ru_passport/crypto/passport_plaintext.dart';
import 'package:ru_passport/domain/parsed_field.dart';

void main() {
  test('factory maps originals, edits and four photo slots in order', () async {
    final factory = PassportPlaintextFactory(
      readPathBytes: (path) async {
        if (path == '/tmp/spread.jpg') {
          return Uint8List.fromList(const [1, 2]);
        }
        if (path == '/tmp/reg.jpg') {
          return Uint8List.fromList(const [3]);
        }
        return Uint8List(0);
      },
    );

    final plaintext = await factory.fromSources(
      originals: {'lastName': 'ИВАНОВ', 'registrationAddress': 'Г. МОСКВА'},
      edits: {'lastName': 'ПЕТРОВ', 'registrationAddress': 'Г. КАЗАНЬ'},
      firstSpreadPath: '/tmp/spread.jpg',
      registrationPath: '/tmp/reg.jpg',
      portraitBytes: Uint8List.fromList(const [10, 11]),
      signatureBytes: Uint8List.fromList(const [12]),
    );
    expect(plaintext.fields['lastName']?.original, 'ИВАНОВ');
    expect(plaintext.fields['lastName']?.edited, 'ПЕТРОВ');
    expect(plaintext.fields['registrationAddress']?.original, 'Г. МОСКВА');
    expect(plaintext.fields['registrationAddress']?.edited, 'Г. КАЗАНЬ');
    expect(plaintext.fields.keys, kPassportFormFields.map((spec) => spec.id));
    expect(plaintext.photos.map((item) => item.kind), PhotoKind.documentOrder);
    expect(plaintext.photos[0].bytes, Uint8List.fromList(const [1, 2]));
    expect(plaintext.photos[1].bytes, Uint8List.fromList(const [3]));
    expect(plaintext.photos[2].bytes, Uint8List.fromList(const [10, 11]));
    expect(plaintext.photos[3].bytes, Uint8List.fromList(const [12]));
  });

  test('factory uses empty bytes for missing photos', () async {
    final plaintext = await const PassportPlaintextFactory().fromSources(
      originals: const {},
      edits: const {},
    );
    expect(plaintext.photos, hasLength(4));
    for (final photo in plaintext.photos) {
      expect(photo.bytes, isEmpty);
    }
  });
}
