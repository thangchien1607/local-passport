import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import test, { after, before, beforeEach } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  Timestamp,
  doc,
  getDoc,
  setDoc,
  updateDoc,
  writeBatch,
} from 'firebase/firestore';

const PROJECT_ID = 'demo-local-passport';
const RULES_PATH = path.resolve(import.meta.dirname, '..', 'firestore.rules');

let testEnv;

function validPassportDoc(overrides = {}) {
  return {
    name: 'Minh Anh',
    passportNo: 'DN123456',
    joinedAt: Timestamp.fromDate(new Date('2026-11-01T00:00:00Z')),
    xp: 250,
    stampCount: 2,
    ...overrides,
  };
}

function validVisitDoc(overrides = {}) {
  return {
    unlocked: true,
    unlockedAt: Timestamp.fromDate(new Date('2026-11-01T01:00:00Z')),
    tasks: ['story', 'timelens'],
    taskPhotos: ['photo:YWJjZA=='],
    stampedAt: Timestamp.fromDate(new Date('2026-11-01T02:00:00Z')),
    ...overrides,
  };
}

function validReflectionDoc(overrides = {}) {
  return {
    locationId: 'dien-hai',
    displayAuthor: 'Minh Anh',
    isAnonymous: false,
    content: 'Đứng trên tường thành Điện Hải nhìn ra sông Hàn rất xúc động.',
    createdAt: Timestamp.fromDate(new Date('2026-11-01T03:00:00Z')),
    photoBase64: 'YWJjZA==',
    ...overrides,
  };
}

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: fs.readFileSync(RULES_PATH, 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
  });
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

after(async () => {
  await testEnv.cleanup();
});

// ---- S2: Ảnh Base64 nén nhỏ (<= 120000 ký tự) và taskPhotos list (<= 3 phần tử) ----

test('S2 Cho phép ghi photoBase64 <= 120000 ký tự và chặn photoBase64 quá lớn', async () => {
  const db = testEnv.authenticatedContext('alice').firestore();

  const okBatch = writeBatch(db);
  okBatch.set(doc(db, 'reflection_owners', 'r-b64-ok'), { uid: 'alice' });
  okBatch.set(
    doc(db, 'reflections', 'r-b64-ok'),
    validReflectionDoc({ photoBase64: 'A'.repeat(80000) }),
  );
  await assertSucceeds(okBatch.commit());

  const hugeBatch = writeBatch(db);
  hugeBatch.set(doc(db, 'reflection_owners', 'r-b64-huge'), { uid: 'alice' });
  hugeBatch.set(
    doc(db, 'reflections', 'r-b64-huge'),
    validReflectionDoc({ photoBase64: 'A'.repeat(120001) }),
  );
  await assertFails(hugeBatch.commit());
});

test('S2 Cho phép tương thích ngược photoUrl hợp lệ và chặn photoUrl sai giao thức', async () => {
  const db = testEnv.authenticatedContext('alice').firestore();
  const okBatch = writeBatch(db);
  okBatch.set(doc(db, 'reflection_owners', 'r-url-ok'), { uid: 'alice' });
  okBatch.set(
    doc(db, 'reflections', 'r-url-ok'),
    validReflectionDoc({
      photoBase64: null,
      photoUrl: 'https://example.com/old.jpg',
    }),
  );
  await assertSucceeds(okBatch.commit());

  const badBatch = writeBatch(db);
  badBatch.set(doc(db, 'reflection_owners', 'r-badurl'), { uid: 'alice' });
  badBatch.set(
    doc(db, 'reflections', 'r-badurl'),
    validReflectionDoc({ photoUrl: 'data:image/png;base64,AAAA' }),
  );
  await assertFails(badBatch.commit());
});

test('S2 Ràng buộc taskPhotos là list <= 3 chuỗi, mỗi chuỗi <= 120000 ký tự', async () => {
  const db = testEnv.authenticatedContext('alice').firestore();
  const visitRef = doc(db, 'user_passports', 'alice', 'visits', 'dien-hai');

  // Hợp lệ: list 3 ảnh nhỏ
  await assertSucceeds(
    setDoc(
      visitRef,
      validVisitDoc({ taskPhotos: ['t1:AAA', 't2:BBB', 't3:CCC'] }),
    ),
  );

  // Vượt quá 3 ảnh -> từ chối
  await assertFails(
    setDoc(
      visitRef,
      validVisitDoc({ taskPhotos: ['t1:A', 't2:B', 't3:C', 't4:D'] }),
    ),
  );

  // Phần tử vượt 120000 ký tự -> từ chối
  await assertFails(
    setDoc(
      visitRef,
      validVisitDoc({ taskPhotos: ['A'.repeat(120001)] }),
    ),
  );

  // Sai kiểu (map thay vì list) -> từ chối
  await assertFails(
    setDoc(
      visitRef,
      validVisitDoc({ taskPhotos: { photo: 'YWJj' } }),
    ),
  );
});

// ---- 1.2: Chặn client tạo/sửa aiScore và khóa _rate_limits ----

test('1.2 Chặn client tự tạo trường aiScore trên reflections', async () => {
  const db = testEnv.authenticatedContext('alice').firestore();
  const batch = writeBatch(db);
  batch.set(doc(db, 'reflection_owners', 'r-score'), { uid: 'alice' });
  batch.set(
    doc(db, 'reflections', 'r-score'),
    validReflectionDoc({ aiScore: 99 }),
  );
  await assertFails(batch.commit());
});

test('1.2 Chặn chủ bài viết tự sửa aiScore sau khi Cloud Function đã chấm', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const adminDb = ctx.firestore();
    await setDoc(doc(adminDb, 'reflection_owners', 'r-scored'), { uid: 'alice' });
    await setDoc(
      doc(adminDb, 'reflections', 'r-scored'),
      validReflectionDoc({ aiScore: 72 }),
    );
  });

  const aliceDb = testEnv.authenticatedContext('alice').firestore();
  await assertFails(
    updateDoc(doc(aliceDb, 'reflections', 'r-scored'), { aiScore: 100 }),
  );
  // Nhưng đổi ẩn danh không đụng aiScore vẫn được phép.
  await assertSucceeds(
    updateDoc(doc(aliceDb, 'reflections', 'r-scored'), {
      isAnonymous: true,
      displayAuthor: 'Một Lữ khách Ẩn danh',
    }),
  );
});

test('1.2 Chặn client đọc/ghi _rate_limits', async () => {
  const aliceDb = testEnv.authenticatedContext('alice').firestore();
  await assertFails(
    setDoc(doc(aliceDb, '_rate_limits', 'ai_verify_alice'), { timestamps: [] }),
  );
  await assertFails(getDoc(doc(aliceDb, '_rate_limits', 'ai_verify_alice')));
});

// ---- 1.3: reflection_owners bất biến (allow update: if false) ----

test('1.3 Chặn ghi đè reflection_owners đã tồn tại và chặn người khác sửa bài', async () => {
  const aliceDb = testEnv.authenticatedContext('alice').firestore();
  const batch = writeBatch(aliceDb);
  batch.set(doc(aliceDb, 'reflection_owners', 'r-own'), { uid: 'alice' });
  batch.set(doc(aliceDb, 'reflections', 'r-own'), validReflectionDoc());
  await assertSucceeds(batch.commit());

  // Ghi đè reflection_owners phải bị từ chối.
  await assertFails(
    setDoc(doc(aliceDb, 'reflection_owners', 'r-own'), { uid: 'alice' }),
  );

  // Người khác không thể sửa bài của alice.
  const bobDb = testEnv.authenticatedContext('bob').firestore();
  await assertFails(
    updateDoc(doc(bobDb, 'reflections', 'r-own'), { isAnonymous: true }),
  );
});

// ---- 1.4: Siết schema cho user_passports/{uid} ----

test('1.4 Cho phép ghi user_passports/{uid} hợp lệ và chặn người dùng khác', async () => {
  const aliceDb = testEnv.authenticatedContext('alice').firestore();
  await assertSucceeds(
    setDoc(doc(aliceDb, 'user_passports', 'alice'), validPassportDoc()),
  );

  const bobDb = testEnv.authenticatedContext('bob').firestore();
  await assertFails(getDoc(doc(bobDb, 'user_passports', 'alice')));
  await assertFails(
    setDoc(doc(bobDb, 'user_passports', 'alice'), validPassportDoc()),
  );
});

test('1.4 Từ chối user_passports thiếu trường bắt buộc, sai kiểu, vượt ngưỡng hoặc thừa trường', async () => {
  const aliceDb = testEnv.authenticatedContext('alice').firestore();
  const ref = doc(aliceDb, 'user_passports', 'alice');

  // Thiếu trường bắt buộc (passportNo)
  const missingField = validPassportDoc();
  delete missingField.passportNo;
  await assertFails(setDoc(ref, missingField));

  // Sai kiểu (xp là chuỗi)
  await assertFails(setDoc(ref, validPassportDoc({ xp: '100' })));

  // Giá trị âm không hợp lệ
  await assertFails(setDoc(ref, validPassportDoc({ xp: -10 })));
  await assertFails(setDoc(ref, validPassportDoc({ stampCount: -1 })));

  // Vượt độ dài tên (> 60 ký tự)
  await assertFails(setDoc(ref, validPassportDoc({ name: 'A'.repeat(61) })));

  // Thừa trường không nằm trong schema
  await assertFails(setDoc(ref, validPassportDoc({ isAdmin: true })));

  // Danh sách tasks vượt ngưỡng (> 30 phần tử)
  const visitRef = doc(aliceDb, 'user_passports', 'alice', 'visits', 'dien-hai');
  await assertFails(
    setDoc(
      visitRef,
      validVisitDoc({ tasks: Array.from({ length: 31 }, (_, i) => `t${i}`) }),
    ),
  );

  // Thông báo thiếu createdAt hoặc title vượt 120 ký tự
  const noteRef = doc(aliceDb, 'user_passports', 'alice', 'notifications', 'n1');
  await assertFails(
    setDoc(noteRef, {
      type: 'welcome',
      title: 'T'.repeat(121),
      body: 'Nội dung',
      read: false,
      createdAt: Timestamp.now(),
    }),
  );
  await assertSucceeds(
    setDoc(noteRef, {
      type: 'welcome',
      title: 'Chào mừng',
      body: 'Nội dung thông báo hợp lệ.',
      locationId: null,
      read: false,
      createdAt: Timestamp.now(),
    }),
  );
});

test('1.4 Xác nhận chưa đăng nhập bị chặn ghi user_passports', async () => {
  const anonDb = testEnv.unauthenticatedContext().firestore();
  await assertFails(
    setDoc(doc(anonDb, 'user_passports', 'alice'), validPassportDoc()),
  );
  assert.ok(true);
});

// ---- 2.2: Leaderboard công khai chỉ đọc bởi client, ghi bởi Cloud Function ----

test('2.2 leaderboard_public cho phép mọi người đọc nhưng chặn client tự ghi/sửa', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'leaderboard_public', 'alice'), {
      displayName: 'Minh Anh',
      xp: 900,
      stampCount: 9,
      avatarUrl: null,
      updatedAt: Timestamp.now(),
    });
  });

  const anonDb = testEnv.unauthenticatedContext().firestore();
  await assertSucceeds(getDoc(doc(anonDb, 'leaderboard_public', 'alice')));

  const aliceDb = testEnv.authenticatedContext('alice').firestore();
  await assertSucceeds(getDoc(doc(aliceDb, 'leaderboard_public', 'alice')));
  await assertFails(
    setDoc(doc(aliceDb, 'leaderboard_public', 'alice'), {
      displayName: 'Hack',
      xp: 999999,
      stampCount: 99,
      avatarUrl: null,
    }),
  );
  await assertFails(
    updateDoc(doc(aliceDb, 'leaderboard_public', 'alice'), { xp: 999999 }),
  );
});

// ---- 2.4: Cho tác giả sửa content/photoUrl nhưng vẫn chặn sửa aiScore/photoBase64 ----

test('2.4 Tác giả sửa được content và photoUrl nhưng vẫn bị chặn sửa aiScore hoặc thêm photoBase64', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const adminDb = ctx.firestore();
    await setDoc(doc(adminDb, 'reflection_owners', 'r-edit'), { uid: 'alice' });
    await setDoc(
      doc(adminDb, 'reflections', 'r-edit'),
      validReflectionDoc({ aiScore: 70 }),
    );
  });

  const aliceDb = testEnv.authenticatedContext('alice').firestore();
  const ref = doc(aliceDb, 'reflections', 'r-edit');

  await assertSucceeds(
    updateDoc(ref, {
      content: 'Nội dung cảm nhận đã được tác giả chỉnh sửa chi tiết hơn.',
      photoUrl: 'https://firebasestorage.googleapis.com/v0/b/test/o/new.jpg',
    }),
  );

  await assertFails(
    updateDoc(ref, {
      content: 'Thử gian lận điểm AI',
      aiScore: 100,
    }),
  );

  await assertFails(
    updateDoc(ref, {
      photoBase64: 'A'.repeat(120001),
    }),
  );

  const bobDb = testEnv.authenticatedContext('bob').firestore();
  await assertFails(
    updateDoc(doc(bobDb, 'reflections', 'r-edit'), {
      content: 'Người khác sửa trộm',
    }),
  );
});
