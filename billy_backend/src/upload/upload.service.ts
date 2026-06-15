import { Injectable, InternalServerErrorException, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { S3Client, PutObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { randomUUID } from 'crypto';

/**
 * S3 presigned URL 발급. (ddiding 방식과 동일)
 * 프론트가 uploadUrl 로 이미지 바이트를 직접 PUT 하고, imageUrl 을 저장한다.
 * 필요 환경변수: AWS_S3_REGION, AWS_S3_BUCKET, AWS_ACCESS_KEY, AWS_SECRET_KEY
 */
@Injectable()
export class UploadService {
  private readonly logger = new Logger(UploadService.name);
  private s3: S3Client;
  private bucket: string;
  private region: string;

  constructor(private configService: ConfigService) {
    this.region = this.configService.get<string>('AWS_S3_REGION') ?? 'ap-northeast-2';
    this.bucket = this.configService.get<string>('AWS_S3_BUCKET') ?? '';
    this.s3 = new S3Client({
      region: this.region,
      credentials: {
        accessKeyId: this.configService.get<string>('AWS_ACCESS_KEY') ?? '',
        secretAccessKey: this.configService.get<string>('AWS_SECRET_KEY') ?? '',
      },
      requestChecksumCalculation: 'when_required' as any,
      responseChecksumValidation: 'when_required' as any,
    });
  }

  async getPresignedUrl(folder: string, contentType: string) {
    if (!this.bucket) {
      throw new InternalServerErrorException(
        'S3 버킷이 설정되지 않았습니다 (AWS_S3_BUCKET 등 환경변수를 확인하세요)',
      );
    }
    const ext = contentType.split('/')[1]?.replace('jpeg', 'jpg') ?? 'jpg';
    const key = `${folder}/${randomUUID()}.${ext}`;
    const command = new PutObjectCommand({ Bucket: this.bucket, Key: key, ContentType: contentType });
    const uploadUrl = await getSignedUrl(this.s3, command, {
      expiresIn: 300,
      unhoistableHeaders: new Set(['x-amz-checksum-crc32', 'x-amz-sdk-checksum-algorithm']),
    });
    return { uploadUrl, imageUrl: `https://${this.bucket}.s3.${this.region}.amazonaws.com/${key}` };
  }
}
