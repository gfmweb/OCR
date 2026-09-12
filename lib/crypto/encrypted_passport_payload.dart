class EncryptedBlob {
  const EncryptedBlob({
    required this.ciphertext,
    required this.nonce,
    required this.tag,
  });

  final String ciphertext;
  final String nonce;
  final String tag;

  Map<String, String> toJson() => {
    'ciphertext': ciphertext,
    'nonce': nonce,
    'tag': tag,
  };

  factory EncryptedBlob.fromJson(Map<dynamic, dynamic> json) {
    return EncryptedBlob(
      ciphertext: json['ciphertext'] as String? ?? '',
      nonce: json['nonce'] as String? ?? '',
      tag: json['tag'] as String? ?? '',
    );
  }
}

class EncryptedFile {
  const EncryptedFile({
    required this.kind,
    required this.ciphertext,
    required this.nonce,
    required this.tag,
  });

  final String kind;
  final String ciphertext;
  final String nonce;
  final String tag;

  EncryptedBlob get blob =>
      EncryptedBlob(ciphertext: ciphertext, nonce: nonce, tag: tag);

  Map<String, String> toJson() => {
    'kind': kind,
    'ciphertext': ciphertext,
    'nonce': nonce,
    'tag': tag,
  };

  factory EncryptedFile.fromJson(Map<dynamic, dynamic> json) {
    return EncryptedFile(
      kind: json['kind'] as String? ?? '',
      ciphertext: json['ciphertext'] as String? ?? '',
      nonce: json['nonce'] as String? ?? '',
      tag: json['tag'] as String? ?? '',
    );
  }
}

class EncryptedPassportPayload {
  const EncryptedPassportPayload({
    required this.version,
    required this.keyAlgorithm,
    required this.dataAlgorithm,
    required this.encryptedKey,
    required this.passport,
    required this.photos,
  });

  final int version;
  final String keyAlgorithm;
  final String dataAlgorithm;
  final String encryptedKey;
  final EncryptedBlob passport;
  final List<EncryptedFile> photos;

  Map<String, Object> toJson() => {
    'version': version,
    'key_algorithm': keyAlgorithm,
    'data_algorithm': dataAlgorithm,
    'encrypted_key': encryptedKey,
    'passport': passport.toJson(),
    'photos': [for (final photo in photos) photo.toJson()],
  };

  factory EncryptedPassportPayload.fromJson(Map<dynamic, dynamic> json) {
    final photosRaw = json['photos'];
    final passportRaw = json['passport'];
    return EncryptedPassportPayload(
      version: (json['version'] as num?)?.toInt() ?? 0,
      keyAlgorithm: json['key_algorithm'] as String? ?? '',
      dataAlgorithm: json['data_algorithm'] as String? ?? '',
      encryptedKey: json['encrypted_key'] as String? ?? '',
      passport: EncryptedBlob.fromJson(
        passportRaw is Map ? passportRaw : <dynamic, dynamic>{},
      ),
      photos: photosRaw is List
          ? photosRaw.whereType<Map>().map(EncryptedFile.fromJson).toList()
          : const [],
    );
  }
}
