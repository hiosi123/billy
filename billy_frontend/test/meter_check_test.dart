import 'package:flutter_test/flutter_test.dart';
import 'package:billy_frontend/utils/meter_check.dart';

void main() {
  group('suggestDecimalFix — 2026-10 운영 9월분(소수점 없이 저장된 전기 지침)', () {
    test('소수 한 자리 계량기: 10으로 나눈 값을 제안', () {
      expect(suggestDecimalFix(120737, 12049.6), closeTo(12073.7, 1e-9)); // 천리안안과-1
      expect(suggestDecimalFix(532068, 52121.8), closeTo(53206.8, 1e-9)); // KTF
      expect(suggestDecimalFix(370010, 36264.2), closeTo(37001.0, 1e-9)); // 약국
    });

    test('소수 두 자리 계량기(×25 배수 호실): 100으로 나눈 값을 제안', () {
      expect(suggestDecimalFix(743086, 7293.23), closeTo(7430.86, 1e-9)); // 고려신경-1
      expect(suggestDecimalFix(648680, 6334.68), closeTo(6486.80, 1e-9)); // 사랑채
    });

    test('정상 지침·숫자 하나 빠진 값은 소수점 문제로 보지 않는다', () {
      expect(suggestDecimalFix(12073.7, 12049.6), isNull); // 바르게 입력
      expect(suggestDecimalFix(126439, 108347.5), isNull); // 행복마당 — 소수점이 아닌 다른 실수(서버가 짚는다)
      expect(suggestDecimalFix(781, 777), isNull); // 수도
    });

    test('지난달 값이 없거나 아주 작으면(새 계량기) 판단하지 않는다', () {
      expect(suggestDecimalFix(120737, null), isNull);
      expect(suggestDecimalFix(null, 12049.6), isNull);
      expect(suggestDecimalFix(250, 20), isNull);
      expect(suggestDecimalFix(0, 0), isNull);
    });

    test('나눠도 지난달 근처가 안 되면 제안하지 않는다', () {
      expect(suggestDecimalFix(9000000, 12049.6), isNull); // 10·100·1000 어느 것도 12,049.6~18,074.4 밖
    });
  });

  test('plainReading — 뒤의 0 없이 입력칸 문자열로', () {
    expect(plainReading(12073.7), '12073.7');
    expect(plainReading(7430.86), '7430.86');
    expect(plainReading(37001.0), '37001');
    expect(plainReading(100.5), '100.5');
    expect(plainReading(1000), '1000');
  });
}
