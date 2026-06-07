# ── Build stage ─────────────────────────────────────────────────────────────
FROM ghcr.io/cirruslabs/flutter:3.44.0 AS build

WORKDIR /app

COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .

# ⚠️ billy 백엔드는 전역 prefix /api/v1 가 있으므로 API_BASE_URL 끝에 포함한다.
ARG API_BASE_URL=https://billy-backend.up.railway.app/api/v1
# CanvasKit(기본) 렌더러 사용 — 텍스트/입력창을 캔버스에 직접 그려서
# 브라우저 기본 'X(지우기)' 버튼·폰트 로딩 중 깨짐 박스가 생기지 않음.
RUN flutter build web --release --dart-define=API_BASE_URL=$API_BASE_URL

# ── Serve stage ─────────────────────────────────────────────────────────────
FROM nginx:alpine

COPY --from=build /app/build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]
