import { expect, test } from '@playwright/test';

test('the test mode switch in the footer hides the bug button', async ({ page }) => {
  await page.goto('/');
  const testMode = page.getByRole('checkbox', { name: 'Testmodus' });
  const bug = page.getByRole('button', { name: 'Fehler melden' });
  await expect(testMode).toBeChecked();
  await expect(bug).toBeVisible();

  await testMode.uncheck();
  await expect(bug).toBeHidden();
  await page.reload();
  await expect(testMode).not.toBeChecked();
  await expect(bug).toBeHidden();

  await testMode.check();
  await expect(bug).toBeVisible();
});
