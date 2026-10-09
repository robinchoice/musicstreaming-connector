import { Hono } from 'hono';
import { bodyLimit } from 'hono/body-limit';
import { HTTPException } from 'hono/http-exception';
import type { Database } from '@app/db';
import { conversionInput, countries, failureMessages, type Song } from '@app/shared';
import { z } from 'zod';
import { ResolutionError } from './lib/resolver';
import { resolve, resolveAll } from './lib/music';
import { captureException } from './monitoring';
import { feedbackRoutes } from './routes/feedback';

// Without a database there is no feedback, the converter needs none.
const songInput = z.object({ input: z.string().trim().min(1).max(4096), country: z.enum(countries).default('DE') });

export function createApp(resolver = resolve, db?: Database, resolveSong = resolveAll) {
  let windowStart = Date.now();
  let requests = 0;
  const limit = (c: { header: (name: string, value: string) => void }) => {
    if (Date.now() - windowStart >= 60_000) {
      windowStart = Date.now();
      requests = 0;
    }
    if (++requests > 60) {
      c.header('Retry-After', String(Math.ceil((windowStart + 60_000 - Date.now()) / 1000)));
      throw new ResolutionError('RATE_LIMITED');
    }
  };
  // Share pages get opened by every member of a group chat and by link previews,
  // so finished lookups stay in memory for a day instead of hitting the services again
  const songs = new Map<string, { at: number; song: Song }>();
  return new Hono()
    .onError((error, c) => {
      if (error instanceof ResolutionError) {
        const status = error.code === 'RATE_LIMITED' ? 429 : error.code === 'NETWORK' ? 502 : 422;
        return c.json({ error: error.message, code: error.code, searchUrl: error.searchUrl }, status);
      }
      if (error instanceof HTTPException) return c.json({ error: error.message }, error.status);
      captureException(error);
      return c.json({ error: 'Interner Fehler' }, 500);
    })
    // The CI compares revision with the deployed commit
    .get('/api/health', c => c.json({ status: 'ok', revision: process.env.APP_VERSION || 'dev' }))
    .use('/api/v1/convert', bodyLimit({ maxSize: 8192, onError: c => c.json({ error: 'Der geteilte Text ist zu lang.' }, 413) }))
    .post('/api/v1/convert', async c => {
      let body: unknown;
      try { body = await c.req.json(); } catch { return c.json({ error: failureMessages.INVALID_LINK }, 400); }
      const parsed = conversionInput.safeParse(body);
      if (!parsed.success) return c.json({ error: failureMessages.INVALID_LINK }, 400);
      limit(c);
      c.header('Cache-Control', 'no-store');
      return c.json(await resolver(parsed.data, c.req.raw.signal));
    })
    .get('/api/v1/song', async c => {
      const parsed = songInput.safeParse(c.req.query());
      if (!parsed.success) return c.json({ error: failureMessages.INVALID_LINK }, 400);
      const key = `${parsed.data.country} ${parsed.data.input}`;
      const cached = songs.get(key);
      if (cached && Date.now() - cached.at < 86_400_000) return c.json(cached.song);
      limit(c);
      const song = await resolveSong(parsed.data, c.req.raw.signal);
      if (songs.size >= 1000) songs.delete(songs.keys().next().value!);
      songs.set(key, { at: Date.now(), song });
      return c.json(song);
    })
    .use('/api/v1/feedback', bodyLimit({ maxSize: 8 * 1024 * 1024, onError: c => c.json({ error: 'Der Screenshot ist zu groß.' }, 413) }))
    .route('/api/v1/feedback', db ? feedbackRoutes(db) : new Hono())
    .notFound(c => c.json({ error: 'Nicht gefunden' }, 404));
}
