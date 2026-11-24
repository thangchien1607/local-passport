import assert from 'node:assert/strict';
import test from 'node:test';

import { HeuristicFallbackAdapter } from '../src/ai/adapter';
import {
  handleReflectionUpdatedForRescore,
  shouldRescoreReflection,
} from '../src/ai/rescoreOnReflectionEdit';

test('Chỉ kích hoạt chấm lại AI khi content hoặc photoUrl thay đổi (tránh vòng lặp vô hạn)', () => {
  const base = {
    locationId: 'dien-hai',
    content: 'Nội dung ban đầu đủ dài cho bài cảm nhận.',
    photoUrl: null,
    aiScore: 70,
  };

  // Đổi ẩn danh / không đổi content hay photoUrl -> không chấm lại.
  assert.equal(shouldRescoreReflection(base, { ...base }), false);

  // Chỉ đổi aiScore (do chính Cloud Function ghi) -> không chấm lại.
  assert.equal(shouldRescoreReflection(base, { ...base, aiScore: 85 }), false);

  // Sửa content -> cần chấm lại.
  assert.equal(
    shouldRescoreReflection(base, {
      ...base,
      content: 'Nội dung mới được tác giả bổ sung thêm chi tiết lịch sử.',
    }),
    true,
  );

  // Đổi photoUrl -> cần chấm lại.
  assert.equal(
    shouldRescoreReflection(base, {
      ...base,
      photoUrl: 'https://firebasestorage.googleapis.com/v0/b/test/o/p.jpg',
    }),
    true,
  );
});

test('handleReflectionUpdatedForRescore chấm lại và ghi aiScore mới', async () => {
  const updated: Array<{ id: string; score: number }> = [];
  const ran = await handleReflectionUpdatedForRescore(
    'r-edit-1',
    {
      locationId: 'dien-hai',
      content: 'Nội dung cũ ngắn.',
      photoUrl: null,
      aiScore: 50,
    },
    {
      locationId: 'dien-hai',
      content: 'Đứng trên tường thành Điện Hải nhìn ra sông Hàn, cảm thấy rất tự hào về lịch sử Đà Nẵng.',
      photoUrl: 'https://firebasestorage.googleapis.com/v0/b/test/o/new.jpg',
      aiScore: 50,
    },
    new HeuristicFallbackAdapter(),
    {
      async updateScore(id, score) {
        updated.push({ id, score });
      },
    },
  );

  assert.equal(ran, true);
  assert.equal(updated.length, 1);
  assert.equal(updated[0].id, 'r-edit-1');
  assert.ok(updated[0].score > 50);
});
