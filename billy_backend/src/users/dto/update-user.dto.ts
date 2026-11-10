import { Transform } from 'class-transformer';
import { ArrayMaxSize, IsArray, IsEnum, IsInt, IsOptional, IsString, Matches, MaxLength, MinLength } from 'class-validator';
import { UserRole } from '../user.entity';

const trim = ({ value }: { value: unknown }) => (typeof value === 'string' ? value.trim() : value);

export class UpdateUserDto {
  @IsOptional()
  @Transform(trim)
  @IsString()
  @MinLength(5, { message: '아이디는 5자 이상이어야 합니다' })
  @MaxLength(32, { message: '아이디는 32자까지 됩니다' })
  @Matches(/^\S+$/, { message: '아이디에 띄어쓰기를 넣을 수 없습니다' })
  username?: string;

  @IsOptional()
  @IsString()
  @MinLength(10, { message: '비밀번호는 10자 이상이어야 합니다' })
  @MaxLength(64, { message: '비밀번호는 64자까지 됩니다' })
  @Matches(/^\S+$/, { message: '비밀번호에 공백을 포함할 수 없습니다' })
  password?: string;

  @IsOptional()
  @IsEnum(['admin', 'manager', 'viewer'], { message: 'role은 admin, manager, viewer 중 하나여야 합니다' })
  role?: UserRole;
}

export class SetUserBuildingsDto {
  @IsArray()
  @ArrayMaxSize(500)
  @IsInt({ each: true })
  buildingIds: number[];
}
