import { db } from './admin';
import { Collections } from '../types';

export interface AuditInput {
  /** The acting user, or `system` for scheduled jobs. */
  actorId: string;
  /** Verb describing what happened, e.g. `seller.approved`. */
  action: string;
  targetType?: string;
  targetId?: string;
  metadata?: Record<string, unknown>;
}

/**
 * Appends an entry to `admin_audit` (mirrors Dart `AdminAuditEntry`). The
 * collection is append-only: entries are never updated or deleted.
 */
export async function writeAudit(input: AuditInput): Promise<void> {
  await db.collection(Collections.adminAudit).add({
    actorId: input.actorId,
    action: input.action,
    targetType: input.targetType ?? null,
    targetId: input.targetId ?? null,
    metadata: input.metadata ?? {},
    // ISO string, matching how the Dart model reads `createdAt`.
    createdAt: new Date().toISOString(),
  });
}
