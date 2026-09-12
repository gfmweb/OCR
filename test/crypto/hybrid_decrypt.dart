import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:pointycastle/api.dart' hide Mac;
import 'package:pointycastle/asn1.dart';
import 'package:pointycastle/asymmetric/api.dart';
import 'package:pointycastle/asymmetric/oaep.dart';
import 'package:pointycastle/asymmetric/rsa.dart';
import 'package:ru_passport/crypto/encrypted_passport_payload.dart';

RSAPrivateKey parseRsaPrivateKeyPem(String pem) {
  final normalized = pem.trim();
  final der = ASN1Utils.getBytesFromPEMString(normalized);
  final top = ASN1Parser(der).nextObject() as ASN1Sequence;
  late final ASN1Sequence rsaSeq;
  if (normalized.contains('BEGIN PRIVATE KEY')) {
    final octet = top.elements![2] as ASN1OctetString;
    rsaSeq = ASN1Parser(octet.octets!).nextObject() as ASN1Sequence;
  } else {
    rsaSeq = top;
  }
  final modulus = (rsaSeq.elements![1] as ASN1Integer).integer!;
  final privateExponent = (rsaSeq.elements![3] as ASN1Integer).integer!;
  final p = (rsaSeq.elements![4] as ASN1Integer).integer!;
  final q = (rsaSeq.elements![5] as ASN1Integer).integer!;
  return RSAPrivateKey(modulus, privateExponent, p, q);
}

Uint8List rsaOaepSha256Decrypt(RSAPrivateKey privateKey, Uint8List ciphertext) {
  final cipher = OAEPEncoding.withSHA256(RSAEngine());
  cipher.init(false, PrivateKeyParameter<RSAPrivateKey>(privateKey));
  return cipher.process(ciphertext);
}

Future<Uint8List> aesGcmDecrypt({
  required Uint8List aesKey,
  required EncryptedBlob blob,
}) {
  return aesGcmDecryptParts(
    aesKey: aesKey,
    ciphertext: blob.ciphertext,
    nonce: blob.nonce,
    tag: blob.tag,
  );
}

Future<Uint8List> aesGcmDecryptParts({
  required Uint8List aesKey,
  required String ciphertext,
  required String nonce,
  required String tag,
}) async {
  final clear = await AesGcm.with256bits().decrypt(
    SecretBox(
      base64Decode(ciphertext),
      nonce: base64Decode(nonce),
      mac: Mac(base64Decode(tag)),
    ),
    secretKey: SecretKey(aesKey),
  );
  return Uint8List.fromList(clear);
}

Future<({Uint8List aesKey, Uint8List fieldsJson, List<Uint8List> photos})>
decryptPayload({
  required EncryptedPassportPayload payload,
  required RSAPrivateKey privateKey,
}) async {
  final aesKey = rsaOaepSha256Decrypt(
    privateKey,
    base64Decode(payload.encryptedKey),
  );
  final fieldsJson = await aesGcmDecrypt(
    aesKey: aesKey,
    blob: payload.passport,
  );
  final photos = <Uint8List>[];
  for (final photo in payload.photos) {
    photos.add(
      await aesGcmDecryptParts(
        aesKey: aesKey,
        ciphertext: photo.ciphertext,
        nonce: photo.nonce,
        tag: photo.tag,
      ),
    );
  }
  return (aesKey: aesKey, fieldsJson: fieldsJson, photos: photos);
}
