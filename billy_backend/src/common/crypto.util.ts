import { createHash } from 'crypto';

/**
 * 기존 Go 백엔드와 동일한 비밀번호 해싱: SHA-256 hex.
 * ⚠️ 기존 users 테이블의 비밀번호가 이 방식으로 저장돼 있어 변경하면 기존 계정 로그인 불가.
 *   (예: sha256("1234") = 03ac674216f3e15c761ee1a5e255f067953623c8b388b4459e13f978d7c846f4)
 */
export function sha256Hex(plain: string): string {
  return createHash('sha256').update(plain, 'utf8').digest('hex');
}
