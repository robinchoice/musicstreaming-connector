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

test('an invite overrides the preview instead of adding a second one', async ({ request }) => {
  const html = await (await request.get('/f/spotify?name=Lea')).text();
  expect(html.match(/<meta property="og:title"/g)).toHaveLength(1);
  expect(html).toContain('<meta property="og:title" content="Lea hört auf Spotify"');
});
