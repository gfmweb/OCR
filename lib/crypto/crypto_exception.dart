class CryptoException implements Exception {
  const CryptoException(this.message);

  final String message;

  @override
  String toString() => message;
}
