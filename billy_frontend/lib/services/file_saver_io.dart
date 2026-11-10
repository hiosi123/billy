import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// 모바일·데스크톱: 임시 폴더에 저장 후 공유 시트로 열기.
Future<String> saveXlsx(List<int> bytes, String filename) async {
  final dir = await getTemporaryDirectory();
  // 건물 이름에 '/' 같은 글자가 있으면 경로로 읽혀 저장이 실패했다
  final safe = filename.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  final path = '${dir.path}/$safe';
  final file = File(path);
  await file.writeAsBytes(bytes, flush: true);
  await Share.shareXFiles([XFile(path)], text: '관리비 명세서');
  return safe; // 화면엔 파일 이름만(앱 안쪽 경로를 보이지 않게)
}
