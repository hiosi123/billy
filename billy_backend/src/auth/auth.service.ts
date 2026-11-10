import { BadRequestException, ConflictException, Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { User } from '../users/user.entity';
import { sha256Hex } from '../common/crypto.util';
import { setPassword } from '../users/password';

@Injectable()
export class AuthService {
  constructor(
    @InjectRepository(User) private usersRepo: Repository<User>,
    private jwtService: JwtService,
  ) {}

  async login(username: string, password: string) {
    // password 는 select:false 라 명시적으로 가져온다.
    const user = await this.usersRepo.findOne({
      where: { username },
      select: ['userId', 'username', 'password', 'role'],
    });
    if (!user) throw new UnauthorizedException('아이디 또는 비밀번호가 올바르지 않습니다');

    // 기존 Go 백엔드와 동일한 SHA-256 비교 (기존 계정 호환).
    if (user.password !== sha256Hex(password)) {
      throw new UnauthorizedException('아이디 또는 비밀번호가 올바르지 않습니다');
    }

    return this.buildResponse(user);
  }

  /** 내 계정 — 토큰이 아니라 DB 의 지금 값. */
  async account(userId: number) {
    const u = await this.usersRepo.findOne({ where: { userId } });
    if (!u) throw new UnauthorizedException('계정이 없습니다. 다시 로그인해 주세요');
    return { userId: u.userId, username: u.username, role: u.role, isAdmin: u.role === 'admin', createdAt: u.createdAt };
  }

  /** 아이디 바꾸기 — 지금 비밀번호 확인. 새 아이디가 담긴 토큰을 돌려준다. */
  async changeUsername(userId: number, username: string, currentPassword: string) {
    const u = await this.checkPassword(userId, currentPassword);
    if (username === u.username) throw new BadRequestException('지금 아이디와 같습니다');
    const taken = await this.usersRepo.findOne({ where: { username } });
    if (taken && taken.userId !== userId) throw new ConflictException('이미 쓰는 아이디입니다');
    try {
      await this.usersRepo.update({ userId }, { username });
    } catch (e) {
      if ((e as { code?: string }).code === '23505') throw new ConflictException('이미 쓰는 아이디입니다');
      throw e;
    }
    return this.buildResponse({ ...u, username });
  }

  /** 비밀번호 바꾸기 — 다른 기기는 로그아웃되고, 이 기기는 돌려준 새 토큰으로 이어 간다. */
  async changePassword(userId: number, currentPassword: string, newPassword: string) {
    const u = await this.checkPassword(userId, currentPassword);
    if (currentPassword === newPassword) throw new BadRequestException('지금과 다른 비밀번호를 넣어 주세요');
    await setPassword(this.usersRepo, userId, newPassword);
    return this.buildResponse(u);
  }

  /** 틀리면 400 — 401 이면 화면이 '로그인 만료'로 알고 내보낸다. */
  private async checkPassword(userId: number, plain: string): Promise<User> {
    const u = await this.usersRepo.findOne({ where: { userId }, select: ['userId', 'username', 'password', 'role'] });
    if (!u) throw new UnauthorizedException('계정이 없습니다. 다시 로그인해 주세요');
    if (u.password !== sha256Hex(plain)) throw new BadRequestException('지금 비밀번호가 맞지 않습니다');
    return u;
  }

  private buildResponse(user: Pick<User, 'userId' | 'username' | 'role'>) {
    const payload = { sub: user.userId, username: user.username, role: user.role };
    return {
      access_token: this.jwtService.sign(payload),
      user: {
        userId: user.userId,
        username: user.username,
        role: user.role,
        isAdmin: user.role === 'admin',
      },
    };
  }
}
