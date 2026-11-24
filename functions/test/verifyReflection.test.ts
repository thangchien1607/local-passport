import assert from 'node:assert/strict';
import test from 'node:test';

import {
  AiVerifierAdapter,
  HeuristicFallbackAdapter,
  createAiAdapter,
} from '../src/ai/adapter';
import { RateLimiter } from '../src/ai/rateLimit';
import {
  HttpLikeRequest,
  HttpLikeResponse,
  ReflectionStoreWriter,
  handleVerifyReflection,
} from '../src/ai/verifyReflection';

function createMockResponse() {
  let statusCode = 200;
  const headers: Record<string, string> = {};
  let body: unknown = null;

  const res: HttpLikeResponse = {
    status(code: number) {
      statusCode = code;
      return this;
    },
    set(header: string, value: string) {
      headers[header] = value;
      return this;
    },
    json(payload: unknown) {
      body = payload;
    },
  };

  return {
    res,
    getStatus: () => statusCode,
    getHeaders: () => headers,
    getBody: () => body as Record<string, unknown>,
  };
}

function createDeps(overrides?: {
  verifyIdToken?: (t: string) => Promise<{ uid: string }>;
  rateLimiter?: RateLimiter;
  adapter?: AiVerifierAdapter;
  writer?: ReflectionStoreWriter;
}) {
  const saved: Array<Record<string, unknown>> = [];
  const deps = {
    verifyIdToken:
      overrides?.verifyIdToken ??
      (async (token: string) => {
        if (token === 'valid-token') return { uid: 'uid-1' };
        throw new Error('invalid token');
      }),
    rateLimiter:
      overrides?.rateLimiter ??
      ({
        async consume() {
          return { allowed: true, remaining: 9 };
        },
      } satisfies RateLimiter),
    adapter: overrides?.adapter ?? new HeuristicFallbackAdapter(),
    writer:
      overrides?.writer ??
      ({
        async saveScoredReflection(params) {
          saved.push(params);
          return 'saved';
        },
      } satisfies ReflectionStoreWriter),
  };
  return { deps, saved };
}

test('Trả 401 khi thiếu Authorization Bearer token', async () => {
  const { deps } = createDeps();
  const mock = createMockResponse();
  const req: HttpLikeRequest = {
    method: 'POST',
    headers: {},
    body: { content: 'Cảm nhận dài hợp lệ tại Thành Điện Hải.', locationId: 'dien-hai' },
  };
  await handleVerifyReflection(req, mock.res, deps);
  assert.equal(mock.getStatus(), 401);
});

test('Trả 401 khi Firebase ID Token không hợp lệ', async () => {
  const { deps } = createDeps();
  const mock = createMockResponse();
  const req: HttpLikeRequest = {
    method: 'POST',
    headers: { authorization: 'Bearer invalid-token' },
    body: { content: 'Cảm nhận dài hợp lệ tại Thành Điện Hải.', locationId: 'dien-hai' },
  };
  await handleVerifyReflection(req, mock.res, deps);
  assert.equal(mock.getStatus(), 401);
});

test('Trả 429 khi vượt rate limit theo uid', async () => {
  const { deps } = createDeps({
    rateLimiter: {
      async consume() {
        return { allowed: false, retryAfterSeconds: 45, remaining: 0 };
      },
    },
  });
  const mock = createMockResponse();
  const req: HttpLikeRequest = {
    method: 'POST',
    headers: { authorization: 'Bearer valid-token' },
    body: { content: 'Cảm nhận dài hợp lệ tại Thành Điện Hải.', locationId: 'dien-hai' },
  };
  await handleVerifyReflection(req, mock.res, deps);
  assert.equal(mock.getStatus(), 429);
  assert.equal(mock.getHeaders()['Retry-After'], '45');
});

test('Chấm điểm thành công và tự ghi aiScore vào Firestore bằng Admin writer', async () => {
  const { deps, saved } = createDeps();
  const mock = createMockResponse();
  const req: HttpLikeRequest = {
    method: 'POST',
    headers: { authorization: 'Bearer valid-token' },
    body: {
      reflectionId: 'r12345',
      locationId: 'dien-hai',
      locationName: 'Thành Điện Hải',
      displayAuthor: 'Minh Anh',
      isAnonymous: false,
      photoUrl: 'https://firebasestorage.googleapis.com/v0/b/test/o/p.jpg',
      content: 'Đứng trên tường thành Điện Hải nhìn thẳng ra cửa sông Hàn rất xúc động.',
      stories: [{ title: 'Thành Điện Hải', body: 'Pháo đài cổ bên sông Hàn Đà Nẵng.' }],
    },
  };
  await handleVerifyReflection(req, mock.res, deps);
  assert.equal(mock.getStatus(), 200);
  const body = mock.getBody();
  assert.equal(body.approved, true);
  assert.equal(typeof body.score, 'number');
  assert.equal(saved.length, 1);
  assert.equal(saved[0].uid, 'uid-1');
  assert.equal(saved[0].reflectionId, 'r12345');
  assert.equal(saved[0].score, body.score);
});

test('Trả 403 nếu reflectionId thuộc người dùng khác', async () => {
  const { deps } = createDeps({
    writer: {
      async saveScoredReflection() {
        return 'forbidden';
      },
    },
  });
  const mock = createMockResponse();
  const req: HttpLikeRequest = {
    method: 'POST',
    headers: { authorization: 'Bearer valid-token' },
    body: {
      reflectionId: 'r-other',
      locationId: 'dien-hai',
      content: 'Cảm nhận dài hợp lệ để kiểm tra quyền sở hữu bài viết.',
    },
  };
  await handleVerifyReflection(req, mock.res, deps);
  assert.equal(mock.getStatus(), 403);
});

test('createAiAdapter chọn đúng adapter theo cấu hình', () => {
  assert.equal(
    createAiAdapter({ provider: 'gemini', model: 'gemini-2.0-flash', apiKey: '' }).name,
    'heuristic-server',
  );
  assert.equal(
    createAiAdapter({ provider: 'gemini', model: 'gemini-2.0-flash', apiKey: 'test-key' }).name,
    'gemini',
  );
  assert.equal(
    createAiAdapter({ provider: 'openai', model: 'gpt-4o-mini', apiKey: 'test-key' }).name,
    'openai-compatible',
  );
});
