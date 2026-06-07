// 플랫폼별 파일 저장/다운로드 진입점.
// 웹: 브라우저 다운로드 / 모바일·데스크톱: 파일 저장 후 공유 시트.
export 'file_saver_io.dart' if (dart.library.html) 'file_saver_web.dart';
