import { expect, test } from '@playwright/test';

test('the footer switches to English and keeps it, the legal pages follow', async ({ page }) => {
  await page.goto('/');
  await page.getByRole('button', { name: 'English' }).click();
  await expect(page.getByRole('heading', { name: 'Share music. Everyone hears it in their own service.' })).toBeVisible();
  await expect(page.locator('html')).toHaveAttribute('lang', 'en');

  await page.reload();
  await expect(page.getByLabel('Song or album link')).toBeVisible();
  await page.getByRole('link', { name: 'Privacy' }).click();
  await expect(page).toHaveURL(/\/privacy$/);
  await page.getByRole('button', { name: 'Deutsch' }).click();
  await expect(page).toHaveURL(/\/datenschutz$/);
  await expect(page.getByRole('heading', { level: 1, name: 'Datenschutz' })).toBeVisible();
  await page.goto('/');
  await expect(page.getByRole('heading', { name: 'Teil Musik. Jeder hört sie in seinem Dienst.' })).toBeVisible();
});

test('the API answers errors in the chosen language', async ({ request }) => {
  for (const [lang, start] of [['de', 'Teile bitte'], ['en', 'Please share']]) {
    const response = await request.get('/api/v1/song?input=nonsense', { headers: { 'accept-language': lang! } });
    expect(response.status()).toBe(422);
    expect((await response.json()).error).toMatch(new RegExp(`^${start}`));
  }
});
