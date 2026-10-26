import { logger } from 'firebase-functions/v2';
import { db } from './admin';
import { Collections } from '../types';

export interface NotifyInput {
  recipientId: string;
  audience: 'buyer' | 'seller' | 'admin' | 'delivery';
  title: string;
  body: string;
  /** Logical category, e.g. `order_confirmed`, `refund_decision`. */
  type: string;
  deepLink?: string | null;
}

/**
 * Writes an in-app notification (mirrors Dart `AppNotification`).
 *
 * Best-effort: callers notify after the state change or money move has
 * already happened, so a failed write is logged and never undoes or fails
 * that work.
 */
export async function notify(input: NotifyInput): Promise<void> {
  try {
    await db.collection(Collections.notifications).add({
      recipientId: input.recipientId,
      audience: input.audience,
      title: input.title,
      body: input.body,
      type: input.type,
      deepLink: input.deepLink ?? null,
      isRead: false,
      // ISO string, matching how the Dart model reads `createdAt`.
      createdAt: new Date().toISOString(),
    });
  } catch (e) {
    logger.error('notify failed', {
      recipientId: input.recipientId,
      type: input.type,
      error: (e as Error).message,
    });
  }
}
