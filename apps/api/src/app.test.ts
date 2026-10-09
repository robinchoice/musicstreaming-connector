import { expect, test } from 'bun:test';
import { createApp } from './app';
import { ResolutionError } from './lib/resolver';

const conversion = { target: 'appleMusic' as const, source: { title: 'Savior', artist: 'Red Hot Chili Peppers', url: 'https://music.youtube.com/watch?v=UijW9hGpnzc' }, sharePath: '/s/yt/UijW9hGpnzc', candidates: [{ title: 'Savior', url: 'https://open.spotify.com/track/0O8RjwNco465s5o9Ix9IYj', artworkUrl: null }] };
const post = (body: unknown) => ({ method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(body) });

test('public healthcheck and conversion require no account', async () => {
  const app = createApp(async input => { expect(input).toEqual({ input: 'song', target: 'appleMusic', country: 'DE' }); return conversion; });
  const health = await app.request('/api/health');
  expect(health.status).toBe(200);
  expect(await health.json()).toMatchObject({ status: 'ok', revision: expect.any(String) });
  const response = await app.request('/api/v1/convert', post({ input: ' song ', target: 'appleMusic' }));
  expect(response.status).toBe(200);
  expect(response.headers.get('cache-control')).toBe('no-store');
  expect(await response.json()).toEqual(conversion);
});

test('validates input before calling upstream', async () => {
  const app = createApp(async () => { throw new Error('must not resolve'); });
  for (const body of [{}, { input: 123 }, { input: '' }, { input: 'a'.repeat(4097) }]) {
    expect((await app.request('/api/v1/convert', post(body))).status).toBe(400);
  }
  expect((await app.request('/api/v1/convert', { method: 'POST', body: '{' })).status).toBe(400);
  expect((await app.request('/api/v1/convert', post({ input: 'x'.repeat(9000) }))).status).toBe(413);
});

test.each([['NO_MATCH', 422], ['RATE_LIMITED', 429], ['NETWORK', 502]] as const)('returns %s as a structured error', async (code, status) => {
  const app = createApp(async () => { throw new ResolutionError(code); });
  const response = await app.request('/api/v1/convert', post({ input: 'song', target: 'appleMusic' }));
  expect(response.status).toBe(status);
  expect(await response.json()).toMatchObject({ code, error: expect.any(String) });
});

test('passes the search fallback of a missing match to clients', async () => {
  const app = createApp(async () => { throw new ResolutionError('NO_MATCH', 'https://music.youtube.com/search?q=Savior'); });
  const response = await app.request('/api/v1/convert', post({ input: 'song', target: 'youtubeMusic' }));
  expect(await response.json()).toMatchObject({ code: 'NO_MATCH', searchUrl: 'https://music.youtube.com/search?q=Savior' });
});

test('caps upstream traffic per process regardless of spoofed forwarding headers', async () => {
  let calls = 0;
  const app = createApp(async () => { calls++; return conversion; });
  for (let i = 0; i < 60; i++) await app.request('/api/v1/convert', post({ input: 'song', target: 'appleMusic' }));
  const response = await app.request('/api/v1/convert', { ...post({ input: 'song', target: 'appleMusic' }), headers: { 'x-forwarded-for': '1.2.3.4' } });
  expect(response.status).toBe(429);
  expect(Number(response.headers.get('retry-after'))).toBeGreaterThan(0);
  expect(calls).toBe(60);
});

test('song lookups are cached so share pages do not hit the services again', async () => {
  const song = { source: { platform: 'youtubeMusic' as const, title: 'Savior', artist: 'Red Hot Chili Peppers', url: 'https://music.youtube.com/watch?v=UijW9hGpnzc', artworkUrl: null }, sharePath: '/s/yt/UijW9hGpnzc', links: {
    youtubeMusic: { url: 'https://music.youtube.com/watch?v=UijW9hGpnzc', found: true }, appleMusic: { url: 'https://music.apple.com/de/album/savior/945575406?i=945575419', found: true },
    spotify: { url: 'https://open.spotify.com/search/Savior', found: false }, deezer: { url: 'https://www.deezer.com/track/725299', found: true },
  } };
  let calls = 0;
  const app = createApp(undefined, undefined, async input => { calls++; expect(input).toEqual({ input: 'https://youtu.be/UijW9hGpnzc', country: 'AT' }); return song; });
  const url = '/api/v1/song?input=' + encodeURIComponent('https://youtu.be/UijW9hGpnzc') + '&country=AT';
  expect(await (await app.request(url)).json()).toEqual(song);
  expect(await (await app.request(url)).json()).toEqual(song);
  expect(calls).toBe(1);
  expect((await app.request('/api/v1/song?country=XX&input=x')).status).toBe(400);
});
