export interface StorySnippet {
  title: string;
  body: string;
}

export interface VerifyInput {
  content: string;
  hasPhoto: boolean;
  locationId: string;
  locationName: string;
  stories: StorySnippet[];
}

export interface VerifyOutput {
  score: number;
  approved: boolean;
  soulmate: boolean;
  bonusXp: number;
  comment: string;
  isAi: boolean;
  adapter: string;
}

export interface AiVerifierAdapter {
  readonly name: string;
  scoreReflection(input: VerifyInput): Promise<VerifyOutput>;
}

export interface AiAdapterConfig {
  provider: string;
  model: string;
  endpoint?: string;
  apiKey?: string;
  fetchImpl?: typeof fetch;
}

function clampInt(value: unknown, min: number, max: number, fallback: number): number {
  const n = typeof value === 'number' ? value : Number(value);
  if (!Number.isFinite(n)) return fallback;
  return Math.max(min, Math.min(max, Math.round(n)));
}

function buildPrompt(input: VerifyInput): string {
  const storyContext = input.stories
    .slice(0, 5)
    .map((s, i) => `${i + 1}. ${s.title}: ${s.body}`)
    .join('\n');

  return [
    'Bạn là giám khảo văn hóa địa phương cho ứng dụng Local Passport Đà Nẵng.',
    'Hãy đánh giá bài cảm nhận của du khách sau khi tham quan di tích.',
    `Địa điểm: ${input.locationName} (${input.locationId})`,
    `Có ảnh đính kèm: ${input.hasPhoto ? 'Có' : 'Không'}`,
    storyContext ? `Câu chuyện tại di tích:\n${storyContext}` : '',
    `Cảm nhận của người dùng:\n"""\n${input.content}\n"""`,
    'Tiêu chí chấm điểm (0-100):',
    '- Chân thực, có trải nghiệm thực tế và cảm xúc cá nhân.',
    '- Liên hệ được với câu chuyện lịch sử/văn hóa của di tích.',
    '- Không spam, không vô nghĩa, không xúc phạm.',
    'Trả về DUY NHẤT JSON hợp lệ theo mẫu:',
    '{"score": 0-100, "approved": true/false, "soulmate": true/false, "bonusXp": 0-50, "comment": "Nhận xét ngắn tiếng Việt (1-2 câu)"}',
  ]
    .filter(Boolean)
    .join('\n\n');
}

function parseAiJsonResponse(rawText: string, adapterName: string): VerifyOutput {
  const cleaned = rawText
    .trim()
    .replace(/^```(?:json)?\s*/i, '')
    .replace(/\s*```$/i, '')
    .trim();
  const parsed = JSON.parse(cleaned) as Record<string, unknown>;
  const score = clampInt(parsed.score, 0, 100, 0);
  const approved = typeof parsed.approved === 'boolean' ? parsed.approved : score >= 30;
  const soulmate = typeof parsed.soulmate === 'boolean' ? parsed.soulmate : score >= 70;
  const bonusXp = clampInt(
    parsed.bonusXp,
    0,
    500,
    approved ? Math.round(score / 2) : 0,
  );
  const comment =
    typeof parsed.comment === 'string' && parsed.comment.trim().length > 0
      ? parsed.comment.trim().slice(0, 400)
      : approved
        ? 'Cảm ơn bạn đã chia sẻ cảm nhận chân thực về di tích.'
        : 'Cảm nhận chưa đủ chi tiết, hãy viết thêm một chút nhé.';
  return {
    score,
    approved,
    soulmate,
    bonusXp,
    comment,
    isAi: true,
    adapter: adapterName,
  };
}

/**
 * Adapter gọi Google Gemini Generative Language REST API.
 * Đọc model/endpoint từ biến cấu hình và API key từ Secret Manager.
 */
export class GeminiAiAdapter implements AiVerifierAdapter {
  readonly name = 'gemini';

  constructor(
    private readonly apiKey: string,
    private readonly model: string,
    private readonly endpoint?: string,
    private readonly fetchImpl: typeof fetch = fetch,
  ) {}

  async scoreReflection(input: VerifyInput): Promise<VerifyOutput> {
    const base =
      this.endpoint ||
      `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(
        this.model,
      )}:generateContent`;
    const url = `${base}${base.includes('?') ? '&' : '?'}key=${encodeURIComponent(
      this.apiKey,
    )}`;

    const response = await this.fetchImpl(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        contents: [{ role: 'user', parts: [{ text: buildPrompt(input) }] }],
        generationConfig: {
          temperature: 0.2,
          responseMimeType: 'application/json',
        },
      }),
    });

    if (!response.ok) {
      throw new Error(`Gemini API lỗi (${response.status})`);
    }
    const body = (await response.json()) as {
      candidates?: Array<{ content?: { parts?: Array<{ text?: string }> } }>;
    };
    const text = body.candidates?.[0]?.content?.parts?.[0]?.text;
    if (!text) {
      throw new Error('Gemini API không trả về nội dung chấm điểm.');
    }
    return parseAiJsonResponse(text, this.name);
  }
}

/**
 * Adapter tương thích chuẩn OpenAI Chat Completions (OpenAI, Vertex OpenAI-compat,
 * Ollama/vLLM...) cho phép đổi mô hình/endpoint chỉ qua biến môi trường.
 */
export class OpenAiCompatibleAdapter implements AiVerifierAdapter {
  readonly name = 'openai-compatible';

  constructor(
    private readonly apiKey: string,
    private readonly model: string,
    private readonly endpoint: string,
    private readonly fetchImpl: typeof fetch = fetch,
  ) {}

  async scoreReflection(input: VerifyInput): Promise<VerifyOutput> {
    const response = await this.fetchImpl(this.endpoint, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${this.apiKey}`,
      },
      body: JSON.stringify({
        model: this.model,
        temperature: 0.2,
        response_format: { type: 'json_object' },
        messages: [
          {
            role: 'system',
            content: 'Chỉ trả về JSON hợp lệ theo đúng cấu trúc được yêu cầu.',
          },
          { role: 'user', content: buildPrompt(input) },
        ],
      }),
    });

    if (!response.ok) {
      throw new Error(`AI endpoint lỗi (${response.status})`);
    }
    const body = (await response.json()) as {
      choices?: Array<{ message?: { content?: string } }>;
    };
    const text = body.choices?.[0]?.message?.content;
    if (!text) {
      throw new Error('AI endpoint không trả về nội dung chấm điểm.');
    }
    return parseAiJsonResponse(text, this.name);
  }
}

/**
 * Adapter dự phòng phía server dùng khi chạy Emulator/môi trường phát triển
 * chưa cấu hình AI_API_KEY. Vẫn chạy hoàn toàn ở server và ghi điểm bằng Admin SDK.
 */
export class HeuristicFallbackAdapter implements AiVerifierAdapter {
  readonly name = 'heuristic-server';

  async scoreReflection(input: VerifyInput): Promise<VerifyOutput> {
    const text = input.content.trim().toLowerCase();
    const words = text.split(/\s+/).filter(Boolean).length;
    const splitter = /[^\p{L}\d]+/u;
    const keywords = new Set(
      input.stories
        .flatMap((s) => `${s.title} ${s.body}`.toLowerCase().split(splitter))
        .filter((w) => w.length >= 4),
    );
    const hits = new Set(
      text.split(splitter).filter((w) => keywords.has(w)),
    ).size;

    let raw = 35 + Math.min(words, 60) * 0.6 + Math.min(hits, 6) * 4 + (input.hasPhoto ? 8 : 0);
    if (words < 5) raw = Math.min(raw, 30);
    const score = Math.min(Math.round(raw), 98);
    const approved = score >= 30;
    const soulmate = score >= 70;
    const bonusXp = approved ? Math.round(score / 2) : 0;
    const comment = soulmate
      ? 'Cảm nhận sâu sắc, có liên hệ với câu chuyện của di tích.'
      : approved
        ? 'Cảm ơn bạn đã chia sẻ! Thêm chi tiết về điều bạn học được để nhận huy hiệu Tri kỷ.'
        : 'Cảm nhận hơi ngắn, hãy kể thêm một chút nhé.';

    return {
      score,
      approved,
      soulmate,
      bonusXp,
      comment,
      isAi: false,
      adapter: this.name,
    };
  }
}

export function createAiAdapter(config: AiAdapterConfig): AiVerifierAdapter {
  const provider = config.provider.trim().toLowerCase();
  const apiKey = config.apiKey?.trim() ?? '';

  if (provider === 'heuristic' || apiKey.length === 0) {
    return new HeuristicFallbackAdapter();
  }
  if (provider === 'openai' || provider === 'openai-compatible') {
    const endpoint =
      config.endpoint?.trim() || 'https://api.openai.com/v1/chat/completions';
    return new OpenAiCompatibleAdapter(
      apiKey,
      config.model,
      endpoint,
      config.fetchImpl,
    );
  }
  return new GeminiAiAdapter(
    apiKey,
    config.model,
    config.endpoint?.trim() || undefined,
    config.fetchImpl,
  );
}
