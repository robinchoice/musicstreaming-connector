import { expect, test } from '@playwright/test';

// Link crawlers run no JavaScript: the server-rendered page must carry the tags
test('the start page links a preview image that exists', async ({ request }) => {
  const html = await (await request.get('/')).text();
  expect(html).toContain('<meta property="og:title" content="');
  const image = html.match(/<meta property="og:image" content="([^"]+)"/)?.[1];
  expect(image).toMatch(/\/og-image-de\.png$/);
  const response = await request.get(image!);
  expect(response.headers()['content-type']).toBe('image/png');
});

test('English visitors get the English preview, ?lang= picks it too', async ({ request }) => {
  for (const html of [
    await (await request.get('/', { headers: { 'accept-language': 'en-US,en;q=0.9' } })).text(),
    await (await request.get('/?lang=en', { headers: { 'accept-language': 'de-DE' } })).text(),
  ]) {
    expect(html).toContain('<html lang="en">');
    expect(html).toMatch(/<meta property="og:image" content="[^"]+\/og-image-en\.png"/);
    expect(html).toContain('<meta property="og:locale" content="en_US"');
  }
  const image = await request.get('/og-image-en.png');
  expect(image.headers()['content-type']).toBe('image/png');
  const invite = await (await request.get('/f/spotify?name=Lea&lang=en')).text();
  expect(invite).toContain('<meta property="og:title" content="Lea listens on Spotify"');
});

test('an invite overrides the preview instead of adding a second one', async ({ request }) => {
  const html = await (await request.get('/f/spotify?name=Lea')).text();
  expect(html.match(/<meta property="og:title"/g)).toHaveLength(1);
  expect(html).toContain('<meta property="og:title" content="Lea hört auf Spotify"');
});

test('pages and the API carry the security headers', async ({ request }) => {
  for (const path of ['/', '/api/health']) {
    const headers = (await request.get(path)).headers();
    expect(headers['strict-transport-security']).toBe('max-age=31536000');
    expect(headers['x-content-type-options']).toBe('nosniff');
  }
  expect((await request.get('/')).headers()['content-security-policy']).toContain("frame-ancestors 'none'");
});
