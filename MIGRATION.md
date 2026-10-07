# 맥미니 이사 안내 — billy (2026-10-07)

새 컴퓨터에서 이 레포를 clone 하면 코드는 다 따라온다. 깃에 없는 것(서명 키·DB 백업·Claude 기억)은
암호를 걸어 **elemental 레포**에 넣어 뒀다 → `elemental/migrate-secrets-billy.tar.gz.enc`

> **이 레포는 public 이다.** 뛰딩·elemental 처럼 번들을 이 레포에 넣지 않은 이유다 — 암호화돼 있어도
> public 이면 누구나 받아서 암호를 대입해 볼 수 있다. 이 파일에도 값은 하나도 없다.
> 앞으로도 키·`.env`·DB 덤프·메모리 사본은 이 레포에 **어떤 형태로도**(암호화해도) 넣지 않는다.

```bash
cd /Users/simon/Desktop/app
git clone git@github.com:hiosi123/billy.git
git clone git@github.com:hiosi123/elemental.git   # 번들이 여기 있다 (private)
```

---

## 1. 손으로 옮길 것 — 깃에 없다 (제일 먼저)

| 무엇 | 위치 | 잃어버리면 |
|---|---|---|
| `upload-keystore.jks` | `billy_frontend/android/` | **앱 업데이트를 못 올린다** (Play 지원팀에 업로드 키 재설정 신청해야 복구) |
| `key.properties` | `billy_frontend/android/` | 위 키스토어 비밀번호 — 같이 잃으면 위와 동일 |
| `KEYSTORE_BACKUP.txt` | `billy_frontend/android/` | 비밀번호·지문 메모 (위 두 파일이 있으면 다시 만들 수 있다) |
| `backups/` | 레포 루트 | 운영 DB 덤프 3개(6/7·6/15). 원본은 운영 DB 이고 이건 그때의 스냅샷 |
| Claude 기억 | `~/.claude/projects/-Users-simon-Desktop-app-billy/memory/` | 이전 작업 제약(SHA-256·synchronize 금지·계산 공식 1:1)·배포 메모 |

> 이 키스토어는 **elemental 것과 바이트 단위로 같은 파일**이다(billy 에서 처음 만들고 elemental 이 같이 쓴다).
> `key.properties` 도 내용이 같다. 그래서 elemental 번들(`migrate-secrets.tar.gz.enc`)에도 같은 키가 들어 있다.

### 푸는 법 — 홈 폴더에서 풀면 전부 제자리로 (암호는 elemental 번들과 같은 것)

> 10/7 에 elemental 번들이 그 암호로 풀리는 걸 확인한 뒤에 만들었다. **뛰딩 번들은 그 암호로 안 풀렸다** —
> 뛰딩 것과 같다고 가정하지 말 것.

번들 안의 경로가 홈 기준(`Desktop/app/billy/...`, `.claude/projects/...`)이다.
**billy 와 elemental 을 먼저 clone** 해 둘 것 — 먼저 풀면 billy 폴더가 생겨서 clone 이 "이미 있음"으로 실패한다.

```bash
cd ~
openssl enc -d -aes-256-cbc -pbkdf2 -iter 300000 -in Desktop/app/elemental/migrate-secrets-billy.tar.gz.enc | tar xzvf -
```

제자리에 들어갔는지 — 비밀번호는 출력하지 않는다:

```bash
cd ~/Desktop/app/billy
ls -l billy_frontend/android/upload-keystore.jks billy_frontend/android/KEYSTORE_BACKUP.txt backups/
sed -E 's/=.*/=<숨김>/' billy_frontend/android/key.properties    # 4줄: storePassword keyPassword keyAlias storeFile
ls ~/.claude/projects/-Users-simon-Desktop-app-billy/memory/     # MEMORY.md 포함 4개
```

`key.properties` 와 그 안의 `storeFile` 은 `build.gradle.kts` 가 `rootProject.file(...)` 로 읽어서
**`billy_frontend/android/` 기준**이다. macOS 기본 openssl(LibreSSL)로도 풀린다(10/7 확인).

⚠️ 폴더 이름 `-Users-simon-Desktop-app-billy` 는 레포 경로를 그대로 쓴 이름이다. 새 맥에서도
`/Users/simon/Desktop/app/billy` 에 두면 그대로 맞는다. 경로가 다르면 풀고 나서 그 경로 이름(`/` → `-`)으로 폴더를 옮긴다.

옮기고 나면 번들은 elemental 레포에서 지운다 (elemental 은 push 하면 재배포된다 — 코드 변경이 없어 무해):

```bash
cd ~/Desktop/app/elemental && git rm migrate-secrets-billy.tar.gz.enc && git commit -m "chore: billy 이사 끝 — 시크릿 번들 제거" && git push
```

> 맥 **마이그레이션 어시스턴트**로 통째로 옮겼다면 이것들도, `~/.claude` 도 이미 따라와 있다.

### 옮기면 좋은 것 (선택) — 크기 때문에 번들에 안 넣었다

| 폴더 | 크기 | 내용 |
|---|---|---|
| `images/` | 19MB | 계량기·고지서 예시 사진 7장 (OCR 만들 때 쓴 것 — 코드에서는 안 읽는다). 필요하면 AirDrop |
| `release_artifacts/` | 83MB | 1.0.0+1 AAB (6/11) — 다시 빌드하면 된다. 안 옮겨도 된다 |

깃 히스토리는 지울 수 없어서, 큰 파일을 번들에 넣으면 elemental 레포가 그만큼 영구히 무거워진다.

---

## 2. 워크스페이스 파일 · 다시 로그인

`/Users/simon/Desktop/app/CLAUDE.md`·`APP_PLAYBOOK.md`·`~/.claude/settings.json` 사본은 **뛰딩·elemental 레포의
`docs/claude/`** 에 있다(둘 다 내용 같음). 이 레포는 public 이라 넣지 않았다 — 그쪽 `MIGRATION.md` 대로 복원한다.

다시 로그인: `gh auth login` · Railway(웹 또는 `railway login`) · Play Console(브라우저) · AWS 콘솔(S3 버킷을 볼 때만)

---

## 3. 옮길 필요 없는 것 — 클라우드에 있다

**Railway 환경변수**는 Railway 에 있다. 이름만 적어 둔다 (값은 Railway 웹에서):

| 서비스 | 변수 |
|---|---|
| `billy-backend` | `DATABASE_URL`(끝이 **`/billy`** — 공유 Postgres 안의 billy DB) · `DB_SYNCHRONIZE`(**false 고정**) · `JWT_SECRET` · `JWT_EXPIRES_IN` · `CORS_ORIGIN` · `PORT` · AI 사진 인식 `OPENAI_API_KEY`·`OPENAI_MODEL`·`OPENAI_BILL_MODEL`(있으면 우선) 또는 `ANTHROPIC_API_KEY`·`ANTHROPIC_MODEL`·`ANTHROPIC_BILL_MODEL` · 사진 저장 `AWS_S3_REGION`·`AWS_S3_BUCKET`·`AWS_ACCESS_KEY`·`AWS_SECRET_KEY` |
| `billy-frontend` | `API_BASE_URL` — Dockerfile 기본값 `https://billy-backend.up.railway.app/api/v1` |

배포는 `main` push = 자동 재배포다(이 파일을 올린 push 도 재배포를 일으킨다). 프론트 Docker 빌드는 Flutter **3.44.0** 고정.

---

## 4. 개발 환경

이 맥북 기준: Flutter 3.41.6 · Node 23.7 · npm 10.9 (billy 는 Dart `^3.9.0` 이상이면 된다)

```bash
sudo xcodebuild -license accept      # 안 하면 flutter build appbundle 이 exit 69 로 죽는다 (뛰딩에서 겪음)
cd billy_frontend && flutter pub get
cd ../billy_backend && npm ci
```

이 맥북에도 로컬 `.env`·로컬 DB 는 없었다. 로컬 백엔드가 필요하면 `.env.example` 을 복사해 채운다.
스키마는 `sql/schema.sql` + `sql/migrations/*.sql` 로만 만든다 — **synchronize 금지**(운영 스키마를 건드릴 수 있다).

---

## 5. 제대로 옮겨졌는지 확인

```bash
# 1) 백엔드 — 테스트 셋업이 없어서 빌드가 곧 검사다
cd billy_backend && npm ci && npm run build

# 2) 프론트 — 오류·경고 0 (info 4개는 원래 있다 → --no-fatal-infos 없이 돌리면 exit 1), 테스트 2개
cd ../billy_frontend && flutter analyze --no-fatal-infos && flutter test

# 3) 서명 파일이 제자리에 있는지 (비밀번호는 출력 안 함)
test -f android/upload-keystore.jks && test -f android/key.properties && echo "서명 파일 OK"

# 4) 릴리스 빌드가 끝까지 도는지 — 성공하면 서명까지 된 것
flutter build appbundle --release --dart-define=API_BASE_URL=https://billy-backend.up.railway.app/api/v1

# 5) 운영이 살아 있는지
curl -s -o /dev/null -w '%{http_code}\n' https://billy-building.up.railway.app/                  # 200
curl -s -o /dev/null -w '%{http_code}\n' https://billy-backend.up.railway.app/api/v1/buildings   # 401 = 로그인 필요 = 살아 있음
```

---

## 6. 이사 시점의 상태 (2026-10-07)

- 마지막 커밋 2026-06-15 (전기 고지서 OCR — 같은 건물 직전 정답을 few-shot 으로). 운영 정상(웹 200 · API 401).
- 앱 버전 `1.0.0+1`. 6/11 에 서명한 AAB 가 `release_artifacts/` 에 있다. **Play Console 상태는 이번에 확인하지 않았다**
  (`play_store/README.md` 체크리스트 참고). +1 이 이미 올라갔다면 다음 빌드는 `+2` 이상 — versionCode 는 재사용 불가.
- Claude 메모리는 6/7 에 멈춰 있던 것을 이사 직전에 고쳐 썼다("통합테스트 미실시", "OCR 은 Anthropic 만" 등).

---

## 참고 — 번들을 만든 방법

이미 elemental 레포에 들어 있으면 할 필요 없다. 다시 만들어야 할 때만 (결과는 **elemental 레포**에 둔다 — 이 레포는 public):

```bash
# 암호는 직접 입력한다 (이 파일에도, 채팅에도 남기지 말 것)
cd ~
COPYFILE_DISABLE=1 tar czf - --exclude='.DS_Store' \
  Desktop/app/billy/billy_frontend/android/upload-keystore.jks \
  Desktop/app/billy/billy_frontend/android/key.properties \
  Desktop/app/billy/billy_frontend/android/KEYSTORE_BACKUP.txt \
  Desktop/app/billy/backups \
  .claude/projects/-Users-simon-Desktop-app-billy/memory \
  | openssl enc -aes-256-cbc -pbkdf2 -iter 300000 -salt -out Desktop/app/elemental/migrate-secrets-billy.tar.gz.enc
```

10/7 에는 암호를 한 번만 받아(화면에 안 나오게) **elemental 번들이 그 암호로 풀리는지 먼저 확인한 뒤** 만들었다 —
암호를 잘못 쳐서 다른 암호로 잠그는 일을 막으려고.

확인은 **`tar tzf`** 로 한다. macOS tar 는 압축본 끝을 0 으로 채워서(10240바이트 단위) `gzip -t` 는 맞는 암호에도
"trailing garbage" 경고와 함께 exit 2 를 낸다 — 이걸로 확인했다가 맞는 암호를 틀렸다고 판정한 적이 있다(10/7).
