import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ru_passport/crypto/crypto_exception.dart';
import 'package:ru_passport/crypto/encrypted_passport_payload.dart';
import 'package:ru_passport/crypto/passport_encryption_service.dart';
import 'package:ru_passport/crypto/passport_plaintext.dart';
import 'package:ru_passport/domain/parsed_field.dart';

import 'hybrid_decrypt.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late String testPublicPem;
  late String testPrivatePem;
  late String wrongPrivatePem;
  late String smallPublicPem;
  late String pkcs1PublicPem;

  setUpAll(() {
    testPublicPem = _fixture('test_public.pem');
    testPrivatePem = _fixture('test_private.pem');
    wrongPrivatePem = _fixture('test_wrong_private.pem');
    smallPublicPem = _fixture('test_public_2048.pem');
    pkcs1PublicPem = _fixture('test_public_pkcs1.pem');
  });

  PassportEncryptionService serviceWith(String pem) {
    return PassportEncryptionService(
      bundle: MemoryAssetBundle({kPassportPublicKeyAsset: pem}),
    );
  }

  PassportPlaintext samplePlaintext({
    Uint8List? firstSpread,
    Uint8List? registration,
    Uint8List? portrait,
    Uint8List? signature,
  }) {
    return PassportPlaintext(
      fields: {
        for (final spec in kPassportFormFields)
          spec.id: PassportFieldPair(
            original: spec.id == 'lastName' ? 'ИВАНОВ' : '',
            edited: spec.id == 'lastName' ? 'ПЕТРОВ' : '',
          ),
      },
      photos: [
        PhotoPlaintext(
          kind: PhotoKind.firstSpread,
          bytes: firstSpread ?? Uint8List.fromList(const [1, 2, 3]),
        ),
        PhotoPlaintext(
          kind: PhotoKind.registration,
          bytes: registration ?? Uint8List.fromList(const [4, 5]),
        ),
        PhotoPlaintext(
          kind: PhotoKind.portrait,
          bytes: portrait ?? Uint8List.fromList(const [6]),
        ),
        PhotoPlaintext(
          kind: PhotoKind.signature,
          bytes: signature ?? Uint8List(0),
        ),
      ],
    );
  }

  test('production public key asset loads and validates', () async {
    final service = PassportEncryptionService();
    await service.initialize();
  });

  test(
    'encrypt round-trip with test RSA pair restores fields and photos',
    () async {
      final plaintext = samplePlaintext();
      final payload = await serviceWith(testPublicPem).encrypt(plaintext);
      expect(payload.version, 1);
      expect(payload.keyAlgorithm, 'RSA-OAEP-SHA256');
      expect(payload.dataAlgorithm, 'AES-256-GCM');
      expect(payload.photos, hasLength(4));
      expect(payload.photos.map((item) => item.kind).toList(), [
        'firstSpread',
        'registration',
        'portrait',
        'signature',
      ]);

      final decrypted = await decryptPayload(
        payload: payload,
        privateKey: parseRsaPrivateKeyPem(testPrivatePem),
      );
      final json =
          jsonDecode(utf8.decode(decrypted.fieldsJson)) as Map<String, dynamic>;
      expect(json['fields']['lastName'], {
        'original': 'ИВАНОВ',
        'edited': 'ПЕТРОВ',
      });
      expect(json['fields']['registrationAddress'], {
        'original': '',
        'edited': '',
      });
      expect(decrypted.photos, hasLength(4));
      expect(decrypted.photos[0], Uint8List.fromList(const [1, 2, 3]));
      expect(decrypted.photos[1], Uint8List.fromList(const [4, 5]));
      expect(decrypted.photos[2], Uint8List.fromList(const [6]));
      expect(decrypted.photos[3], isEmpty);
    },
  );

  test(
    'repeated encrypt produces different ciphertext and unique nonces',
    () async {
      final plaintext = samplePlaintext();
      final service = serviceWith(testPublicPem);
      final first = await service.encrypt(plaintext);
      final second = await service.encrypt(plaintext);
      expect(first.encryptedKey, isNot(second.encryptedKey));
      expect(first.passport.ciphertext, isNot(second.passport.ciphertext));
      expect(first.passport.nonce, isNot(second.passport.nonce));

      final nonces = <String>{
        first.passport.nonce,
        for (final photo in first.photos) photo.nonce,
      };
      expect(nonces, hasLength(5));
    },
  );

  test('tampered ciphertext, tag or nonce fails decrypt', () async {
    final payload = await serviceWith(testPublicPem).encrypt(samplePlaintext());
    final privateKey = parseRsaPrivateKeyPem(testPrivatePem);
    final aesKey = rsaOaepSha256Decrypt(
      privateKey,
      base64Decode(payload.encryptedKey),
    );

    Future<void> expectDecryptFails(EncryptedBlob blob) {
      return expectLater(
        aesGcmDecrypt(aesKey: aesKey, blob: blob),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    }

    await expectDecryptFails(
      EncryptedBlob(
        ciphertext: _flipBase64Byte(payload.passport.ciphertext),
        nonce: payload.passport.nonce,
        tag: payload.passport.tag,
      ),
    );
    await expectDecryptFails(
      EncryptedBlob(
        ciphertext: payload.passport.ciphertext,
        nonce: payload.passport.nonce,
        tag: _flipBase64Byte(payload.passport.tag),
      ),
    );
    await expectDecryptFails(
      EncryptedBlob(
        ciphertext: payload.passport.ciphertext,
        nonce: _flipBase64Byte(payload.passport.nonce),
        tag: payload.passport.tag,
      ),
    );
  });

  test('foreign RSA private key does not unwrap the AES key', () async {
    final payload = await serviceWith(testPublicPem).encrypt(samplePlaintext());
    final wrongKey = parseRsaPrivateKeyPem(wrongPrivatePem);
    expect(
      () => rsaOaepSha256Decrypt(wrongKey, base64Decode(payload.encryptedKey)),
      throwsA(anything),
    );
  });

  test('missing public key asset is a controlled error', () async {
    final service = PassportEncryptionService(bundle: MemoryAssetBundle({}));
    await expectLater(service.initialize(), throwsA(isA<CryptoException>()));
  });

  test('broken public key PEM is a controlled error', () async {
    final service = serviceWith('not-a-pem');
    await expectLater(service.initialize(), throwsA(isA<CryptoException>()));
  });

  test('PKCS#1 RSA public key is rejected', () async {
    final service = serviceWith(pkcs1PublicPem);
    await expectLater(service.initialize(), throwsA(isA<CryptoException>()));
  });

  test('RSA modulus below 3072 bits is rejected', () async {
    final service = serviceWith(smallPublicPem);
    await expectLater(service.initialize(), throwsA(isA<CryptoException>()));
  });

  test(
    'empty photo slot stays in the payload and decrypts to empty bytes',
    () async {
      final plaintext = samplePlaintext(
        firstSpread: Uint8List(0),
        registration: Uint8List.fromList(const [9]),
        portrait: Uint8List(0),
        signature: Uint8List(0),
      );
      final payload = await serviceWith(testPublicPem).encrypt(plaintext);
      expect(payload.photos, hasLength(4));
      final decrypted = await decryptPayload(
        payload: payload,
        privateKey: parseRsaPrivateKeyPem(testPrivatePem),
      );
      expect(decrypted.photos[0], isEmpty);
      expect(decrypted.photos[1], Uint8List.fromList(const [9]));
      expect(decrypted.photos[2], isEmpty);
      expect(decrypted.photos[3], isEmpty);
    },
  );

  test(
    'large photo encrypts in isolate without unhandled crash',
    () async {
      final large = Uint8List(8 * 1024 * 1024);
      large[0] = 7;
      large[large.length - 1] = 11;
      final plaintext = samplePlaintext(firstSpread: large);
      final payload = await serviceWith(testPublicPem).encrypt(plaintext);
      final decrypted = await decryptPayload(
        payload: payload,
        privateKey: parseRsaPrivateKeyPem(testPrivatePem),
      );
      expect(decrypted.photos[0].length, large.length);
      expect(decrypted.photos[0].first, 7);
      expect(decrypted.photos[0].last, 11);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

String _fixture(String name) =>
    File('test/fixtures/crypto/$name').readAsStringSync();

String _flipBase64Byte(String encoded) {
  final bytes = base64Decode(encoded);
  bytes[0] = bytes[0] ^ 0x01;
  return base64Encode(bytes);
}

class MemoryAssetBundle extends CachingAssetBundle {
  MemoryAssetBundle(this._values);

  final Map<String, String> _values;

  @override
  Future<ByteData> load(String key) async {
    final value = _values[key];
    if (value == null) {
      throw FlutterError('Unable to load asset: $key');
    }
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(value)));
  }
}
