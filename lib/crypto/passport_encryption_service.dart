import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pointycastle/api.dart';
import 'package:pointycastle/asymmetric/api.dart';
import 'package:pointycastle/asymmetric/oaep.dart';
import 'package:pointycastle/asymmetric/rsa.dart';
import 'package:ru_passport/crypto/crypto_exception.dart';
import 'package:ru_passport/crypto/encrypted_passport_payload.dart';
import 'package:ru_passport/crypto/passport_plaintext.dart';
import 'package:ru_passport/crypto/rsa_pem.dart';

const kPassportPublicKeyAsset = 'assets/crypto/passport_public.pem';
const kPassportPayloadVersion = 1;
const kKeyAlgorithm = 'RSA-OAEP-SHA256';
const kDataAlgorithm = 'AES-256-GCM';
const _aesGcmNonceLength = 12;

class PassportEncryptionService {
  PassportEncryptionService({
    AssetBundle? bundle,
    this.assetPath = kPassportPublicKeyAsset,
  }) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;
  final String assetPath;

  String? _publicKeyPem;

  Future<void> initialize() async {
    if (_publicKeyPem != null) {
      return;
    }
    final String pem;
    try {
      pem = await _bundle.loadString(assetPath);
    } catch (_) {
      throw const CryptoException('Публичный ключ недоступен.');
    }
    parseAndValidateRsaPublicKey(pem);
    _publicKeyPem = pem;
  }

  Future<EncryptedPassportPayload> encrypt(PassportPlaintext plaintext) async {
    await initialize();
    if (plaintext.photos.length != PhotoKind.documentOrder.length) {
      throw const CryptoException('Не удалось зашифровать документ.');
    }
    for (var i = 0; i < PhotoKind.documentOrder.length; i++) {
      if (plaintext.photos[i].kind != PhotoKind.documentOrder[i]) {
        throw const CryptoException('Не удалось зашифровать документ.');
      }
    }
    final pem = _publicKeyPem;
    if (pem == null) {
      throw const CryptoException('Публичный ключ недоступен.');
    }
    final fieldsJson = Uint8List.fromList(
      utf8.encode(jsonEncode(plaintext.toFieldsJson())),
    );
    final args = <String, Object?>{
      'pem': pem,
      'fieldsJson': fieldsJson,
      'photos': [for (final photo in plaintext.photos) photo.bytes],
      'kinds': [for (final photo in plaintext.photos) photo.kind.name],
    };
    final Map<dynamic, dynamic> raw;
    try {
      raw = await compute(_encryptInIsolate, args);
    } catch (_) {
      throw const CryptoException('Не удалось зашифровать документ.');
    }
    final error = raw['error'];
    if (error is String && error.isNotEmpty) {
      throw CryptoException(error);
    }
    return EncryptedPassportPayload.fromJson(raw);
  }
}

Future<Map<String, dynamic>> _encryptInIsolate(
  Map<String, Object?> args,
) async {
  try {
    return await _encryptDocument(args);
  } on CryptoException catch (error) {
    return {'error': error.message};
  } catch (_) {
    return {'error': 'Не удалось зашифровать документ.'};
  }
}

Future<Map<String, dynamic>> _encryptDocument(Map<String, Object?> args) async {
  final pem = args['pem'];
  final fieldsJson = args['fieldsJson'];
  final photosRaw = args['photos'];
  final kindsRaw = args['kinds'];
  if (pem is! String ||
      fieldsJson is! Uint8List ||
      photosRaw is! List ||
      kindsRaw is! List) {
    throw const CryptoException('Не удалось зашифровать документ.');
  }
  final publicKey = parseAndValidateRsaPublicKey(pem);
  final photos = photosRaw.whereType<Uint8List>().toList();
  final kinds = kindsRaw.whereType<String>().toList();
  if (photos.length != PhotoKind.documentOrder.length ||
      kinds.length != photos.length) {
    throw const CryptoException('Не удалось зашифровать документ.');
  }

  final algorithm = AesGcm.with256bits();
  final secretKey = await algorithm.newSecretKey();
  try {
    final keyBytes = Uint8List.fromList(await secretKey.extractBytes());
    try {
      final encryptedKey = _rsaOaepSha256Encrypt(publicKey, keyBytes);
      final passport = await _aesGcmEncrypt(algorithm, secretKey, fieldsJson);
      final photosOut = <Map<String, String>>[];
      for (var i = 0; i < photos.length; i++) {
        final blob = await _aesGcmEncrypt(algorithm, secretKey, photos[i]);
        photosOut.add({
          'kind': kinds[i],
          'ciphertext': blob['ciphertext']!,
          'nonce': blob['nonce']!,
          'tag': blob['tag']!,
        });
      }
      return {
        'version': kPassportPayloadVersion,
        'key_algorithm': kKeyAlgorithm,
        'data_algorithm': kDataAlgorithm,
        'encrypted_key': base64Encode(encryptedKey),
        'passport': passport,
        'photos': photosOut,
      };
    } finally {
      keyBytes.fillRange(0, keyBytes.length, 0);
    }
  } finally {
    secretKey.destroy();
  }
}

Future<Map<String, String>> _aesGcmEncrypt(
  AesGcm algorithm,
  SecretKey secretKey,
  List<int> plaintext,
) async {
  final nonce = algorithm.newNonce();
  if (nonce.length != _aesGcmNonceLength) {
    throw const CryptoException('Не удалось зашифровать документ.');
  }
  final box = await algorithm.encrypt(
    plaintext,
    secretKey: secretKey,
    nonce: nonce,
  );
  return {
    'ciphertext': base64Encode(box.cipherText),
    'nonce': base64Encode(box.nonce),
    'tag': base64Encode(box.mac.bytes),
  };
}

Uint8List _rsaOaepSha256Encrypt(RSAPublicKey publicKey, Uint8List message) {
  final cipher = OAEPEncoding.withSHA256(RSAEngine());
  cipher.init(true, PublicKeyParameter<RSAPublicKey>(publicKey));
  return cipher.process(message);
}
