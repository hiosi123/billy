import { CanActivate, ExecutionContext, ForbiddenException, Injectable } from '@nestjs/common';

/** 관리자(admin) 전용 라우트 — 계정 관리 등. JwtAuthGuard 뒤에 둔다. */
@Injectable()
export class AdminGuard implements CanActivate {
  canActivate(ctx: ExecutionContext): boolean {
    const user = ctx.switchToHttp().getRequest().user;
    if (user?.role !== 'admin') throw new ForbiddenException('관리자만 할 수 있습니다');
    return true;
  }
}
