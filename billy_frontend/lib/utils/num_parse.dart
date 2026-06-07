/// 백엔드가 DECIMAL 컬럼을 문자열("6.50")로 보낼 수 있어 num/String 모두 안전 파싱한다.
/// 직접 `as num` 캐스트는 String에서 TypeError를 던진다. (ddiding 플레이북 #1 교훈)
double? toDoubleSafe(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

double toDouble(dynamic v) => toDoubleSafe(v) ?? 0.0;

int? toIntSafe(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? double.tryParse(v)?.toInt();
  return null;
}

int toInt(dynamic v) => toIntSafe(v) ?? 0;
