import 'dart:typed_data';

import 'package:ru_passport/domain/parsed_field.dart';

enum PhotoKind {
  firstSpread,
  registration,
  portrait,
  signature;

  static const List<PhotoKind> documentOrder = [
    PhotoKind.firstSpread,
    PhotoKind.registration,
    PhotoKind.portrait,
    PhotoKind.signature,
  ];
}

class PassportFieldPair {
  const PassportFieldPair({required this.original, required this.edited});

  final String original;
  final String edited;

  Map<String, String> toJson() => {'original': original, 'edited': edited};
}

class PhotoPlaintext {
  const PhotoPlaintext({required this.kind, required this.bytes});

  final PhotoKind kind;
  final Uint8List bytes;
}

class PassportPlaintext {
  PassportPlaintext({
    required this.fields,
    required List<PhotoPlaintext> photos,
  }) : photos = List<PhotoPlaintext>.unmodifiable(photos);

  final Map<String, PassportFieldPair> fields;
  final List<PhotoPlaintext> photos;

  Map<String, Object> toFieldsJson() {
    return {
      'fields': {
        for (final spec in kPassportFormFields)
          spec.id:
              (fields[spec.id] ??
                      const PassportFieldPair(original: '', edited: ''))
                  .toJson(),
      },
    };
  }
}
