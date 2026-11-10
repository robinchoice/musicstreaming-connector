import { expect, test } from '@playwright/test';

// Share pages and invites open in the installed app: the association files must be JSON at their fixed paths
test('the app link association files are served as JSON', async ({ request }) => {
  const apple = await request.get('/.well-known/apple-app-site-association');
  expect(apple.headers()['content-type']).toContain('application/json');
  expect((await apple.json()).applinks.details[0].components).toEqual([{ '/': '/s/*' }, { '/': '/f/*' }]);
  const android = await request.get('/.well-known/assetlinks.json');
  expect(android.headers()['content-type']).toContain('application/json');
  expect((await android.json())[0].target.package_name).toBe('org.pleasance.songgate');
});
