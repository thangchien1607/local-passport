import * as admin from 'firebase-admin';
import { onDocumentUpdated } from 'firebase-functions/v2/firestore';
import { defineString } from 'firebase-functions/params';

import { AiVerifierAdapter, createAiAdapter } from './adapter';
import { aiApiKeySecret } from './verifyReflection';

const aiProviderParam = defineString('AI_PROVIDER', { default: 'gemini' });
const aiModelParam = defineString('AI_MODEL', { default: 'gemini-2.0-flash' });
const aiEndpointParam = defineString('AI_ENDPOINT', { default: '' });

export interface ReflectionDocData {
  locationId?: string;
  content?: string;
  photoUrl?: string | null;
  aiScore?: number;
}

export interface ReflectionRescoreWriter {
  updateScore(reflectionId: string, score: number): Promise<void>;
}

/**
 * Quyết định xem thay đổi trên `reflections/{id}` có cần kích hoạt chấm lại AI
 * không. Tránh vòng lặp vô hạn bằng cách chỉ chấm lại khi `content` hoặc
 * `photoUrl` đổi VÀ `aiScore` chưa được cập nhật trong cùng lần ghi.
 */
export function shouldRescoreReflection(
  before: ReflectionDocData | undefined,
  after: ReflectionDocData | undefined,
): boolean {
  if (!before || !after) return false;
  const contentChanged = (before.content ?? '') !== (after.content ?? '');
  const photoChanged = (before.photoUrl ?? null) !== (after.photoUrl ?? null);
  if (!contentChanged && !photoChanged) return false;
  // Nếu aiScore cũng vừa thay đổi (do verifyReflection ghi trực tiếp), không chấm lặp lại.
  if (before.aiScore !== after.aiScore) return false;
  const content = (after.content ?? '').trim();
  return content.length >= 5 && typeof after.locationId === 'string';
}

export async function handleReflectionUpdatedForRescore(
  reflectionId: string,
  before: ReflectionDocData | undefined,
  after: ReflectionDocData | undefined,
  adapter: AiVerifierAdapter,
  writer: ReflectionRescoreWriter,
): Promise<boolean> {
  if (!shouldRescoreReflection(before, after) || !after) {
    return false;
  }
  const result = await adapter.scoreReflection({
    content: (after.content ?? '').trim(),
    hasPhoto: Boolean(after.photoUrl),
    locationId: after.locationId ?? '',
    locationName: after.locationId ?? '',
    stories: [],
  });
  await writer.updateScore(reflectionId, result.score);
  return true;
}

export const rescoreReflectionOnUpdate = onDocumentUpdated(
  {
    document: 'reflections/{reflectionId}',
    region: 'asia-southeast1',
    secrets: [aiApiKeySecret],
  },
  async (event) => {
    const before = event.data?.before.data() as ReflectionDocData | undefined;
    const after = event.data?.after.data() as ReflectionDocData | undefined;
    const reflectionId = event.params.reflectionId;

    const adapter = createAiAdapter({
      provider: aiProviderParam.value() || process.env.AI_PROVIDER || 'gemini',
      model: aiModelParam.value() || process.env.AI_MODEL || 'gemini-2.0-flash',
      endpoint: aiEndpointParam.value() || process.env.AI_ENDPOINT || undefined,
      apiKey: aiApiKeySecret.value() || process.env.AI_API_KEY,
    });

    const db = admin.firestore();
    await handleReflectionUpdatedForRescore(reflectionId, before, after, adapter, {
      async updateScore(id, score) {
        await db.collection('reflections').doc(id).update({
          aiScore: score,
          aiRescoredAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      },
    });
  },
);
