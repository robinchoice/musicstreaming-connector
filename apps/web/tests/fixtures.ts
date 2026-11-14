import { expect, type Page } from '@playwright/test';
import type { Song } from '@app/shared';

export const savior: Song = {
  source: { kind: 'song', platform: 'youtubeMusic', title: 'Savior', artist: 'RHCP', url: 'https://music.youtube.com/watch?v=UijW9hGpnzc', artworkUrl: null },
  sharePath: '/s/yt/UijW9hGpnzc',
  links: {
    spotify: { url: 'https://open.spotify.com/track/x', found: true },
    appleMusic: { url: 'https://music.apple.com/de/song/1', found: true },
    youtubeMusic: { url: 'https://music.youtube.com/watch?v=UijW9hGpnzc', found: true },
    deezer: { url: 'https://www.deezer.com/search/Savior', found: false },
    tidal: { url: 'https://tidal.com/track/1', found: true },
    amazonMusic: { url: 'https://music.amazon.de/search/RHCP%20Savior', found: false },
  },
};

// Contacts and groups show with a result, so tests that need them find a song first
export async function findSavior(page: Page) {
  await page.route('**/api/v1/song?**', route => route.fulfill({ json: savior }));
  await page.goto('/app');
  await page.locator('#song').fill('https://youtu.be/UijW9hGpnzc');
  await page.locator('#song').press('Enter');
  await expect(page.getByRole('heading', { name: 'Savior' })).toBeVisible();
}
