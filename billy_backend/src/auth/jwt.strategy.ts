import { Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { DataSource } from 'typeorm';

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(
    configService: ConfigService,
    private readonly dataSource: DataSource,
  ) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: configService.get<string>('JWT_SECRET', ''),
    });
  }

  /**
   * 권한·아이디는 토큰이 아니라 DB 에서 읽는다 — 지운 계정·바뀐 권한이 30일 토큰이 끝날 때까지 남지 않게.
   * 비밀번호를 바꾸기 전에 받은 토큰은 거절한다(다른 기기 로그아웃). 초 단위 비교라 바꾼 그 초에 받은 새 토큰은 산다.
   */
  async validate(payload: { sub: number; iat?: number }) {
    // SELECT * — 005 마이그레이션 전이면 password_changed_at 이 없을 뿐 로그인은 그대로 된다
    const rows = await this.dataSource.query('SELECT * FROM users WHERE user_id = $1', [payload.sub]);
    const u = rows[0];
    if (!u) throw new UnauthorizedException('계정이 없습니다. 다시 로그인해 주세요');
    const changedAt = u.password_changed_at ? Math.floor(new Date(u.password_changed_at).getTime() / 1000) : 0;
    if ((payload.iat ?? 0) < changedAt) throw new UnauthorizedException('비밀번호가 바뀌었습니다. 다시 로그인해 주세요');
    return { id: Number(u.user_id), username: u.username as string, role: (u.role as string) ?? 'viewer' };
  }
}
