import fs from 'node:fs';
import path from 'node:path';
import test, { after, before, beforeEach } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import { getBytes, ref, uploadBytes } from 'firebase/storage';

const PROJECT_ID = 'demo-local-passport';
const STORAGE_RULES_PATH = path.resolve(
  import.meta.dirname,
  '..',
  'storage.rules',
);

let testEnv;

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    storage: {
      rules: fs.readFileSync(STORAGE_RULES_PATH, 'utf8'),
      host: '127.0.0.1',
      port: 9199,
    },
  });
});

beforeEach(async () => {
  await testEnv.clearStorage();
});

after(async () => {
  await testEnv.cleanup();
});

test('1.1 Storage: chủ sở hữu tải ảnh JPEG <= 5 MB vào thư mục của mình thành công', async () => {
  const storage = testEnv.authenticatedContext('alice').storage();
  const data = new Uint8Array([0xff, 0xd8, 0xff, 0xd9]);
  await assertSucceeds(
    uploadBytes(ref(storage, 'users/alice/tasks/dien-hai/photo_1.jpg'), data, {
      contentType: 'image/jpeg',
    }),
  );
  await assertSucceeds(
    uploadBytes(ref(storage, 'users/alice/reflections/r1.jpg'), data, {
      contentType: 'image/jpeg',
    }),
  );
});

test('1.1 Storage: chặn người khác ghi vào thư mục của alice và chặn đọc ảnh nhiệm vụ riêng tư', async () => {
  const aliceStorage = testEnv.authenticatedContext('alice').storage();
  const bobStorage = testEnv.authenticatedContext('bob').storage();
  const data = new Uint8Array([0xff, 0xd8, 0xff, 0xd9]);

  await assertSucceeds(
    uploadBytes(
      ref(aliceStorage, 'users/alice/tasks/dien-hai/photo_1.jpg'),
      data,
      { contentType: 'image/jpeg' },
    ),
  );
  await assertSucceeds(
    uploadBytes(ref(aliceStorage, 'users/alice/reflections/r1.jpg'), data, {
      contentType: 'image/jpeg',
    }),
  );

  // Bob không thể ghi vào thư mục của alice.
  await assertFails(
    uploadBytes(ref(bobStorage, 'users/alice/reflections/hack.jpg'), data, {
      contentType: 'image/jpeg',
    }),
  );

  // Bob không thể đọc ảnh nhiệm vụ riêng tư của alice.
  await assertFails(
    getBytes(ref(bobStorage, 'users/alice/tasks/dien-hai/photo_1.jpg')),
  );

  // Ảnh cảm nhận công khai thì đọc được.
  await assertSucceeds(
    getBytes(ref(bobStorage, 'users/alice/reflections/r1.jpg')),
  );
});

test('1.1 Storage: chặn contentType không phải ảnh và chặn file > 5 MB', async () => {
  const aliceStorage = testEnv.authenticatedContext('alice').storage();
  const smallText = new Uint8Array([65, 66, 67]);
  await assertFails(
    uploadBytes(
      ref(aliceStorage, 'users/alice/reflections/bad.txt'),
      smallText,
      { contentType: 'text/plain' },
    ),
  );

  const oversized = new Uint8Array(5 * 1024 * 1024 + 10);
  await assertFails(
    uploadBytes(
      ref(aliceStorage, 'users/alice/reflections/huge.jpg'),
      oversized,
      { contentType: 'image/jpeg' },
    ),
  );
});
