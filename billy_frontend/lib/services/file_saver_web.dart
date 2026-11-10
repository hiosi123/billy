import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

/// 웹: Blob + 앵커 클릭으로 즉시 다운로드(dart:html 대신 package:web — 낡은 API 경고 제거).
Future<String> saveXlsx(List<int> bytes, String filename) async {
  final blob = web.Blob(
    [Uint8List.fromList(bytes).toJS].toJS,
    web.BlobPropertyBag(type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'),
  );
  final url = web.URL.createObjectURL(blob);
  final a = web.HTMLAnchorElement()
    ..href = url
    ..download = filename;
  web.document.body?.append(a);
  a.click();
  a.remove();
  // 바로 지우면 아이폰 사파리·홈 화면 앱에서 내려받기가 조용히 실패했다 — 잠시 뒤에 지운다
  Future.delayed(const Duration(seconds: 30), () => web.URL.revokeObjectURL(url));
  return filename;
}
