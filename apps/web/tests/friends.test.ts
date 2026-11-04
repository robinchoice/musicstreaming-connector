import { expect, test } from '@playwright/test';

// Console errors fail the test, CSP violations included
let errors: string[] = [];
test.beforeEach(({ page }) => {
  errors = [];
  page.on('console', msg => {
    if (msg.type() === 'error') errors.push(msg.text());
  });
  page.on('pageerror', err => errors.push(err.message));
});
test.afterEach(() => expect(errors).toEqual([]));

test('invalid saved entries preserve valid friends and groups after saving', async ({ page }) => {
  await page.addInitScript(() => {
    if (localStorage.getItem('musiclink-friends') !== null) return;
    localStorage.setItem('musiclink-friends', JSON.stringify({
      friends: [{ name: 'Alex', platform: 'spotify' }, { name: 'Invalid', platform: 'unknown' }],
      groups: [{ name: 'WG', members: ['Alex', 42] }, { name: null, members: [] }],
      me: {},
    }));
  });
  await page.goto('/');
  await expect(page.getByRole('button', { name: /Alex/ })).toBeVisible();
  await expect(page.getByRole('button', { name: 'WG', exact: true })).toBeVisible();
  await page.getByRole('button', { name: 'Neu', exact: false }).click();
  await page.getByPlaceholder('Name', { exact: true }).fill('Sam');
  await page.getByRole('button', { name: 'Speichern', exact: true }).click();
  await page.reload();
  await expect(page.getByRole('button', { name: /Alex/ })).toBeVisible();
  await expect(page.getByRole('button', { name: /Sam/ })).toBeVisible();
  await expect(page.getByRole('button', { name: 'WG', exact: true })).toBeVisible();
  const saved: unknown = await page.evaluate(() => JSON.parse(localStorage.getItem('musiclink-friends') ?? 'null'));
  expect(saved).toEqual({
    friends: [{ name: 'Alex', platform: 'spotify' }, { name: 'Sam', platform: 'spotify' }],
    groups: [{ name: 'WG', members: ['Alex'] }],
    me: null,
  });
});

test('an invite saves its sender and the own invite shows as a QR code', async ({ page }) => {
  await page.goto('/f/spotify?name=Lea');
  await page.getByRole('button', { name: 'Hier im Browser speichern' }).click();
  await expect(page.getByRole('button', { name: '✓ Lea ist gespeichert' })).toBeDisabled();
  await page.goto('/');
  await expect(page.getByRole('button', { name: /Lea/ })).toBeVisible();
  await page.getByRole('button', { name: 'Meine Einladung' }).click();
  await expect(page.getByRole('img', { name: 'QR-Code deiner Einladung' })).toHaveCount(0);
  await page.getByPlaceholder('Dein Name').fill('Robin');
  await expect(page.getByRole('img', { name: 'QR-Code deiner Einladung' }).locator('svg')).toBeVisible();
});


test('draft and result selection survive live window changes without overflow', async ({ page }) => {
  await page.goto('/');
  await page.getByRole('button', { name: 'Meine Einladung' }).click();
  await page.getByPlaceholder('Dein Name').fill('Alex');
  for (const [width, height] of [[320, 640], [640, 320], [768, 1024], [1024, 768], [1440, 900], [320, 480]]) {
    await page.setViewportSize({ width: width!, height: height! });
    await expect(page.getByPlaceholder('Dein Name')).toHaveValue('Alex');
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
  }
  await page.getByRole('button', { name: 'Meine Einladung' }).click();
  await page.route('**/api/v1/song?**', route => route.fulfill({ json: {
    source: { kind: 'song', platform: 'youtubeMusic', title: 'Savior', artist: 'RHCP',
      url: 'https://music.youtube.com/watch?v=UijW9hGpnzc', artworkUrl: null },
    sharePath: '/s/yt/UijW9hGpnzc',
    links: {
      spotify: { url: 'https://open.spotify.com/track/x', found: true },
      appleMusic: { url: 'https://music.apple.com/de/song/1', found: true },
      youtubeMusic: { url: 'https://music.youtube.com/watch?v=UijW9hGpnzc', found: true },
      deezer: { url: 'https://www.deezer.com/search/Savior', found: false },
    },
  } }));
  await page.locator('#song').fill('https://youtu.be/UijW9hGpnzc');
  await page.locator('#song').press('Enter');
  await expect(page.getByRole('heading', { name: 'Savior' })).toBeVisible();
  await page.getByRole('button', { name: /Spotify/ }).click();
  const message = await page.locator('pre').textContent();
  for (const [width, height] of [[1440, 900], [1024, 768], [640, 320], [320, 640]]) {
    await page.setViewportSize({ width: width!, height: height! });
    await expect(page.locator('pre')).toHaveText(message!);
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
  }
});
