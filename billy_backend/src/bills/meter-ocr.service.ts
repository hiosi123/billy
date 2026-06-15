import { Injectable, InternalServerErrorException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { ReadMeterDto } from './dto/read-meter.dto';
import { ReadBillDto } from './dto/read-bill.dto';
import { ReadBillAutoDto } from './dto/read-bill-auto.dto';
import { ReadBillElecDto } from './dto/read-bill-elec.dto';

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

    const raw = await this.callVision(system, [{ image: dto.image, mediaType: dto.mediaType }], userText, 50);
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
        '이 수도요금 고지서의 "내역" 표를 보고 다음 값을 정확히 추출해 JSON으로만 답하세요.\n' +
        '표는 보통 [내역 | 상수도 | 하수도(지하수) | 물이용부담금 | 계] 열로 되어 있습니다.\n' +
        '- "waterSupplyCost": "상수도" 열의 "사용요금" 행 값(원). (상수도=수돗물 공급)\n' +
        '- "waterSewerCost": "하수도" 또는 "하수도(지하수)" 열의 "사용요금" 행 값(원). 보통 상수도보다 큼.\n' +
        '- "waterTotalUsage": 당월 물 사용량(톤). "사용량 비교"의 당월 상수도 값.\n' +
        '- "waterTotalCost": 당월 청구금액 "계"(전체 합계, 원).\n' +
        '⚠️ 상수도와 하수도 값을 절대 바꿔 쓰지 마세요. 물이용부담금은 사용요금이 아닙니다. 못 찾으면 null.\n' +
        '콤마 제거하고 정수로. 순수 JSON만 출력.';
    } else {
      keys = ['electricityTotalCost', 'electricityTotalUsage'];
      system =
        '당신은 한국전력 전기요금 고지서 사진에서 숫자 항목을 추출하는 도우미입니다. ' +
        '반드시 JSON 한 개만 출력하세요. 설명/코드블록 없이 순수 JSON.';
      userText =
        '이 한국전력 전기요금 고지서에서 정확히 2개 값을 추출해 JSON으로만 답하세요.\n' +
        '\n' +
        '① "electricityTotalCost" = 전기요금계(원). 아래 2가지로 교차 확인해 또렷한 값을 쓰세요(둘은 항상 같음).\n' +
        '   (a) ★1순위★ "전자세금계산서" 박스의 "공급가액" 옆 숫자. ← 깨끗한 표라 가장 정확.\n' +
        '   (b) "청구내역" 표의 "전기요금계" 글자 옆 숫자.\n' +
        '   - 🚫 절대 쓰면 안 되는 더 큰 숫자: "청구금액"·"금액"(맨아래 총액)·"영수금액"·"수납금액"·"당월요금계"·부가가치세·전력기금·TV수신료.\n' +
        '   - 크기 순서는 (전기요금계=공급가액) < (당월요금계) < (청구금액). 가장 작은 값이 정답.\n' +
        '   - 추측 금지. 또렷이 못 읽으면 null.\n' +
        '\n' +
        '② "electricityTotalUsage" = 당월 전기 사용량(kWh).\n' +
        '   - 위치: "사용량 비교"의 "당월" 값, 또는 "계절별 사용량"의 "계", 또는 사용량 그래프 당월값.\n' +
        '   - 단위는 kWh(전력량)이며 금액(원)이 아닙니다. 못 읽으면 null.\n' +
        '\n' +
        '콤마 제거하고 정수로. 설명 없이 순수 JSON만 출력.';
    }

    const raw = await this.callVision(system, [{ image: dto.image, mediaType: dto.mediaType }], userText, 200, true);
    const parsed = this.parseJson(raw);
    const out: { [k: string]: number | string | null } = { raw };
    for (const k of keys) out[k] = this.coerceNumber(parsed?.[k]);
    return out;
  }

  // ── 3. 고지서 사진 → 수도/전기 자동 판별 + 항목 추출 ───────────────────
  // (수도·전기 구분 없이 여러 장 업로드할 때 한 장씩 호출)
  async readBillAuto(dto: ReadBillAutoDto): Promise<{ type: 'water' | 'electricity' | null; [k: string]: number | string | null }> {
    const system =
      '당신은 한국 공공요금 고지서(수도 또는 전기) 사진을 판별하고 숫자 항목을 추출하는 도우미입니다. ' +
      '반드시 JSON 한 개만 출력하세요. 설명/코드블록 없이 순수 JSON.';
    const userText =
      '이 고지서가 "수도(상수도)" 요금인지 "전기(한국전력)" 요금인지 먼저 판별한 뒤, 해당 항목만 추출해 JSON으로만 답하세요.\n' +
      '반드시 "type" 필드에 "water" 또는 "electricity" 를 넣으세요.\n' +
      '\n' +
      '[수도(상수도)이면] type="water" 이고 아래 필드를 채웁니다.\n' +
      '  표는 보통 [내역 | 상수도 | 하수도(지하수) | 물이용부담금 | 계] 열입니다.\n' +
      '  - "waterSupplyCost": "상수도" 열의 "사용요금" 행 값(원).\n' +
      '  - "waterSewerCost": "하수도(지하수)" 열의 "사용요금" 행 값(원). 보통 상수도보다 큼.\n' +
      '  - "waterTotalUsage": 당월 물 사용량(톤). "사용량 비교"의 당월 상수도 값.\n' +
      '  - "waterTotalCost": 당월 청구금액 "계"(전체 합계, 원).\n' +
      '  ⚠️ 상수도/하수도 값을 절대 바꿔 쓰지 마세요. 물이용부담금은 사용요금이 아닙니다.\n' +
      '\n' +
      '[전기(한국전력)이면] type="electricity" 이고 아래 필드를 채웁니다.\n' +
      '  - "electricityTotalCost": 전기요금계(원). "전자세금계산서"의 "공급가액" 옆 숫자(1순위) = "청구내역"의 "전기요금계" 옆 숫자(둘은 같음).\n' +
      '      🚫 더 큰 숫자 금지: "영수금액"·"청구금액"·"금액"·"수납금액"·"당월요금계"·부가세·전력기금·TV수신료.\n' +
      '  - "electricityTotalUsage": 당월 사용량(kWh). "사용량 비교" 당월 또는 "계절별 사용량"의 "계".\n' +
      '\n' +
      '콤마 제거하고 정수로. 판별된 type의 필드만 채워 순수 JSON만 출력.';

    const raw = await this.callVision(system, [{ image: dto.image, mediaType: dto.mediaType }], userText, 300, true);
    const parsed = this.parseJson(raw);
    const type = parsed?.type === 'water' || parsed?.type === 'electricity' ? parsed.type : null;
    const out: { type: 'water' | 'electricity' | null; [k: string]: number | string | null } = { type, raw };
    const keys =
      type === 'water'
        ? ['waterTotalUsage', 'waterSupplyCost', 'waterSewerCost', 'waterTotalCost']
        : type === 'electricity'
          ? ['electricityTotalCost', 'electricityTotalUsage']
          : [];
    for (const k of keys) out[k] = this.coerceNumber(parsed?.[k]);
    return out;
  }

  // ── 4. 전기 고지서 여러 장(청구서+내역서) → 전기요금계 + 당월 사용량 ──
  // 전기 고지서는 보통 2장으로 나뉘어, 한 장에 전기요금계, 다른 장에 당월 사용량이 있다.
  // 모든 이미지를 한 번에 보고 두 값을 종합 추출한다.
  async readBillElec(
    dto: ReadBillElecDto,
  ): Promise<{ electricityTotalCost: number | null; electricityTotalUsage: number | null; raw: string }> {
    const system =
      '당신은 한국전력 전기요금 고지서 여러 장(청구서+내역서)을 함께 보고 숫자 항목을 추출하는 도우미입니다. ' +
      '반드시 JSON 한 개만 출력하세요. 설명/코드블록 없이 순수 JSON.';
    const userText =
      '제공된 전기요금 고지서 이미지들(보통 청구서 1장 + 내역서 1장)을 모두 종합해 정확히 2개 값을 추출해 JSON으로만 답하세요.\n' +
      '\n' +
      '① "electricityTotalCost" = 전기요금계(원). 아래 2가지로 교차 확인해 가장 또렷한 값을 쓰세요. (둘은 항상 같은 값)\n' +
      '   (a) ★1순위★ "전자세금계산서" 라는 박스 안의 "공급가액" 옆 숫자. ← 깨끗한 표라 가장 정확합니다.\n' +
      '   (b) "청구내역" 표의 "전기요금계" 글자 옆 숫자.\n' +
      '   - (a)공급가액 과 (b)전기요금계 는 반드시 일치합니다. 둘 다 확인해 같은 숫자를 고르세요.\n' +
      '   - 🚫 절대 쓰면 안 되는 더 큰 숫자들: "청구금액"·"금액"(맨아래 큰 총액)·"영수금액"·"수납금액"·"당월요금계"·부가가치세·전력기금·TV수신료.\n' +
      '   - 크기 순서: (전기요금계=공급가액) < (당월요금계) < (청구금액). 가장 작은 전기요금계가 정답.\n' +
      '   - 추측 금지. 공급가액/전기요금계 어느 쪽도 또렷이 못 읽으면 null.\n' +
      '\n' +
      '② "electricityTotalUsage" = 당월 전기 사용량(kWh).\n' +
      '   - 내역서의 "계절별 사용량"의 "계", 또는 "사용량 비교"의 "당월" 값. 단위는 kWh(원 아님).\n' +
      '\n' +
      '두 값은 서로 다른 페이지에 있을 수 있으니 모든 이미지를 살펴보세요. 못 찾는 값만 null.\n' +
      '콤마 제거, 정수. 순수 JSON만.';

    const images = (dto.images || []).map((img) => ({ image: img, mediaType: dto.mediaType }));
    const raw = await this.callVision(system, images, userText, 300, true);
    const parsed = this.parseJson(raw);
    return {
      electricityTotalCost: this.coerceNumber(parsed?.electricityTotalCost),
      electricityTotalUsage: this.coerceNumber(parsed?.electricityTotalUsage),
      raw,
    };
  }

  // ── 공통 비전 호출 (이미지 1장 이상). OPENAI 우선, 없으면 ANTHROPIC ──
  // strong=true 면 고지서 표 인식용 상위 모델(gpt-4o)을 쓴다(계량기 숫자는 false).
  private async callVision(
    systemText: string,
    images: { image: string; mediaType?: string }[],
    userText: string,
    maxTokens: number,
    strong = false,
  ): Promise<string> {
    const openaiKey = this.config.get<string>('OPENAI_API_KEY');
    const anthropicKey = this.config.get<string>('ANTHROPIC_API_KEY');
    if (openaiKey) return this.callOpenAI(openaiKey, systemText, images, userText, maxTokens, strong);
    if (anthropicKey) return this.callAnthropic(anthropicKey, systemText, images, userText, maxTokens, strong);
    throw new InternalServerErrorException(
      'AI 키(OPENAI_API_KEY 또는 ANTHROPIC_API_KEY)가 설정되지 않았습니다 (Railway 변수에 추가하세요)',
    );
  }

  private async callOpenAI(
    key: string,
    systemText: string,
    images: { image: string; mediaType?: string }[],
    userText: string,
    maxTokens: number,
    strong = false,
  ): Promise<string> {
    const model = strong
      ? this.config.get<string>('OPENAI_BILL_MODEL', 'gpt-4o')
      : this.config.get<string>('OPENAI_MODEL', 'gpt-4o-mini');
    const body = {
      model,
      max_tokens: maxTokens,
      messages: [
        { role: 'system', content: systemText },
        {
          role: 'user',
          content: [
            { type: 'text', text: userText },
            ...images.map((img) => ({
              type: 'image_url',
              image_url: { url: `data:${img.mediaType || 'image/jpeg'};base64,${img.image}` },
            })),
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
    images: { image: string; mediaType?: string }[],
    userText: string,
    maxTokens: number,
    strong = false,
  ): Promise<string> {
    const model = strong
      ? this.config.get<string>('ANTHROPIC_BILL_MODEL', 'claude-sonnet-4-6')
      : this.config.get<string>('ANTHROPIC_MODEL', 'claude-sonnet-4-6');
    const body = {
      model,
      max_tokens: maxTokens,
      system: [{ type: 'text', text: systemText, cache_control: { type: 'ephemeral' } }],
      messages: [
        {
          role: 'user',
          content: [
            ...images.map((img) => ({
              type: 'image',
              source: { type: 'base64', media_type: img.mediaType || 'image/jpeg', data: img.image },
            })),
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
