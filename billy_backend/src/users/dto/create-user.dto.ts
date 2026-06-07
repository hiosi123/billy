import { IsEnum, IsString, Matches, MinLength } from 'class-validator';
import { UserRole } from '../user.entity';

export class CreateUserDto {
  @IsString()
  @MinLength(5, { message: '아이디는 5자 이상이어야 합니다' })
  username: string;

  // 기존 Go 백엔드 규칙: 10자 이상, 공백 불가.
  @IsString()
  @MinLength(10, { message: '비밀번호는 10자 이상이어야 합니다' })
  @Matches(/^\S+$/, { message: '비밀번호에 공백을 포함할 수 없습니다' })
  password: string;

  @IsEnum(['admin', 'manager', 'viewer'], { message: 'role은 admin, manager, viewer 중 하나여야 합니다' })
  role: UserRole;
}
