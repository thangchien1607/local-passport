import assert from 'node:assert/strict';
import test from 'node:test';

import { HttpLikeRequest, HttpLikeResponse } from '../src/ai/verifyReflection';
import { handleDeleteAccount } from '../src/auth/deleteAccount';

function createMockResponse() {
  let statusCode = 200;
  let body: unknown = null;
  const res: HttpLikeResponse = {
    status(code: number) {
      statusCode = code;
      return this;
    },
    set() {
      return this;
    },
    json(payload: unknown) {
      body = payload;
    },
  };
  return {
    res,
    getStatus: () => statusCode,
    getBody: () => body as Record<string, unknown>,
  };
}

test('deleteUserAccountData trả 401 khi thiếu hoặc sai ID token', async () => {
  const mock = createMockResponse();
  const req: HttpLikeRequest = { method: 'POST', headers: {}, body: {} };
  await handleDeleteAccount(req, mock.res, {
    verifyIdToken: async () => {
      throw new Error('invalid');
    },
    cleaner: {
      deleteAllUserData: async () => ({
        visitsDeleted: 0,
        notificationsDeleted: 0,
        reflectionsDeleted: 0,
        storagePrefixCleared: '',
      }),
      deleteAuthUser: async () => {},
    },
  });
  assert.equal(mock.getStatus(), 401);
});

test('deleteUserAccountData dọn sạch Firestore, Storage và xóa Auth user của đúng uid', async () => {
  const calls: string[] = [];
  const mock = createMockResponse();
  const req: HttpLikeRequest = {
    method: 'POST',
    headers: { authorization: 'Bearer valid-token' },
    body: {},
  };

  await handleDeleteAccount(req, mock.res, {
    verifyIdToken: async () => ({ uid: 'uid-del-1' }),
    cleaner: {
      async deleteAllUserData(uid) {
        calls.push(`data:${uid}`);
        return {
          visitsDeleted: 3,
          notificationsDeleted: 5,
          reflectionsDeleted: 2,
          storagePrefixCleared: `users/${uid}/`,
        };
      },
      async deleteAuthUser(uid) {
        calls.push(`auth:${uid}`);
      },
    },
  });

  assert.equal(mock.getStatus(), 200);
  assert.deepEqual(calls, ['data:uid-del-1', 'auth:uid-del-1']);
  assert.equal(mock.getBody().deleted, true);
  assert.equal(mock.getBody().uid, 'uid-del-1');
});
