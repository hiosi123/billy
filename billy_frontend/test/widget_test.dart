import 'package:flutter_test/flutter_test.dart';
import 'package:billy_frontend/utils/num_parse.dart';
import 'package:billy_frontend/utils/format.dart';

void main() {
  test('toDoubleSafe parses num and decimal-string', () {
    expect(toDoubleSafe(6), 6.0);
    expect(toDoubleSafe('6.50'), 6.5);
    expect(toDoubleSafe(null), null);
    expect(toDouble('bad'), 0.0);
  });

  test('chargeMonthLabel formats YYYYMM', () {
    expect(chargeMonthLabel('202507'), '2025년 7월');
  });
}
