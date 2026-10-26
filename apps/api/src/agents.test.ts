import { expect, test } from 'bun:test';
import { APP_NAME, APP_TAGLINE } from '@app/shared';
import { createApp } from './app';
import { publicPages } from './lib/public-pages';

process.env.APP_URL = 'https://app.test';
const app = createApp(async () => { throw new Error('unused'); });
const get = (path: string, headers: Record<string, string> = {}) => app.request(path, { headers });

test('llms.txt lists every public page as Markdown', async () => {
  const res = await get('/llms.txt');
  expect(res.headers.get('content-type')).toBe('text/plain; charset=utf-8');
  const text = await res.text();
  expect(text).toStartWith(`# ${APP_NAME}\n\n> ${APP_TAGLINE}`);
  expect(text).toContain('https://app.test/llms-full.txt');
  expect(text).toContain('https://app.test/llms.txt?lang=en');
  expect(text).toContain(`- [${APP_NAME}](https://app.test/index.md): ${APP_TAGLINE}`);
  expect(text).toContain('https://app.test/datenschutz.md');
});

test('the language follows ?lang= before Accept-Language, and links keep it', async () => {
  const text = await (await get('/llms.txt?lang=en', { 'accept-language': 'de' })).text();
  expect(text).toContain('https://app.test/index.md?lang=en');
  expect(text).toContain('https://app.test/privacy.md?lang=en');
  expect(await (await get('/index.md', { 'accept-language': 'en-GB,en;q=0.9' })).text()).toContain('## Paste a link');
  expect(await (await get('/index.md', { 'accept-language': 'fr' })).text()).toContain('## Link einfügen');
});

test('every page is Markdown at <path>.md in either language, and llms-full.txt holds all of them', async () => {
  for (const locale of ['de', 'en'] as const) {
    const full = await (await get(`/llms-full.txt?lang=${locale}`)).text();
    for (const page of publicPages(locale, 'https://app.test')) {
      const res = await get(`${page.path === '/' ? '/index.md' : `${page.path}.md`}?lang=${locale}`);
      expect(res.headers.get('content-type')).toBe('text/markdown; charset=utf-8');
      const markdown = await res.text();
      expect(markdown).toStartWith(`# ${page.title}\n\n> ${page.description}`);
      expect(full).toContain(markdown.trim());
    }
  }
  expect(await (await get('/privacy.md')).text()).toStartWith('# Privacy policy');
});

test('shared songs and the API have no Markdown', async () => {
  expect((await get('/s/yt/UijW9hGpnzc.md')).status).toBe(404);
  expect((await get('/api/health.md')).status).toBe(404);
  expect((await get('/api/health')).status).toBe(200);
});
