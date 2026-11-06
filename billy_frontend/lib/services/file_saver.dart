// 플랫폼별 파일 저장/다운로드 진입점.
// 웹: 브라우저 다운로드 / 모바일·데스크톱: 파일 저장 후 공유 시트. (웹 전용 코드는 조건부로만 — 안드로이드 빌드 보호)
export 'file_saver_io.dart' if (dart.library.js_interop) 'file_saver_web.dart';
