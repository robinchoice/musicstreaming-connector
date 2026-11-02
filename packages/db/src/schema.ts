import type { FeedbackContext } from '@app/shared';
import { sql } from 'drizzle-orm';
import { check, customType, integer, jsonb, pgTable, text, timestamp, uuid, varchar } from 'drizzle-orm/pg-core';

const bytea = customType<{ data: Buffer }>({ dataType: () => 'bytea' });

// Bug reports and ideas from the feedback button, also mailed. MusicLink has
// no accounts: the email is optional and the only way to reach the tester.
export const feedback = pgTable(
  'feedback',
  {
    id: uuid('id').defaultRandom().primaryKey(),
    kind: varchar('kind', { length: 10 }).notNull(),
    message: text('message').notNull(),
    email: varchar('email', { length: 255 }),
    screenshot: bytea('screenshot'),
    context: jsonb('context').$type<FeedbackContext & { api: string }>().notNull(),
    createdAt: timestamp('created_at').defaultNow().notNull(),
  },
  (table) => [check('feedback_kind', sql`${table.kind} in ('bug', 'idea')`)],
);

// Counters of lib/rate-limit.ts in the API
export const rateLimits = pgTable(
  'rate_limits',
  {
    key: varchar('key', { length: 300 }).primaryKey(),
    count: integer('count').notNull(),
    resetAt: timestamp('reset_at').notNull(),
  },
  (table) => [check('rate_limits_count', sql`${table.count} >= 1`)],
);
