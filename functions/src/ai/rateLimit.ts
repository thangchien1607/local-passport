import * as admin from 'firebase-admin';

export interface RateLimitResult {
  allowed: boolean;
  retryAfterSeconds?: number;
  remaining: number;
}

export interface RateLimiter {
  consume(uid: string, nowMs?: number): Promise<RateLimitResult>;
}

export interface RateLimitOptions {
  maxRequests: number;
  windowMs: number;
  collectionName?: string;
}

/**
 * Giới hạn tần suất theo `uid` lưu trong Firestore (`_rate_limits/{uid}`),
 * chạy trong transaction để tránh race condition khi nhiều request đến đồng thời.
 */
export class FirestoreRateLimiter implements RateLimiter {
  private readonly collectionName: string;

  constructor(
    private readonly db: admin.firestore.Firestore,
    private readonly options: RateLimitOptions,
  ) {
    this.collectionName = options.collectionName ?? '_rate_limits';
  }

  async consume(uid: string, nowMs = Date.now()): Promise<RateLimitResult> {
    const ref = this.db.collection(this.collectionName).doc(`ai_verify_${uid}`);
    const windowStart = nowMs - this.options.windowMs;

    return this.db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      const data = snap.data() as { timestamps?: number[] } | undefined;
      const recent = (data?.timestamps ?? []).filter(
        (ts) => typeof ts === 'number' && ts > windowStart,
      );

      if (recent.length >= this.options.maxRequests) {
        const oldest = recent[0];
        const retryAfterSeconds = Math.max(
          1,
          Math.ceil((oldest + this.options.windowMs - nowMs) / 1000),
        );
        return {
          allowed: false,
          retryAfterSeconds,
          remaining: 0,
        };
      }

      const updated = [...recent, nowMs];
      tx.set(ref, {
        uid,
        timestamps: updated,
        updatedAt: admin.firestore.Timestamp.fromMillis(nowMs),
      });

      return {
        allowed: true,
        remaining: Math.max(0, this.options.maxRequests - updated.length),
      };
    });
  }
}
