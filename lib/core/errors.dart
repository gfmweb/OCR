class OcrException implements Exception {
  const OcrException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}
