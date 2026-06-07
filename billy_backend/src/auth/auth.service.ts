import { Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { User } from '../users/user.entity';
import { sha256Hex } from '../common/crypto.util';

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

  private buildResponse(user: User) {
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
