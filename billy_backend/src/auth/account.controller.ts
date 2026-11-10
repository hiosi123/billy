import { Body, Controller, Get, Put, UseGuards } from '@nestjs/common';
import { AuthService } from './auth.service';
import { JwtAuthGuard } from './jwt-auth.guard';
import { ChangePasswordDto, ChangeUsernameDto } from './dto/account.dto';
import { CurrentUser, AuthUser } from '../common/current-user.decorator';

/** 내 계정 — 누구나 자기 것만. 남의 계정은 users(관리자 전용)에서. */
@UseGuards(JwtAuthGuard)
@Controller('account')
export class AccountController {
  constructor(private readonly authService: AuthService) {}

  @Get()
  me(@CurrentUser() user: AuthUser) {
    return this.authService.account(user.id);
  }

  @Put('username')
  changeUsername(@CurrentUser() user: AuthUser, @Body() dto: ChangeUsernameDto) {
    return this.authService.changeUsername(user.id, dto.username, dto.currentPassword);
  }

  @Put('password')
  changePassword(@CurrentUser() user: AuthUser, @Body() dto: ChangePasswordDto) {
    return this.authService.changePassword(user.id, dto.currentPassword, dto.newPassword);
  }
}
