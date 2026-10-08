import { type Database, rateLimits } from '@app/db';
import { lt, sql } from 'drizzle-orm';
import type { Context } from 'hono';

// Fixed-window counters in Postgres, so all API instances share them and a
// restart keeps them. `name` keeps the keys of different limits apart.
export function rateLimit(name: string, limit: number, windowMs: number) {
  let nextSweep = 0;

  return {
    // Counts a hit for `key`; false once it goes over the limit.
    async hit(db: Database, key: string) {
      if (Date.now() >= nextSweep) {
        nextSweep = Date.now() + windowMs;
        await db.delete(rateLimits).where(lt(rateLimits.resetAt, new Date()));
      }

      // An expired window starts over at 1. Both CASEs see the old row.
      const [row] = await db
        .insert(rateLimits)
        .values({ key: `${name}:${key}`, count: 1, resetAt: new Date(Date.now() + windowMs) })
        .onConflictDoUpdate({
          target: rateLimits.key,
          set: {
            count: sql`case when ${rateLimits.resetAt} <= now() then 1 else ${rateLimits.count} + 1 end`,
            resetAt: sql`case when ${rateLimits.resetAt} <= now() then excluded.reset_at else ${rateLimits.resetAt} end`,
          },
        })
        .returning({ count: rateLimits.count });
      return row!.count <= limit;
    },
  };
}

// Traefik sets X-Forwarded-For and the web app passes it through. Its last
// entry is the address Traefik saw.
export function clientIp(c: Context) {
  return c.req.header('x-forwarded-for')?.split(',').at(-1)?.trim() || 'unknown';
}
