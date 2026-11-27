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
  deleteDoc,
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
    aiScore: 82,
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

// ---- S3: Ràng buộc aiScore là số nguyên 0..100 trên reflections ----

test('S3 Chấp nhận aiScore 0..100 và từ chối aiScore âm, > 100 hoặc sai kiểu', async () => {
  const db = testEnv.authenticatedContext('alice').firestore();

  const okBatch = writeBatch(db);
  okBatch.set(doc(db, 'reflection_owners', 'r-score-ok'), { uid: 'alice' });
  okBatch.set(
    doc(db, 'reflections', 'r-score-ok'),
    validReflectionDoc({ aiScore: 100 }),
  );
  await assertSucceeds(okBatch.commit());

  for (const [id, badScore] of [
    ['r-score-neg', -1],
    ['r-score-over', 101],
    ['r-score-str', '80'],
    ['r-score-float', 85.5],
  ]) {
    const batch = writeBatch(db);
    batch.set(doc(db, 'reflection_owners', id), { uid: 'alice' });
    batch.set(
      doc(db, 'reflections', id),
      validReflectionDoc({ aiScore: badScore }),
    );
    await assertFails(batch.commit());
  }
});

test('S3 Tác giả chấm lại aiScore 0..100 khi sửa bài, nhưng bị chặn điểm ngoài 0..100', async () => {
  const aliceDb = testEnv.authenticatedContext('alice').firestore();
  const batch = writeBatch(aliceDb);
  batch.set(doc(aliceDb, 'reflection_owners', 'r-rescore'), { uid: 'alice' });
  batch.set(
    doc(aliceDb, 'reflections', 'r-rescore'),
    validReflectionDoc({ aiScore: 72 }),
  );
  await assertSucceeds(batch.commit());

  await assertSucceeds(
    updateDoc(doc(aliceDb, 'reflections', 'r-rescore'), {
      content: 'Nội dung mới sau khi sửa và tự chấm lại ở client.',
      aiScore: 91,
    }),
  );

  await assertFails(
    updateDoc(doc(aliceDb, 'reflections', 'r-rescore'), { aiScore: 150 }),
  );
  await assertFails(
    updateDoc(doc(aliceDb, 'reflections', 'r-rescore'), { aiScore: -5 }),
  );
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

// ---- 1.3b: đọc reflection_owners khi đồng bộ bài cảm nhận mới ----

test('1.3b Đọc được reflection_owners chưa tồn tại, không đọc được của người khác', async () => {
  const aliceDb = testEnv.authenticatedContext('alice').firestore();
  // Bài mới chưa có chủ: phải đọc được (trước đây bị từ chối, hỏng cả lần đồng bộ).
  await assertSucceeds(getDoc(doc(aliceDb, 'reflection_owners', 'r-chua-co')));

  const batch = writeBatch(aliceDb);
  batch.set(doc(aliceDb, 'reflection_owners', 'r-cua-alice'), { uid: 'alice' });
  batch.set(doc(aliceDb, 'reflections', 'r-cua-alice'), validReflectionDoc());
  await assertSucceeds(batch.commit());
  await assertSucceeds(getDoc(doc(aliceDb, 'reflection_owners', 'r-cua-alice')));

  const bobDb = testEnv.authenticatedContext('bob').firestore();
  await assertFails(getDoc(doc(bobDb, 'reflection_owners', 'r-cua-alice')));

  const guestDb = testEnv.unauthenticatedContext().firestore();
  await assertFails(getDoc(doc(guestDb, 'reflection_owners', 'r-chua-co')));
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

// ---- S4: Leaderboard công khai do chủ tài khoản tự ghi trong giới hạn schema ----

test('S4 leaderboard_public cho chủ sở hữu ghi/xóa đúng schema và chặn sai uid hoặc sai dữ liệu', async () => {
  const aliceDb = testEnv.authenticatedContext('alice').firestore();
  const bobDb = testEnv.authenticatedContext('bob').firestore();
  const anonDb = testEnv.unauthenticatedContext().firestore();
  const aliceRef = doc(aliceDb, 'leaderboard_public', 'alice');

  const validEntry = {
    displayName: 'Minh Anh',
    xp: 900,
    stampCount: 9,
    avatarUrl: 'https://example.com/avatar.jpg',
    updatedAt: Timestamp.now(),
  };

  // Chủ tài khoản tạo & cập nhật thành công.
  await assertSucceeds(setDoc(aliceRef, validEntry));
  await assertSucceeds(
    updateDoc(aliceRef, { xp: 1050, stampCount: 10, updatedAt: Timestamp.now() }),
  );

  // Khách và người dùng khác đều đọc được bảng xếp hạng.
  await assertSucceeds(getDoc(doc(anonDb, 'leaderboard_public', 'alice')));
  await assertSucceeds(getDoc(doc(bobDb, 'leaderboard_public', 'alice')));

  // Người khác KHÔNG được ghi/sửa/xóa bản ghi của alice.
  await assertFails(
    setDoc(doc(bobDb, 'leaderboard_public', 'alice'), validEntry),
  );
  await assertFails(
    updateDoc(doc(bobDb, 'leaderboard_public', 'alice'), { xp: 10 }),
  );

  // Chặn displayName > 40 ký tự, xp vượt trần/âm/sai kiểu, stampCount ngoài 0..200, thiếu updatedAt, trường thừa.
  await assertFails(setDoc(aliceRef, { ...validEntry, displayName: 'A'.repeat(41) }));
  await assertFails(setDoc(aliceRef, { ...validEntry, xp: -1 }));
  await assertFails(setDoc(aliceRef, { ...validEntry, xp: 50001 }));
  await assertFails(setDoc(aliceRef, { ...validEntry, xp: '900' }));
  await assertFails(setDoc(aliceRef, { ...validEntry, stampCount: -1 }));
  await assertFails(setDoc(aliceRef, { ...validEntry, stampCount: 201 }));
  await assertFails(setDoc(aliceRef, { ...validEntry, avatarUrl: 'ftp://bad.url' }));
  const noUpdatedAt = { ...validEntry };
  delete noUpdatedAt.updatedAt;
  await assertFails(setDoc(aliceRef, noUpdatedAt));
  await assertFails(setDoc(aliceRef, { ...validEntry, isAdmin: true }));
});

// ---- 2.4: Tác giả sửa bài trong giới hạn schema Spark ----

test('2.4 Tác giả sửa được content/photo hợp lệ nhưng bị chặn aiScore ngoài 0..100 hoặc photoBase64 > 120000', async () => {
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
      content: 'Thử gian lận điểm AI vượt ngưỡng',
      aiScore: 101,
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

// ---- S5: Chủ tài khoản xóa sạch toàn bộ dữ liệu của mình, người khác bị chặn ----

test('S5 Chủ tài khoản xóa sạch toàn bộ dữ liệu Firestore của mình và người khác bị chặn', async () => {
  const aliceDb = testEnv.authenticatedContext('alice').firestore();
  const bobDb = testEnv.authenticatedContext('bob').firestore();

  // Tạo đủ dữ liệu cho alice trên tất cả collection/subcollection.
  await assertSucceeds(
    setDoc(doc(aliceDb, 'user_passports', 'alice'), validPassportDoc()),
  );
  await assertSucceeds(
    setDoc(
      doc(aliceDb, 'user_passports', 'alice', 'visits', 'dien-hai'),
      validVisitDoc(),
    ),
  );
  await assertSucceeds(
    setDoc(
      doc(aliceDb, 'user_passports', 'alice', 'notifications', 'n-del'),
      {
        type: 'welcome',
        title: 'Chào mừng',
        body: 'Nội dung thử xóa tài khoản.',
        locationId: null,
        read: false,
        createdAt: Timestamp.now(),
      },
    ),
  );
  await assertSucceeds(
    setDoc(doc(aliceDb, 'leaderboard_public', 'alice'), {
      displayName: 'Minh Anh',
      xp: 250,
      stampCount: 2,
      avatarUrl: null,
      updatedAt: Timestamp.now(),
    }),
  );
  const createRefl = writeBatch(aliceDb);
  createRefl.set(doc(aliceDb, 'reflection_owners', 'r-del'), { uid: 'alice' });
  createRefl.set(doc(aliceDb, 'reflections', 'r-del'), validReflectionDoc());
  await assertSucceeds(createRefl.commit());

  // Bob KHÔNG thể xóa bất kỳ document nào của alice.
  await assertFails(deleteDoc(doc(bobDb, 'user_passports', 'alice')));
  await assertFails(
    deleteDoc(doc(bobDb, 'user_passports', 'alice', 'visits', 'dien-hai')),
  );
  await assertFails(
    deleteDoc(doc(bobDb, 'user_passports', 'alice', 'notifications', 'n-del')),
  );
  await assertFails(deleteDoc(doc(bobDb, 'reflections', 'r-del')));
  await assertFails(deleteDoc(doc(bobDb, 'reflection_owners', 'r-del')));
  await assertFails(deleteDoc(doc(bobDb, 'leaderboard_public', 'alice')));

  // Alice xóa toàn bộ dữ liệu trong cùng WriteBatch (cặp reflection + reflection_owners đi cùng nhau).
  const delBatch = writeBatch(aliceDb);
  delBatch.delete(doc(aliceDb, 'user_passports', 'alice', 'visits', 'dien-hai'));
  delBatch.delete(
    doc(aliceDb, 'user_passports', 'alice', 'notifications', 'n-del'),
  );
  delBatch.delete(doc(aliceDb, 'reflections', 'r-del'));
  delBatch.delete(doc(aliceDb, 'reflection_owners', 'r-del'));
  delBatch.delete(doc(aliceDb, 'leaderboard_public', 'alice'));
  delBatch.delete(doc(aliceDb, 'user_passports', 'alice'));
  await assertSucceeds(delBatch.commit());

  // Xác nhận không còn document nào tồn tại.
  assert.equal((await getDoc(doc(aliceDb, 'user_passports', 'alice'))).exists(), false);
  assert.equal((await getDoc(doc(aliceDb, 'reflections', 'r-del'))).exists(), false);
  assert.equal(
    (await getDoc(doc(aliceDb, 'leaderboard_public', 'alice'))).exists(),
    false,
  );

  // Chạy xóa lại trên document không tồn tại (idempotent khi retry): vẫn hợp lệ.
  const retryBatch = writeBatch(aliceDb);
  retryBatch.delete(doc(aliceDb, 'leaderboard_public', 'alice'));
  retryBatch.delete(doc(aliceDb, 'user_passports', 'alice'));
  await assertSucceeds(retryBatch.commit());
});
