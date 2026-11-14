import { expect, test } from '@playwright/test';
import type { Song } from '@app/shared';

const podcast: Song = {
  source: { kind: 'podcast', platform: 'deezer', title: 'The Daily', artist: '', url: 'https://www.deezer.com/show/52913', artworkUrl: null },
  sharePath: '/s/podcast/dz/52913',
  links: {
    appleMusic: { url: 'https://podcasts.apple.com/de/podcast/id1200361736', found: true },
    youtubeMusic: { url: 'https://music.youtube.com/playlist?list=PLdMrbgYfVl-s16D_iT2BJCJ90pWtTO1A4', found: true },
    spotify: { url: 'https://open.spotify.com/search/The%20Daily', found: false },
    deezer: { url: 'https://www.deezer.com/show/52913', found: true },
    tidal: { url: 'https://tidal.com/search?q=The+Daily', found: false },
    amazonMusic: { url: 'https://music.amazon.de/search/The%20Daily', found: false },
  },
  apps: [{ name: 'Overcast', url: 'https://overcast.fm/itunes1200361736' }, { name: 'RSS', url: 'https://feeds.simplecast.com/Sl5CSM3S' }],
};

test('a podcast shows Apple Podcasts instead of TIDAL and the other podcast apps', async ({ page }) => {
  await page.route('**/api/v1/song?*', route => route.fulfill({ json: podcast }));
  await page.goto('/app');
  await page.getByLabel('Link zu Song, Album oder Podcast').fill('https://www.deezer.com/show/52913');
  await page.getByRole('button', { name: 'Finden' }).click();
  await expect(page.getByText('Podcast aus Deezer')).toBeVisible();
  const tiles = page.getByRole('group', { name: 'Dienste in der Nachricht' }).getByRole('button');
  await expect(tiles).toHaveCount(5);
  await expect(tiles.filter({ hasText: 'Apple Podcasts' })).toHaveCount(1);
  await expect(tiles.filter({ hasText: 'TIDAL' })).toHaveCount(0);
  await expect(page.getByRole('link', { name: 'Overcast' })).toHaveAttribute('href', 'https://overcast.fm/itunes1200361736');
  await tiles.filter({ hasText: 'Apple Podcasts' }).click();
  await expect(page.locator('pre')).toContainText('🎙️ The Daily\nhttps://podcasts.apple.com/de/podcast/id1200361736');
});
