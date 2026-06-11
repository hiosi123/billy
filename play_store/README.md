# Google Play 출시 준비 — 완료 상태 & 콘솔 체크리스트

## ✅ 코드/빌드 측에서 자동 세팅 완료한 것
| 항목 | 내용 |
|------|------|
| 패키지명(applicationId) | `com.billy.building` *(출시 후 변경 불가)* |
| 앱 표시명 | `Billy - 건물 관리비` |
| 업로드 키스토어 | `billy_frontend/android/upload-keystore.jks` 생성 (alias `upload`, 유효 27년) |
| 서명 설정 | `key.properties` 연동, 릴리스 자동 서명 (둘 다 .gitignore) |
| INTERNET 권한 | AndroidManifest에 추가(API 통신 필수) |
| 코드 축소 | R8 minify + 리소스 축소 활성화 (proguard 규칙 포함) |
| 앱 아이콘 | 브랜드 네이비 빌딩 아이콘 전 해상도 + 적응형 아이콘 생성 |
| 서명된 AAB | **`release_artifacts/billy-release.aab`** (백엔드 URL 주입 완료) |
| 스토어 그래픽 | `play_store/graphics/` 아이콘512 + 피처그래픽 |
| 스토어 문구 | `play_store/store_listing.md` |
| 개인정보처리방침 | `billy_frontend/web/privacy.html` → 배포 시 `/privacy.html` 로 공개 |

> 🔑 **키스토어 비밀번호/지문**은 `billy_frontend/android/KEYSTORE_BACKUP.txt` 에 있습니다.
> 안전한 곳에 꼭 따로 백업하세요. (git에는 올라가지 않음)

---

## 📤 업로드할 파일
```
release_artifacts/billy-release.aab        ← Play Console에 올릴 앱 번들
```

---

## 🚀 Play Console에서 직접 해야 하는 단계 (자동화 불가)

### 0. 사전: 개인정보처리방침 배포
- 프론트엔드를 한 번 재배포하면 `https://billy-building.up.railway.app/privacy.html` 로 열립니다.
- (이번 커밋에 `web/privacy.html` 포함 → push 후 Railway 자동 재배포)

### 1. 앱 만들기
- Play Console → **앱 만들기** → 이름 `Billy - 건물 관리비`, 언어 한국어, 앱/유료 여부 선택.

### 2. AAB 업로드
- **프로덕션**(또는 먼저 **비공개 테스트** 권장) → **새 버전 만들기**.
- **Play 앱 서명** 사용에 동의(기본) → `billy-release.aab` 업로드.
  - 우리가 만든 키는 “업로드 키”. 실제 배포 서명키는 구글이 안전하게 보관 → 분실해도 재설정 가능.

### 3. 스토어 등록정보 (Main store listing)
- `store_listing.md` 의 짧은 설명/자세한 설명 복사.
- 아이콘 `graphics/icon_512.png`, 피처 그래픽 `graphics/feature_graphic_1024x500.png` 업로드.
- **휴대전화 스크린샷 최소 2장** 업로드 (아래 참고).

### 4. 앱 콘텐츠(필수 설문) — 좌측 ‘정책 및 프로그램’ / ‘앱 콘텐츠’
- **개인정보처리방침**: `https://billy-building.up.railway.app/privacy.html`
- **앱 액세스 권한**: 로그인 필요 앱이므로 검수자용 계정 제공
  - 아이디 `admin` / 비밀번호 `1234` (또는 별도 테스트 계정 생성 권장)
- **데이터 보안(Data safety)**: 수집 항목 = 계정정보, 사진(일시처리), 앱 활동.
  - 전송 중 암호화(HTTPS) 예, 제3자 공유(OpenAI OCR 처리) 명시.
- **광고**: 광고 없음.
- **콘텐츠 등급**: 설문 작성 → ‘전체 이용가’ 예상.
- **타겟 연령층**: 18세 이상(업무용) 권장.
- **정부 앱/금융 앱 아님** 등 기본 설문.

### 5. 출시
- 비공개 테스트로 먼저 설치 확인 → 이상 없으면 프로덕션으로 단계적 출시.

---

## 📸 스크린샷 만드는 법 (최소 2장)
실제 기기/에뮬레이터에 설치 후 세로로 캡처하는 것이 가장 보기 좋습니다.

```bash
# 기기 연결 후 디버그 설치
cd billy_frontend
flutter install --release --dart-define=API_BASE_URL=https://billy-backend.up.railway.app/api/v1
# 또는 APK 추출(직접 설치용)
flutter build apk --release --dart-define=API_BASE_URL=https://billy-backend.up.railway.app/api/v1
```
추천 화면: ① 로그인 ② 홈 대시보드 ③ 관리비 계산(AI 버튼) ④ 관리비 내역(통계).

---

## 🔁 다음 버전 올릴 때
1. `pubspec.yaml` 의 `version: 1.0.0+1` 에서 **+뒤 숫자(빌드번호)를 반드시 증가** (예: `1.0.1+2`).
2. 동일 명령으로 재빌드:
   ```bash
   flutter build appbundle --release \
     --dart-define=API_BASE_URL=https://billy-backend.up.railway.app/api/v1
   ```
3. 같은 업로드 키로 자동 서명됨 → 새 AAB를 콘솔에 업로드.
