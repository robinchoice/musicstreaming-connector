import { expect, test } from '@playwright/test';

// What other people's agents read, through the web server like in production
test('llms.txt links Markdown for pages that exist', async ({ request }) => {
  for (const lang of ['de', 'en']) {
    const text = await (await request.get(`/llms.txt?lang=${lang}`)).text();
    const links = [...text.matchAll(/\]\((http[^)]+\.md)\?lang=\w+\)/g)].map(match => match[1]!);
    expect(links.length).toBeGreaterThan(0);
    for (const link of links) {
      const markdown = await request.get(link);
      expect(markdown.headers()['content-type']).toBe('text/markdown; charset=utf-8');
      const page = await request.get(link.replace(/\/index\.md$/, '/').replace(/\.md$/, ''));
      expect(page.status()).toBe(200);
    }
  }
});

// The HTML and the Markdown of a page are written separately (public-pages.ts),
// so a section that one of them forgets shows up here. The web is German only,
// so the German Markdown is the one to match. The legal pages are left out:
// their Markdown only points to the HTML, the one binding version.
test('every section of a page is in its Markdown', async ({ request }) => {
  const text = await (await request.get('/llms.txt?lang=de')).text();
  const links = [...text.matchAll(/\]\((http[^)]+\.md)\?lang=de\)/g)]
    .map(match => match[1]!)
    .filter(link => !/\/(impressum|datenschutz)\.md$/.test(link));
  expect(links.length).toBeGreaterThan(0);
  for (const link of links) {
    const html = await (await request.get(link.replace(/\/index\.md$/, '/').replace(/\.md$/, ''))).text();
    const markdown = await (await request.get(`${link}?lang=de`)).text();
    // Svelte escapes only & and < in text
    const headings = [...html.matchAll(/<h2[^>]*>(.*?)<\/h2>/gs)].map(match =>
      match[1]!.replace(/<[^>]*>/g, '').replace(/&lt;/g, '<').replace(/&amp;/g, '&'),
    );
    for (const heading of headings) expect(markdown).toContain(`## ${heading}\n`);
  }
});

test('a page answers Accept: text/markdown with Markdown, else with HTML', async ({ request }) => {
  const markdown = await request.get('/datenschutz', { headers: { accept: 'text/markdown, text/html;q=0.9' } });
  expect(markdown.headers()['content-type']).toBe('text/markdown; charset=utf-8');
  expect(await markdown.text()).toMatch(/^# Datenschutz/);
  const html = await request.get('/', { headers: { accept: 'text/html' } });
  expect(html.headers()['content-type']).toContain('text/html');
  // Pages without Markdown stay HTML for agents too
  const invite = await request.get('/f/spotify?name=Lea', { headers: { accept: 'text/markdown, text/html;q=0.9' } });
  expect(invite.headers()['content-type']).toContain('text/html');
});
