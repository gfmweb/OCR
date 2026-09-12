import 'dart:typed_data';

import 'package:pointycastle/asn1.dart';
import 'package:pointycastle/asymmetric/api.dart';
import 'package:ru_passport/crypto/crypto_exception.dart';

const kRsaEncryptionOid = '1.2.840.113549.1.1.1';
const kMinRsaModulusBits = 3072;

bool _hasSpkiPublicKeyHeader(String pem) {
  return pem.contains('BEGIN PUBLIC KEY') &&
      !pem.contains('BEGIN RSA PUBLIC KEY');
}

RSAPublicKey parseAndValidateRsaPublicKey(String pem) {
  final normalized = pem.trim();
  if (!_hasSpkiPublicKeyHeader(normalized)) {
    throw const CryptoException(
      'Публичный ключ должен быть RSA типа PUBLIC KEY.',
    );
  }
  try {
    final der = ASN1Utils.getBytesFromPEMString(normalized);
    final top = ASN1Parser(der).nextObject();
    if (top is! ASN1Sequence ||
        top.elements == null ||
        top.elements!.length < 2) {
      throw const CryptoException('Публичный ключ имеет неверный формат.');
    }
    final algorithm = top.elements![0];
    if (algorithm is! ASN1Sequence ||
        algorithm.elements == null ||
        algorithm.elements!.isEmpty) {
      throw const CryptoException('Публичный ключ имеет неверный формат.');
    }
    final oid = algorithm.elements![0];
    if (oid is! ASN1ObjectIdentifier ||
        oid.objectIdentifierAsString != kRsaEncryptionOid) {
      throw const CryptoException(
        'Публичный ключ должен быть RSA типа PUBLIC KEY.',
      );
    }
    final bitString = top.elements![1];
    if (bitString is! ASN1BitString || bitString.stringValues == null) {
      throw const CryptoException('Публичный ключ имеет неверный формат.');
    }
    final rsaBytes = Uint8List.fromList(bitString.stringValues!);
    final rsaKey = ASN1Parser(rsaBytes).nextObject();
    if (rsaKey is! ASN1Sequence ||
        rsaKey.elements == null ||
        rsaKey.elements!.length < 2) {
      throw const CryptoException('Публичный ключ имеет неверный формат.');
    }
    final modulus = rsaKey.elements![0];
    final exponent = rsaKey.elements![1];
    if (modulus is! ASN1Integer ||
        exponent is! ASN1Integer ||
        modulus.integer == null ||
        exponent.integer == null) {
      throw const CryptoException('Публичный ключ имеет неверный формат.');
    }
    if (modulus.integer!.bitLength < kMinRsaModulusBits) {
      throw const CryptoException('Модуль публичного ключа слишком короткий.');
    }
    return RSAPublicKey(modulus.integer!, exponent.integer!);
  } on CryptoException {
    rethrow;
  } catch (_) {
    throw const CryptoException('Публичный ключ имеет неверный формат.');
  }
}
