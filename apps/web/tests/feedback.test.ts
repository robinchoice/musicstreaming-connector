import { LIVE } from '@app/shared';
import { expect, test } from '@playwright/test';

test('the test mode switch in the footer hides the bug button', async ({ page }) => {
  await page.goto('/');
  const testMode = page.getByRole('checkbox', { name: 'Testmodus' });
  const bug = page.getByRole('button', { name: 'Fehler melden' });
  await testMode.check();
  await expect(bug).toBeVisible();

  await testMode.uncheck();
  await expect(bug).toBeHidden();
  await page.reload();
  await expect(testMode).not.toBeChecked();
  await expect(bug).toBeHidden();

  await testMode.check();
  await expect(bug).toBeVisible();
  await page.reload();
  await expect(testMode).toBeChecked();
  await expect(bug).toBeVisible();
});

test('the test mode default follows the release state', async ({ page }) => {
  await page.goto('/');
  await expect(page.getByRole('checkbox', { name: 'Testmodus' })).toBeChecked({ checked: !LIVE });
});

for (const [mode, position] of [
  ['broken', 'broken'],
  ['"false"', '{"x":"bad","y":20}'],
  ['0', '{"x":1e999,"y":20}'],
  ['null', '[]'],
] as const) {
  test(`invalid feedback preferences recover: ${mode}, ${position}`, async ({ page }) => {
    await page.addInitScript(
      ({ mode, position }) => {
        localStorage.setItem('test-mode', mode);
        localStorage.setItem('feedback-button', position);
      },
      { mode, position },
    );
    await page.goto('/');
    const testMode = page.getByRole('checkbox', { name: 'Testmodus' });
    await expect(testMode).toBeChecked({ checked: !LIVE });
    await testMode.check();
    const bug = page.getByRole('button', { name: 'Fehler melden' });
    await expect(bug).toBeVisible();
    const box = (await bug.boundingBox())!;
    const viewport = page.viewportSize()!;
    expect(box.x).toBeCloseTo(viewport.width - box.width - 16, 0);
    expect(box.y).toBeCloseTo(viewport.height * 0.62, 0);
  });
}

test('the bug button keeps its saved position after moving and reloading', async ({ page }) => {
  await page.addInitScript(() => {
    if (localStorage.getItem('feedback-button') !== null) return;
    localStorage.setItem('test-mode', 'true');
    localStorage.setItem('feedback-button', JSON.stringify({ x: 80, y: 140 }));
  });
  await page.goto('/');
  const bug = page.getByRole('button', { name: 'Fehler melden' });
  await expect(bug).toBeVisible();
  const box = (await bug.boundingBox())!;
  expect(box.x).toBe(80);
  expect(box.y).toBe(140);
  await page.mouse.move(box.x + box.width / 2, box.y + box.height / 2);
  await page.mouse.down();
  await page.mouse.move(box.x + box.width / 2 + 30, box.y + box.height / 2 + 40, { steps: 5 });
  await page.mouse.up();
  await page.reload();
  await expect(bug).toBeVisible();
  const moved = (await bug.boundingBox())!;
  expect(moved.x).toBeCloseTo(110, 0);
  expect(moved.y).toBeCloseTo(180, 0);
});
