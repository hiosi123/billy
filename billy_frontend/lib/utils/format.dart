import 'package:intl/intl.dart';

final _won = NumberFormat('#,##0', 'ko_KR');
final _num2 = NumberFormat('#,##0.##', 'ko_KR');

/// 원화 표기: 1234567 → "1,234,567원"
String won(num? v) => '${_won.format((v ?? 0).round())}원';

/// 원화 숫자만(콤마): 1234567 → "1,234,567"
String money(num? v) => _won.format((v ?? 0).round());

/// 일반 숫자(소수 2자리까지): 12.5 → "12.5"
String num2(num? v) => _num2.format(v ?? 0);

/// YYYYMM → "2025년 7월"
String chargeMonthLabel(String? yyyymm) {
  if (yyyymm == null || yyyymm.length != 6) return yyyymm ?? '';
  final y = yyyymm.substring(0, 4);
  final m = int.tryParse(yyyymm.substring(4, 6)) ?? 0;
  return '$y년 $m월';
}

/// 이번 달 YYYYMM
String currentChargeMonth() {
  final now = DateTime.now();
  return '${now.year}${now.month.toString().padLeft(2, '0')}';
}
