import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// 모바일·데스크톱: 임시 폴더에 저장 후 공유 시트로 열기.
Future<String> saveXlsx(List<int> bytes, String filename) async {
  final dir = await getTemporaryDirectory();
  final path = '${dir.path}/$filename';
  final file = File(path);
  await file.writeAsBytes(bytes, flush: true);
  await Share.shareXFiles([XFile(path)], text: '관리비 명세서');
  return path;
}
