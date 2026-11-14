import { expect, test } from '@playwright/test';
import { savior } from './fixtures.ts';

const IPHONE = 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1';
const ANDROID = 'Mozilla/5.0 (Linux; Android 15; Pixel 9) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Mobile Safari/537.36';

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

const stores = (page: import('@playwright/test').Page) => page.getByRole('navigation', { name: 'Songgate als App' }).getByRole('link');

test('a desktop sees both stores and the way into the web app', async ({ page }) => {
  await page.goto('/');
  await expect(page.getByRole('heading', { level: 1 })).toHaveText('Teil Musik. Alle hören sie in ihrer App.');
  await expect(stores(page)).toHaveCount(2);
  await expect(page.getByRole('link', { name: 'Laden im App Store' })).toHaveAttribute('href', /apps\.apple\.com/);
  await expect(page.getByRole('link', { name: 'Jetzt bei Google Play' })).toHaveAttribute('href', /play\.google\.com/);
  await page.getByRole('link', { name: 'Im Browser öffnen →' }).click();
  await expect(page).toHaveURL(/\/app$/);
  await expect(page.getByLabel('Link zu Song, Album oder Podcast')).toBeVisible();
});

test('old bookmarks with ?q= open the converter', async ({ page }) => {
  await page.route('**/api/v1/song?**', route => route.fulfill({ json: savior }));
  await page.goto('/?q=https%3A%2F%2Fyoutu.be%2FUijW9hGpnzc');
  await expect(page).toHaveURL(/\/app\?q=https/);
  await expect(page.getByRole('heading', { name: 'Savior' })).toBeVisible();
});

for (const [name, userAgent, store, other] of [['iPhone', IPHONE, 'Laden im App Store', 'Google Play'], ['Android', ANDROID, 'Jetzt bei Google Play', 'App Store']] as const) {
  test.describe(name, () => {
    test.use({ userAgent, viewport: { width: 390, height: 664 }, isMobile: true, hasTouch: true });

    test(`${name} sees only its store and everything fits one screen`, async ({ page }) => {
      await page.goto('/');
      await expect(stores(page)).toHaveCount(1);
      await expect(page.getByRole('link', { name: store })).toBeVisible();
      await expect(page.getByRole('link', { name: other, exact: true })).toBeVisible();
      expect(await page.evaluate(() => document.documentElement.scrollHeight <= innerHeight)).toBe(true);
      await page.goto('/app');
      expect(await page.evaluate(() => document.documentElement.scrollHeight <= innerHeight)).toBe(true);
    });
  });
}
