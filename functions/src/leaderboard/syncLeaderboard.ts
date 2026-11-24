import * as admin from 'firebase-admin';
import { onDocumentWritten } from 'firebase-functions/v2/firestore';

export interface PublicLeaderboardEntry {
  displayName: string;
  xp: number;
  stampCount: number;
  avatarUrl: string | null;
}

export interface LeaderboardWriter {
  upsert(uid: string, entry: PublicLeaderboardEntry): Promise<void>;
  remove(uid: string): Promise<void>;
}

function sanitizeAvatarUrl(raw: unknown): string | null {
  if (typeof raw !== 'string') return null;
  const trimmed = raw.trim();
  if (trimmed.length === 0 || trimmed.length > 2048) return null;
  return /^https?:\/\//.test(trimmed) ? trimmed : null;
}

function clampNonNegativeInt(raw: unknown, max: number): number {
  const n = typeof raw === 'number' ? raw : Number(raw);
  if (!Number.isFinite(n) || n < 0) return 0;
  return Math.min(max, Math.round(n));
}

/**
 * Chỉ trích xuất các trường công khai tối thiểu từ `user_passports/{uid}`:
 * `displayName`, `xp`, `stampCount`, `avatarUrl`.
 * Không bao giờ sao chép `passportNo`, `joinedAt`, `email` hay dữ liệu nhạy cảm.
 */
export function buildPublicLeaderboardEntry(
  passportData: Record<string, unknown>,
): PublicLeaderboardEntry {
  const rawName =
    typeof passportData.name === 'string' && passportData.name.trim().length > 0
      ? passportData.name.trim()
      : 'Lữ khách';
  return {
    displayName: rawName.slice(0, 60),
    xp: clampNonNegativeInt(passportData.xp, 1_000_000),
    stampCount: clampNonNegativeInt(passportData.stampCount, 500),
    avatarUrl: sanitizeAvatarUrl(passportData.avatarUrl),
  };
}

export async function handlePassportWriteForLeaderboard(
  uid: string,
  afterData: Record<string, unknown> | undefined,
  writer: LeaderboardWriter,
): Promise<void> {
  if (!afterData) {
    await writer.remove(uid);
    return;
  }
  const entry = buildPublicLeaderboardEntry(afterData);
  await writer.upsert(uid, entry);
}

export const syncLeaderboardOnPassportWrite = onDocumentWritten(
  {
    document: 'user_passports/{uid}',
    region: 'asia-southeast1',
  },
  async (event) => {
    const uid = event.params.uid;
    const db = admin.firestore();
    const targetRef = db.collection('leaderboard_public').doc(uid);

    const writer: LeaderboardWriter = {
      async upsert(_id, entry) {
        await targetRef.set({
          displayName: entry.displayName,
          xp: entry.xp,
          stampCount: entry.stampCount,
          avatarUrl: entry.avatarUrl,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      },
      async remove() {
        await targetRef.delete();
      },
    };

    const afterSnap = event.data?.after;
    const afterData = afterSnap?.exists
      ? (afterSnap.data() as Record<string, unknown>)
      : undefined;
    await handlePassportWriteForLeaderboard(uid, afterData, writer);
  },
);
