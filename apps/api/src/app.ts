import { Hono } from 'hono';
import { bodyLimit } from 'hono/body-limit';
import { HTTPException } from 'hono/http-exception';
import { conversionInput, failureMessages } from '@app/shared';
import { ResolutionError } from './lib/resolver';
import { resolve } from './lib/music';
import { captureException } from './monitoring';

export function createApp(resolver = resolve) {
  let windowStart = Date.now();
  let requests = 0;
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
    .get('/api/health', c => c.json({ status: 'ok' }))
    .use('/api/v1/convert', bodyLimit({ maxSize: 8192, onError: c => c.json({ error: 'Der geteilte Text ist zu lang.' }, 413) }))
    .post('/api/v1/convert', async c => {
      let body: unknown;
      try { body = await c.req.json(); } catch { return c.json({ error: failureMessages.INVALID_LINK }, 400); }
      const parsed = conversionInput.safeParse(body);
      if (!parsed.success) return c.json({ error: failureMessages.INVALID_LINK }, 400);
      if (Date.now() - windowStart >= 60_000) {
        windowStart = Date.now();
        requests = 0;
      }
      if (++requests > 60) {
        c.header('Retry-After', String(Math.ceil((windowStart + 60_000 - Date.now()) / 1000)));
        throw new ResolutionError('RATE_LIMITED');
      }
      c.header('Cache-Control', 'no-store');
      return c.json(await resolver(parsed.data, c.req.raw.signal));
    })
    .notFound(c => c.json({ error: 'Nicht gefunden' }, 404));
}
