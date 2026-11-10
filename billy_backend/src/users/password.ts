import { Repository } from 'typeorm';
import { User } from './user.entity';
import { sha256Hex } from '../common/crypto.util';

/**
 * 비밀번호를 바꾸고 바꾼 시각을 남긴다 — 그 전에 받은 토큰은 JwtStrategy 가 거절한다(다른 기기 로그아웃).
 * 시각은 이 서버 시계로 넣는다(바로 뒤에 서명하는 새 토큰의 iat 와 같은 시계). 005 전이면 비밀번호만 바꾼다.
 */
export async function setPassword(repo: Repository<User>, userId: number, plain: string): Promise<void> {
  const hash = sha256Hex(plain);
  try {
    await repo.query('UPDATE users SET password = $1, password_changed_at = $2 WHERE user_id = $3', [hash, new Date(), userId]);
  } catch (e) {
    if ((e as { code?: string }).code !== '42703') throw e; // undefined_column — 005 미적용
    await repo.query('UPDATE users SET password = $1 WHERE user_id = $2', [hash, userId]);
  }
}
