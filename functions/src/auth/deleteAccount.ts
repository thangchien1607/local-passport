import * as admin from 'firebase-admin';
import { onRequest } from 'firebase-functions/v2/https';

import { HttpLikeRequest, HttpLikeResponse } from '../ai/verifyReflection';

export interface DeleteSummary {
  visitsDeleted: number;
  notificationsDeleted: number;
  reflectionsDeleted: number;
  storagePrefixCleared: string;
}

export interface AccountDataCleaner {
  deleteAllUserData(uid: string): Promise<DeleteSummary>;
  deleteAuthUser(uid: string): Promise<void>;
}

export interface DeleteAccountDeps {
  verifyIdToken(token: string): Promise<{ uid: string }>;
  cleaner: AccountDataCleaner;
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

async function deleteRefsInChunks(
  db: admin.firestore.Firestore,
  refs: admin.firestore.DocumentReference[],
  chunkSize = 450,
): Promise<void> {
  for (let i = 0; i < refs.length; i += chunkSize) {
    const batch = db.batch();
    for (const ref of refs.slice(i, i + chunkSize)) {
      batch.delete(ref);
    }
    await batch.commit();
  }
}

export class FirebaseAccountCleaner implements AccountDataCleaner {
  constructor(
    private readonly db: admin.firestore.Firestore,
    private readonly auth: admin.auth.Auth,
    private readonly storage: admin.storage.Storage,
  ) {}

  async deleteAllUserData(uid: string): Promise<DeleteSummary> {
    const userDoc = this.db.collection('user_passports').doc(uid);
    const [visitsSnap, notesSnap, ownersSnap] = await Promise.all([
      userDoc.collection('visits').get(),
      userDoc.collection('notifications').get(),
      this.db.collection('reflection_owners').where('uid', '==', uid).get(),
    ]);

    const refsToDelete: admin.firestore.DocumentReference[] = [
      ...visitsSnap.docs.map((d) => d.ref),
      ...notesSnap.docs.map((d) => d.ref),
      userDoc,
      this.db.collection('leaderboard_public').doc(uid),
      this.db.collection('_rate_limits').doc(`ai_verify_${uid}`),
    ];

    for (const ownerDoc of ownersSnap.docs) {
      refsToDelete.push(this.db.collection('reflections').doc(ownerDoc.id));
      refsToDelete.push(ownerDoc.ref);
    }

    await deleteRefsInChunks(this.db, refsToDelete);

    const prefix = `users/${uid}/`;
    try {
      const bucket = this.storage.bucket();
      await bucket.deleteFiles({ prefix, force: true });
    } catch (err) {
      // Nếu bucket chưa có file hoặc chưa khởi tạo trên emulator, vẫn tiếp tục dọn tài khoản.
      console.warn(`Cảnh báo khi dọn Storage prefix ${prefix}:`, err);
    }

    return {
      visitsDeleted: visitsSnap.size,
      notificationsDeleted: notesSnap.size,
      reflectionsDeleted: ownersSnap.size,
      storagePrefixCleared: prefix,
    };
  }

  async deleteAuthUser(uid: string): Promise<void> {
    await this.auth.deleteUser(uid);
  }
}

export async function handleDeleteAccount(
  req: HttpLikeRequest,
  res: HttpLikeResponse,
  deps: DeleteAccountDeps,
): Promise<void> {
  if (req.method !== 'POST' && req.method !== 'DELETE') {
    res.status(405).json({ error: 'Chỉ hỗ trợ POST hoặc DELETE.' });
    return;
  }

  const token = extractBearerToken(req.headers);
  if (!token) {
    res
      .status(401)
      .json({ error: 'Thiếu Firebase ID Token trong header Authorization.' });
    return;
  }

  let uid: string;
  try {
    const decoded = await deps.verifyIdToken(token);
    uid = decoded.uid;
  } catch {
    res
      .status(401)
      .json({ error: 'Firebase ID Token không hợp lệ hoặc đã hết hạn.' });
    return;
  }

  try {
    const summary = await deps.cleaner.deleteAllUserData(uid);
    await deps.cleaner.deleteAuthUser(uid);
    res.status(200).json({ deleted: true, uid, summary });
  } catch (err) {
    console.error('Lỗi khi xóa tài khoản và dữ liệu:', err);
    res.status(500).json({ error: 'Không thể xóa hoàn tất dữ liệu tài khoản.' });
  }
}

export const deleteUserAccountData = onRequest(
  {
    region: 'asia-southeast1',
    cors: true,
    timeoutSeconds: 60,
  },
  async (req, res) => {
    const cleaner = new FirebaseAccountCleaner(
      admin.firestore(),
      admin.auth(),
      admin.storage(),
    );
    await handleDeleteAccount(req, res, {
      verifyIdToken: (token) => admin.auth().verifyIdToken(token),
      cleaner,
    });
  },
);
