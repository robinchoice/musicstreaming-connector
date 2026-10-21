import { expect, test } from '@playwright/test';

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
