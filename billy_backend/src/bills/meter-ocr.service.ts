import { Injectable, InternalServerErrorException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { ReadMeterDto } from './dto/read-meter.dto';

const API_URL = 'https://api.anthropic.com/v1/messages';

/**
 * 계량기 사진을 Claude 비전으로 읽어 지침값(숫자)을 추출한다.
 * ANTHROPIC_API_KEY 환경변수 필요. 모델은 ANTHROPIC_MODEL 로 override 가능.
 */
@Injectable()
export class MeterOcrService {
  constructor(private config: ConfigService) {}

  async readMeter(dto: ReadMeterDto): Promise<{ value: number | null; raw: string }> {
    const apiKey = this.config.get<string>('ANTHROPIC_API_KEY');
    if (!apiKey) {
      throw new InternalServerErrorException('ANTHROPIC_API_KEY가 설정되지 않았습니다 (Railway 변수에 추가하세요)');
    }
    const model = this.config.get<string>('ANTHROPIC_MODEL', 'claude-sonnet-4-6');

    const meterKo = dto.type === 'water' ? '수도(상수도) 계량기' : '전기 계량기';
    const hint =
      dto.lastValue != null
        ? `지난달 검침값은 ${dto.lastValue} 였습니다. 이번 검침값은 보통 그와 비슷하거나 약간 큽니다. 자릿수와 크기를 참고하세요.`
        : '';

    // 시스템 프롬프트는 고정이라 프롬프트 캐싱으로 반복 호출 비용 절감.
    const system = [
      {
        type: 'text',
        text:
          '당신은 한국 건물의 계량기 사진에서 지침값(숫자)을 정확히 읽어내는 OCR 도우미입니다. ' +
          '계량기 표시창의 주 숫자(정수부, 검은색 다이얼/디지털 숫자)를 읽습니다. 빨간색 소수 자리는 무시합니다. ' +
          '오직 숫자만 출력하세요. 콤마/단위/설명 없이 숫자만. 읽을 수 없으면 정확히 "null" 이라고만 답하세요.',
        cache_control: { type: 'ephemeral' },
      },
    ];

    const body = {
      model,
      max_tokens: 50,
      system,
      messages: [
        {
          role: 'user',
          content: [
            {
              type: 'image',
              source: { type: 'base64', media_type: dto.mediaType || 'image/jpeg', data: dto.image },
            },
            { type: 'text', text: `이 ${meterKo} 사진의 지침값을 읽어주세요. ${hint} 숫자만 답하세요.` },
          ],
        },
      ],
    };

    let res: any;
    try {
      res = await fetch(API_URL, {
        method: 'POST',
        headers: {
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
          'content-type': 'application/json',
        },
        body: JSON.stringify(body),
      });
    } catch {
      throw new InternalServerErrorException('AI 서버 연결에 실패했습니다');
    }

    if (!res.ok) {
      throw new InternalServerErrorException(`AI 요청 실패 (${res.status})`);
    }

    const data = await res.json();
    const raw: string = (data?.content?.[0]?.text ?? '').trim();
    return { value: this.parseNumber(raw), raw };
  }

  private parseNumber(raw: string): number | null {
    if (!raw || /^null$/i.test(raw.trim())) return null;
    const match = raw.replace(/,/g, '').match(/-?\d+(\.\d+)?/);
    if (!match) return null;
    const n = parseFloat(match[0]);
    return Number.isFinite(n) ? n : null;
  }
}
