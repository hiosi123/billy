import { Injectable, InternalServerErrorException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { ReadMeterDto } from './dto/read-meter.dto';
import { ReadBillDto } from './dto/read-bill.dto';

const API_URL = 'https://api.anthropic.com/v1/messages';

/**
 * Claude 비전으로 (1) 계량기 사진의 지침값, (2) 공공요금 고지서의 합계 항목을 읽는다.
 * ANTHROPIC_API_KEY 환경변수 필요. 모델은 ANTHROPIC_MODEL 로 override 가능.
 */
@Injectable()
export class MeterOcrService {
  constructor(private config: ConfigService) {}

  // ── 1. 호실 계량기 사진 → 지침값 1개 ────────────────────────────────
  async readMeter(dto: ReadMeterDto): Promise<{ value: number | null; raw: string }> {
    const meterKo = dto.type === 'water' ? '수도(상수도) 계량기' : '전기 계량기';
    const hint =
      dto.lastValue != null
        ? `지난달 기록된 지침값은 ${dto.lastValue} 입니다. 이번 지침값은 지난달과 같은 자릿수(정수부 자리수)이며 보통 그와 비슷하거나 약간 큽니다. ` +
          '계량기에 소수점/빨간 숫자가 보여도, 지난달 기록과 같은 형식에 맞춰 정수부 위주로 읽으세요.'
        : '';

    const system =
      '당신은 한국 건물의 계량기 사진에서 지침값(숫자)을 정확히 읽어내는 OCR 도우미입니다. ' +
      '계량기 표시창의 주 숫자를 읽습니다. 오직 숫자만 출력하세요. 콤마/단위/설명 없이 숫자만. ' +
      '읽을 수 없으면 정확히 "null" 이라고만 답하세요.';
    const userText = `이 ${meterKo} 사진의 지침값을 읽어주세요. ${hint} 숫자만 답하세요.`;

    const raw = await this.callVision(system, dto.image, dto.mediaType, userText, 50);
    return { value: this.parseNumber(raw), raw };
  }

  // ── 2. 공공요금 고지서 사진 → 합계 항목 여러 개 ─────────────────────
  async readBill(dto: ReadBillDto): Promise<{ [k: string]: number | string | null }> {
    let system: string;
    let userText: string;
    let keys: string[];

    if (dto.type === 'water') {
      keys = ['waterTotalUsage', 'waterSupplyCost', 'waterSewerCost', 'waterTotalCost'];
      system =
        '당신은 한국 상수도(수도) 요금 고지서 사진에서 숫자 항목을 추출하는 도우미입니다. ' +
        '반드시 JSON 한 개만 출력하세요. 설명/코드블록 없이 순수 JSON.';
      userText =
        '이 수도요금 고지서에서 다음 값을 숫자로만 추출해 JSON으로 답하세요. 못 찾으면 null.\n' +
        '{\n' +
        '  "waterTotalUsage": 당월 상수도 사용량(물 총 사용량, 톤),\n' +
        '  "waterSupplyCost": 상수도 사용요금(원),\n' +
        '  "waterSewerCost": 하수도 사용요금(원),\n' +
        '  "waterTotalCost": 청구금액/수납금액 합계(원)\n' +
        '}\n숫자에서 콤마는 제거하고 정수로. JSON만 출력.';
    } else {
      keys = ['electricityTotalCost', 'electricityTotalUsage'];
      system =
        '당신은 한국전력 전기요금 고지서 사진에서 숫자 항목을 추출하는 도우미입니다. ' +
        '반드시 JSON 한 개만 출력하세요. 설명/코드블록 없이 순수 JSON.';
      userText =
        '이 전기요금 고지서에서 다음 값을 숫자로만 추출해 JSON으로 답하세요. 못 찾으면 null.\n' +
        '{\n' +
        '  "electricityTotalCost": 전기요금계(원, 부가세/기금 제외한 전력량요금+기본요금 합계),\n' +
        '  "electricityTotalUsage": 당월 사용량(kWh)\n' +
        '}\n숫자에서 콤마는 제거하고 정수로. JSON만 출력.';
    }

    const raw = await this.callVision(system, dto.image, dto.mediaType, userText, 200);
    const parsed = this.parseJson(raw);
    const out: { [k: string]: number | string | null } = { raw };
    for (const k of keys) out[k] = this.coerceNumber(parsed?.[k]);
    return out;
  }

  // ── 공통 비전 호출 (OPENAI_API_KEY 있으면 OpenAI, 없으면 Anthropic) ──
  private async callVision(
    systemText: string,
    image: string,
    mediaType: string | undefined,
    userText: string,
    maxTokens: number,
  ): Promise<string> {
    const openaiKey = this.config.get<string>('OPENAI_API_KEY');
    const anthropicKey = this.config.get<string>('ANTHROPIC_API_KEY');
    if (openaiKey) return this.callOpenAI(openaiKey, systemText, image, mediaType, userText, maxTokens);
    if (anthropicKey) return this.callAnthropic(anthropicKey, systemText, image, mediaType, userText, maxTokens);
    throw new InternalServerErrorException(
      'AI 키(OPENAI_API_KEY 또는 ANTHROPIC_API_KEY)가 설정되지 않았습니다 (Railway 변수에 추가하세요)',
    );
  }

  private async callOpenAI(
    key: string,
    systemText: string,
    image: string,
    mediaType: string | undefined,
    userText: string,
    maxTokens: number,
  ): Promise<string> {
    const model = this.config.get<string>('OPENAI_MODEL', 'gpt-4o-mini');
    const body = {
      model,
      max_tokens: maxTokens,
      messages: [
        { role: 'system', content: systemText },
        {
          role: 'user',
          content: [
            { type: 'text', text: userText },
            { type: 'image_url', image_url: { url: `data:${mediaType || 'image/jpeg'};base64,${image}` } },
          ],
        },
      ],
    };
    let res: any;
    try {
      res = await fetch('https://api.openai.com/v1/chat/completions', {
        method: 'POST',
        headers: { authorization: `Bearer ${key}`, 'content-type': 'application/json' },
        body: JSON.stringify(body),
      });
    } catch {
      throw new InternalServerErrorException('AI 서버 연결에 실패했습니다');
    }
    if (!res.ok) throw new InternalServerErrorException(`AI 요청 실패 (${res.status})`);
    const data = await res.json();
    return (data?.choices?.[0]?.message?.content ?? '').trim();
  }

  private async callAnthropic(
    key: string,
    systemText: string,
    image: string,
    mediaType: string | undefined,
    userText: string,
    maxTokens: number,
  ): Promise<string> {
    const model = this.config.get<string>('ANTHROPIC_MODEL', 'claude-sonnet-4-6');
    const body = {
      model,
      max_tokens: maxTokens,
      system: [{ type: 'text', text: systemText, cache_control: { type: 'ephemeral' } }],
      messages: [
        {
          role: 'user',
          content: [
            { type: 'image', source: { type: 'base64', media_type: mediaType || 'image/jpeg', data: image } },
            { type: 'text', text: userText },
          ],
        },
      ],
    };
    let res: any;
    try {
      res = await fetch(API_URL, {
        method: 'POST',
        headers: { 'x-api-key': key, 'anthropic-version': '2023-06-01', 'content-type': 'application/json' },
        body: JSON.stringify(body),
      });
    } catch {
      throw new InternalServerErrorException('AI 서버 연결에 실패했습니다');
    }
    if (!res.ok) throw new InternalServerErrorException(`AI 요청 실패 (${res.status})`);
    const data = await res.json();
    return (data?.content?.[0]?.text ?? '').trim();
  }

  private parseNumber(raw: string): number | null {
    if (!raw || /^null$/i.test(raw.trim())) return null;
    const match = raw.replace(/,/g, '').match(/-?\d+(\.\d+)?/);
    if (!match) return null;
    const n = parseFloat(match[0]);
    return Number.isFinite(n) ? n : null;
  }

  private parseJson(raw: string): Record<string, any> | null {
    const m = raw.match(/\{[\s\S]*\}/);
    if (!m) return null;
    try {
      return JSON.parse(m[0]);
    } catch {
      return null;
    }
  }

  private coerceNumber(v: any): number | null {
    if (v == null) return null;
    if (typeof v === 'number') return Number.isFinite(v) ? v : null;
    if (typeof v === 'string') {
      const n = parseFloat(v.replace(/,/g, ''));
      return Number.isFinite(n) ? n : null;
    }
    return null;
  }
}
