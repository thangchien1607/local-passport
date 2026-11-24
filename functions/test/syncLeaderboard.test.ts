import assert from 'node:assert/strict';
import test from 'node:test';

import {
  LeaderboardWriter,
  PublicLeaderboardEntry,
  buildPublicLeaderboardEntry,
  handlePassportWriteForLeaderboard,
} from '../src/leaderboard/syncLeaderboard';

test('buildPublicLeaderboardEntry chỉ giữ displayName, xp, stampCount, avatarUrl (không lộ user_passports)', () => {
  const entry = buildPublicLeaderboardEntry({
    name: '  Bảo Ngọc  ',
    passportNo: 'DN999888',
    email: 'secret@example.com',
    joinedAt: '2026-10-01',
    xp: 850,
    stampCount: 8,
    avatarUrl: 'https://firebasestorage.googleapis.com/v0/b/test/o/avatar.jpg',
  });

  assert.deepEqual(entry, {
    displayName: 'Bảo Ngọc',
    xp: 850,
    stampCount: 8,
    avatarUrl: 'https://firebasestorage.googleapis.com/v0/b/test/o/avatar.jpg',
  });
  assert.equal('passportNo' in entry, false);
  assert.equal('email' in entry, false);
});

test('handlePassportWriteForLeaderboard cập nhật khi ghi và xóa khi passport bị xóa', async () => {
  const store = new Map<string, PublicLeaderboardEntry>();
  const writer: LeaderboardWriter = {
    async upsert(uid, entry) {
      store.set(uid, entry);
    },
    async remove(uid) {
      store.delete(uid);
    },
  };

  await handlePassportWriteForLeaderboard(
    'uid-1',
    { name: 'Minh Anh', xp: 400, stampCount: 4, avatarUrl: 'invalid-url' },
    writer,
  );
  assert.deepEqual(store.get('uid-1'), {
    displayName: 'Minh Anh',
    xp: 400,
    stampCount: 4,
    avatarUrl: null,
  });

  await handlePassportWriteForLeaderboard('uid-1', undefined, writer);
  assert.equal(store.has('uid-1'), false);
});
