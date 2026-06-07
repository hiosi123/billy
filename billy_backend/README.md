# billy_backend

Billy 건물 관리비 시스템 — NestJS 11 + TypeORM + PostgreSQL.

## 실행
```bash
npm install
cp .env.example .env     # DB / JWT 설정
npm run start:dev        # watch 모드, http://localhost:3000/api/v1
npm run build && npm start
```

## 구조 (모듈 = 기능 1개)
```
src/
├── main.ts                 globalPrefix=api/v1, CORS, ValidationPipe
├── app.module.ts           모듈 조립 (BillHistories 를 Bills 보다 먼저 등록)
├── config/database.config  PostgreSQL TypeORM (synchronize:false)
├── common/                 decimal transformer, sha256, logger, @CurrentUser
├── auth/                   JWT + SHA-256 로그인 (기존 계정 호환)
├── users/ buildings/ floors/ rooms/ building-fees/ bill-histories/
└── bills/                  검침입력·관리비계산·엑셀
    ├── bill-calc.ts        계산 코어 (기존 Go 공식 1:1)
    ├── bills.service.ts    insertMeasure / calculate / getByCondition
    └── excel.service.ts    exceljs 템플릿 치환
```

## 데이터 보존
- `synchronize:false` 고정. 스키마 변경은 `sql/migrations/*.sql`(멱등).
- 엔티티는 기존 snake_case 컬럼에 `@Column({ name })` 로 정확히 매핑.
- DECIMAL 컬럼은 `DecimalTransformer` 로 number 변환(문자열 직렬화 버그 방지).

## 주요 엔드포인트 (모두 `/api/v1` prefix)
| Method | Path | 설명 |
|---|---|---|
| POST | `/auth/login` | 로그인 (JWT 발급) |
| GET | `/buildings` `/buildings/user` | 건물 목록 / 내 건물 |
| GET | `/floors/buildings/:id` | 건물의 층 |
| GET | `/rooms/buildings/:id` | 건물의 호실(+floor 조인) |
| POST | `/bills/measurements` | 검침값 입력 → 사용량 계산 |
| POST | `/bills/calculate` | 관리비 계산 |
| POST | `/bills/excel` | 호실별 명세서 엑셀 다운로드 |
| GET/POST | `/building-fees/...` | 건물 고정 관리비 |
| GET/POST | `/bills/histories/...` | 확정 명세 보관 |
