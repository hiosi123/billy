/// 검침값 소수점 빠짐 감지.
///
/// 누적 계량기 지침은 한 달 새 몇 배씩 뛰지 않는다. 지난달 지침의 5배 이상인데 10·100·1000 으로
/// 나누면 지난달 이상 ~ 1.5배 이하가 되면 소수점이 빠진 것으로 보고 그 값을 돌려준다(아니면 null).
/// 2026-10: 9월 전기 지침 8곳이 소수점 없이 저장돼(12,073.7 → 120,737) 관리비 계산이 500 을 냈다.
double? suggestDecimalFix(double? reading, double? lastReading) {
  // 지난달 지침이 아주 작으면(새 계량기) 몇 배 뛰는 게 정상일 수 있어 보지 않는다.
  if (reading == null || lastReading == null || lastReading < 100) return null;
  if (reading < lastReading * 5) return null;
  for (final div in const [10, 100, 1000]) {
    final fixed = reading / div;
    if (fixed >= lastReading && fixed <= lastReading * 1.5) return fixed;
  }
  return null;
}

/// 입력칸에 넣을 지침 문자열 — 소수 셋째 자리까지, 뒤의 0 은 뺀다(12073.7 · 7430.86 · 37001).
String plainReading(double v) => v.toStringAsFixed(3).replaceFirst(RegExp(r'\.?0+$'), '');

/// 지침이 지난달보다 작을 때 서버가 계산하는 사용량(계량기가 한 바퀴 돈 것으로 봄):
/// (지난달 지침 자릿수의 다음 10의 거듭제곱 − 지난달 + 이번달) × 배수.
/// 화면에서 '그대로 저장하면 사용량이 얼마로 잡히는지' 보여 줄 때 쓴다(bill-calc.ts calculateDifference 와 같은 식).
double rolloverUsage(double last, double reading, double multiply) {
  final digits = last >= 1 ? last.floor().toString().length : 1;
  final rolloverPoint = _pow10(digits);
  return (rolloverPoint - last + reading) * multiply;
}

double _pow10(int n) {
  var v = 1.0;
  for (var i = 0; i < n; i++) {
    v *= 10;
  }
  return v;
}
