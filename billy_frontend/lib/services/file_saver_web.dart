// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// 웹: Blob + 앵커 클릭으로 즉시 다운로드.
Future<String> saveXlsx(List<int> bytes, String filename) async {
  final blob = html.Blob([
    bytes,
  ], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
  return filename;
}
