import * as admin from 'firebase-admin';
import { onRequest } from 'firebase-functions/v2/https';
import { defineSecret, defineString } from 'firebase-functions/params';

import {
  AiVerifierAdapter,
  StorySnippet,
  VerifyOutput,
  createAiAdapter,
} from './adapter';
import { FirestoreRateLimiter, RateLimiter } from './rateLimit';

export const aiApiKeySecret = defineSecret('AI_API_KEY');
const aiProviderParam = defineString('AI_PROVIDER', { default: 'gemini' });
const aiModelParam = defineString('AI_MODEL', { default: 'gemini-2.0-flash' });
const aiEndpointParam = defineString('AI_ENDPOINT', { default: '' });

export interface HttpLikeRequest {
  method: string;
  headers: Record<string, string | string[] | undefined>;
  body: unknown;
}

export interface HttpLikeResponse {
  status(code: number): HttpLikeResponse;
  set(header: string, value: string): HttpLikeResponse;
  json(payload: unknown): void;
}

export interface ReflectionStoreWriter {
  saveScoredReflection(params: {
    uid: string;
    reflectionId: string;
    locationId: string;
    displayAuthor: string;
    isAnonymous: boolean;
    content: string;
    photoUrl: string | null;
    score: number;
  }): Promise<'saved' | 'forbidden'>;
}

export interface VerifyHandlerDeps {
  verifyIdToken(token: string): Promise<{ uid: string }>;
  rateLimiter: RateLimiter;
  adapter: AiVerifierAdapter;
  writer: ReflectionStoreWriter;
}

export class FirestoreReflectionWriter implements ReflectionStoreWriter {
  constructor(private readonly db: admin.firestore.Firestore) {}

  async saveScoredReflection(params: {
    uid: string;
    reflectionId: string;
    locationId: string;
    displayAuthor: string;
    isAnonymous: boolean;
    content: string;
    photoUrl: string | null;
    score: number;
  }): Promise<'saved' | 'forbidden'> {
    const ownerRef = this.db
      .collection('reflection_owners')
      .doc(params.reflectionId);
    const reflectionRef = this.db
      .collection('reflections')
      .doc(params.reflectionId);

    return this.db.runTransaction(async (tx) => {
      const ownerSnap = await tx.get(ownerRef);
      const existingOwnerUid = ownerSnap.data()?.uid as string | undefined;
      if (existingOwnerUid && existingOwnerUid !== params.uid) {
        return 'forbidden';
      }

      const reflectionSnap = await tx.get(reflectionRef);
      const now = admin.firestore.Timestamp.now();

      if (!ownerSnap.exists) {
        tx.set(ownerRef, { uid: params.uid });
      }

      if (reflectionSnap.exists) {
        tx.update(reflectionRef, {
          content: params.content,
          displayAuthor: params.displayAuthor,
          isAnonymous: params.isAnonymous,
          photoUrl: params.photoUrl,
          aiScore: params.score,
          updatedAt: now,
        });
      } else {
        tx.set(reflectionRef, {
          locationId: params.locationId,
          displayAuthor: params.displayAuthor,
          isAnonymous: params.isAnonymous,
          content: params.content,
          photoUrl: params.photoUrl,
          aiScore: params.score,
          createdAt: now,
        });
      }
      return 'saved';
    });
  }
}

function extractBearerToken(
  headers: Record<string, string | string[] | undefined>,
): string | null {
  const raw = headers.authorization ?? headers.Authorization;
  const header = Array.isArray(raw) ? raw[0] : raw;
  if (!header || !header.startsWith('Bearer ')) return null;
  const token = header.slice('Bearer '.length).trim();
  return token.length > 0 ? token : null;
}

function sanitizeStories(raw: unknown): StorySnippet[] {
  if (!Array.isArray(raw)) return [];
  return raw
    .slice(0, 6)
    .filter((item): item is Record<string, unknown> => !!item && typeof item === 'object')
    .map((item) => ({
      title: String(item.title ?? '').slice(0, 160),
      body: String(item.body ?? '').slice(0, 800),
    }));
}

function isValidPhotoUrl(value: unknown): value is string | null {
  if (value === null || value === undefined) return true;
  if (typeof value !== 'string') return false;
  if (value.length === 0 || value.length > 2048) return false;
  return /^https?:\/\//.test(value);
}

export async function handleVerifyReflection(
  req: HttpLikeRequest,
  res: HttpLikeResponse,
  deps: VerifyHandlerDeps,
): Promise<void> {
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Chỉ hỗ trợ phương thức POST.' });
    return;
  }

  const token = extractBearerToken(req.headers);
  if (!token) {
    res.status(401).json({ error: 'Thiếu Firebase ID Token trong header Authorization.' });
    return;
  }

  let uid: string;
  try {
    const decoded = await deps.verifyIdToken(token);
    uid = decoded.uid;
  } catch {
    res.status(401).json({ error: 'Firebase ID Token không hợp lệ hoặc đã hết hạn.' });
    return;
  }

  const limit = await deps.rateLimiter.consume(uid);
  if (!limit.allowed) {
    res
      .status(429)
      .set('Retry-After', String(limit.retryAfterSeconds ?? 60))
      .json({
        error: 'Bạn gửi yêu cầu quá nhanh. Vui lòng thử lại sau ít phút.',
        retryAfterSeconds: limit.retryAfterSeconds ?? 60,
      });
    return;
  }

  const body = (req.body ?? {}) as Record<string, unknown>;
  const content = typeof body.content === 'string' ? body.content.trim() : '';
  const locationId =
    typeof body.locationId === 'string' ? body.locationId.trim() : '';
  const locationName =
    typeof body.locationName === 'string' ? body.locationName.trim() : locationId;
  const hasPhoto = body.hasPhoto === true;
  const reflectionId =
    typeof body.reflectionId === 'string' && body.reflectionId.trim().length > 0
      ? body.reflectionId.trim()
      : null;
  const displayAuthor =
    typeof body.displayAuthor === 'string' && body.displayAuthor.trim().length > 0
      ? body.displayAuthor.trim().slice(0, 80)
      : 'Một Lữ khách Ẩn danh';
  const isAnonymous = body.isAnonymous === true;
  const photoUrl = body.photoUrl === undefined ? null : body.photoUrl;

  if (content.length < 5 || content.length > 2000) {
    res.status(400).json({ error: 'Nội dung cảm nhận phải từ 5 đến 2000 ký tự.' });
    return;
  }
  if (!locationId || locationId.length > 80) {
    res.status(400).json({ error: 'Thiếu hoặc sai định dạng locationId.' });
    return;
  }
  if (reflectionId && !/^[a-zA-Z0-9_-]{3,80}$/.test(reflectionId)) {
    res.status(400).json({ error: 'reflectionId không hợp lệ.' });
    return;
  }
  if (!isValidPhotoUrl(photoUrl)) {
    res.status(400).json({ error: 'photoUrl phải là URL HTTP/HTTPS hợp lệ.' });
    return;
  }

  let result: VerifyOutput;
  try {
    result = await deps.adapter.scoreReflection({
      content,
      hasPhoto: hasPhoto || photoUrl !== null,
      locationId,
      locationName,
      stories: sanitizeStories(body.stories),
    });
  } catch (err) {
    console.error('Lỗi chấm điểm AI:', err);
    res.status(502).json({ error: 'Dịch vụ AI tạm thời không phản hồi.' });
    return;
  }

  if (result.approved && reflectionId) {
    const status = await deps.writer.saveScoredReflection({
      uid,
      reflectionId,
      locationId,
      displayAuthor,
      isAnonymous,
      content,
      photoUrl: photoUrl ?? null,
      score: result.score,
    });
    if (status === 'forbidden') {
      res.status(403).json({ error: 'Bạn không phải chủ sở hữu bài cảm nhận này.' });
      return;
    }
  }

  res.status(200).json({
    score: result.score,
    approved: result.approved,
    soulmate: result.soulmate,
    bonusXp: result.bonusXp,
    comment: result.comment,
    isAi: result.isAi,
    adapter: result.adapter,
    reflectionId,
  });
}

export const verifyReflection = onRequest(
  {
    region: 'asia-southeast1',
    cors: true,
    secrets: [aiApiKeySecret],
    timeoutSeconds: 30,
  },
  async (req, res) => {
    const db = admin.firestore();
    const maxPerMinute = Number(process.env.AI_RATE_LIMIT_PER_MIN || 10);
    const rateLimiter = new FirestoreRateLimiter(db, {
      maxRequests: Number.isFinite(maxPerMinute) && maxPerMinute > 0 ? maxPerMinute : 10,
      windowMs: 60_000,
    });
    const adapter = createAiAdapter({
      provider: aiProviderParam.value() || process.env.AI_PROVIDER || 'gemini',
      model: aiModelParam.value() || process.env.AI_MODEL || 'gemini-2.0-flash',
      endpoint: aiEndpointParam.value() || process.env.AI_ENDPOINT || undefined,
      apiKey: aiApiKeySecret.value() || process.env.AI_API_KEY,
    });
    const writer = new FirestoreReflectionWriter(db);

    await handleVerifyReflection(req, res, {
      verifyIdToken: (token) => admin.auth().verifyIdToken(token),
      rateLimiter,
      adapter,
      writer,
    });
  },
);
