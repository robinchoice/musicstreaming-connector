import { afterAll, afterEach, beforeAll, expect, spyOn, test } from 'bun:test';
import { createDb, feedback, migrateDb } from '@app/db';
import { eq } from 'drizzle-orm';
import { createApp } from './app';

// Runs against DATABASE_URL, every test from its own address
const db = createDb(process.env.DATABASE_URL!);
const app = createApp(async () => { throw new Error('unused'); }, db);
const log = spyOn(console, 'log');

beforeAll(() => migrateDb(process.env.DATABASE_URL!));
afterAll(() => db.$client.end());
afterEach(() => { delete process.env.FEEDBACK_EMAIL; });

const PNG = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 1, 2, 3]).toString('base64');
const context = { platform: 'web', page: '/', device: 'Safari 19 · iOS', viewport: '390×844 @3x', errors: ['POST /api/v1/convert → 502'] };

function send(body: unknown, ip = crypto.randomUUID()) {
  return app.request('/api/v1/feedback', {
    method: 'POST',
    headers: { 'content-type': 'application/json', 'x-forwarded-for': ip },
    body: JSON.stringify(body),
  });
}

const lastMail = () => log.mock.calls.map(args => String(args[0])).findLast(line => line.startsWith('[mail]'));

test('a bug report is stored and mailed with reply-to the tester', async () => {
  process.env.FEEDBACK_EMAIL = 'robin@example.com';
  const email = `test-${crypto.randomUUID()}@example.com`;
  const response = await send({ kind: 'bug', message: 'Spotify-Link fehlt', email: email.toUpperCase(), screenshot: PNG, context });
  expect(response.status).toBe(200);

  const [row] = await db.select().from(feedback).where(eq(feedback.email, email));
  expect(row).toMatchObject({ kind: 'bug', message: 'Spotify-Link fehlt', context: { ...context, api: 'dev' } });
  expect(row!.screenshot!.toString('base64')).toBe(PNG);
  expect(lastMail()).toContain('To robin@example.com: Bug: Spotify-Link fehlt');
  expect(lastMail()).toContain(`Tester: ${email}`);
});

test('feedback works without an email', async () => {
  const message = `Mehr Dienste ${crypto.randomUUID()}`;
  expect((await send({ kind: 'idea', message, context })).status).toBe(200);
  const [row] = await db.select().from(feedback).where(eq(feedback.message, message));
  expect(row!.email).toBeNull();
});

test.each([
  [{ kind: 'idea', message: 'kurz', context }, 'Schreib bitte mindestens 5 Zeichen.'],
  [{ kind: 'idea', message: 'Mehr Dienste', email: 'keine-mail', context }, 'Die Mail-Adresse stimmt nicht.'],
  [{ kind: 'idea', message: 'Mehr Dienste' }, 'Die Meldung ist unvollständig.'],
  [{ kind: 'bug', message: 'Kaputt hier', screenshot: Buffer.from('GIF89a').toString('base64'), context }, 'Der Screenshot muss ein PNG oder JPEG sein.'],
])('rejects %p', async (body, error) => {
  const response = await send(body);
  expect(response.status).toBe(400);
  expect(await response.json()).toEqual({ error });
});

test('limits reports per address', async () => {
  const ip = crypto.randomUUID();
  for (let i = 0; i < 10; i++) expect((await send({ kind: 'idea', message: 'Mehr Dienste', context }, ip)).status).toBe(200);
  expect((await send({ kind: 'idea', message: 'Mehr Dienste', context }, ip)).status).toBe(429);
});
