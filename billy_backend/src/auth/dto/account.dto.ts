import { Transform } from 'class-transformer';
import { IsString, Matches, MaxLength, MinLength } from 'class-validator';

const trim = ({ value }: { value: unknown }) => (typeof value === 'string' ? value.trim() : value);

/** 아이디 규칙 — 기존 계정 추가와 같다(5자 이상, 공백 없이). */
export class ChangeUsernameDto {
  @Transform(trim)
  @IsString()
  @MinLength(5, { message: '아이디는 5자 이상이어야 합니다' })
  @MaxLength(32, { message: '아이디는 32자까지 됩니다' })
  @Matches(/^\S+$/, { message: '아이디에 띄어쓰기를 넣을 수 없습니다' })
  username: string;

  @IsString()
  @MinLength(1, { message: '지금 비밀번호를 넣어 주세요' })
  currentPassword: string;
}

/** 비밀번호 규칙 — 기존 Go 백엔드와 같다(10자 이상, 공백 없이). */
export class ChangePasswordDto {
  @IsString()
  @MinLength(1, { message: '지금 비밀번호를 넣어 주세요' })
  currentPassword: string;

  @IsString()
  @MinLength(10, { message: '새 비밀번호는 10자 이상이어야 합니다' })
  @MaxLength(64, { message: '새 비밀번호는 64자까지 됩니다' })
  @Matches(/^\S+$/, { message: '비밀번호에 띄어쓰기를 넣을 수 없습니다' })
  newPassword: string;
}
