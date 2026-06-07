import { IsEnum, IsOptional, IsString, Matches, MinLength } from 'class-validator';
import { UserRole } from '../user.entity';

export class UpdateUserDto {
  @IsOptional()
  @IsString()
  @MinLength(5)
  username?: string;

  @IsOptional()
  @IsString()
  @MinLength(10)
  @Matches(/^\S+$/, { message: '비밀번호에 공백을 포함할 수 없습니다' })
  password?: string;

  @IsOptional()
  @IsEnum(['admin', 'manager', 'viewer'])
  role?: UserRole;
}
