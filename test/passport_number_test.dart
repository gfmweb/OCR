import 'package:flutter_test/flutter_test.dart';
import 'package:ru_passport/domain/passport_number.dart';

void main() {
  test('compactPassportNumber keeps six digits', () {
    expect(compactPassportNumber('567890'), '567890');
    expect(compactPassportNumber('567 890'), '567890');
    expect(compactPassportNumber('1234567890'), '567890');
    expect(compactPassportNumber('123'), isNull);
  });

  test('matchPassportNumbers compares only the number', () {
    expect(
      matchPassportNumbers(firstNumber: '567890', registrationNumber: '567890'),
      PassportNumberMatch.match,
    );
    expect(
      matchPassportNumbers(firstNumber: '1234 567890', registrationNumber: '567890'),
      PassportNumberMatch.match,
    );
    expect(
      matchPassportNumbers(firstNumber: '567890', registrationNumber: '000000'),
      PassportNumberMatch.mismatch,
    );
    expect(
      matchPassportNumbers(firstNumber: '567890', registrationNumber: ''),
      PassportNumberMatch.missing,
    );
  });
}
