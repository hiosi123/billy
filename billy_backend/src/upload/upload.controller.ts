import { Controller, Post, Body, UseGuards } from '@nestjs/common';
import { IsString, IsIn } from 'class-validator';
import { UploadService } from './upload.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';

class PresignedUrlDto {
  /** 저장 폴더(고지서 사진 = bill, 계량기 = meter). */
  @IsIn(['bill', 'meter']) folder: string;
  @IsString() contentType: string;
}

@UseGuards(JwtAuthGuard)
@Controller('upload')
export class UploadController {
  constructor(private service: UploadService) {}

  @Post('presigned-url')
  getPresignedUrl(@Body() dto: PresignedUrlDto) {
    return this.service.getPresignedUrl(dto.folder, dto.contentType);
  }
}
