enum PassportNumberMatch { none, match, mismatch, missing }

String? compactPassportNumber(String number) {
  final digits = number.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.length == 6) {
    return digits;
  }
  if (digits.length == 10) {
    return digits.substring(4);
  }
  return null;
}

PassportNumberMatch matchPassportNumbers({
  required String firstNumber,
  required String registrationNumber,
}) {
  final first = compactPassportNumber(firstNumber);
  final registration = compactPassportNumber(registrationNumber);
  if (registration == null) {
    return PassportNumberMatch.missing;
  }
  if (first == null) {
    return PassportNumberMatch.missing;
  }
  return first == registration ? PassportNumberMatch.match : PassportNumberMatch.mismatch;
}
