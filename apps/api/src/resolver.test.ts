import { describe, expect, test } from 'bun:test';
import { resolve, searchUrl, youtubeVideoId, type Fetch } from './lib/resolver';

const first = '0O8RjwNco465s5o9Ix9IYj';
const second = '60zaXKLFGQ4hPH7NtTcfq1';
const link = 'https://music.youtube.com/watch?v=UijW9hGpnzc&si=secretTracking';

function mock(options: {
  title?: string; artist?: string; target?: string; ids?: readonly string[]; status?: number; artwork?: string;
  inspect?: (url: URL) => void;
} = {}): Fetch {
  return async (url) => {
    options.inspect?.(url);
    switch (url.hostname) {
      case 'www.youtube.com':
        expect(url.searchParams.get('url')).toBe('https://www.youtube.com/watch?v=UijW9hGpnzc');
        return Response.json({ title: options.title ?? 'Savior', author_name: options.artist ?? 'Red Hot Chili Peppers - Topic' });
      case 'labs.api.listenbrainz.org':
        return Response.json([{ spotify_track_ids: options.ids ?? [first] }]);
      case 'open.spotify.com':
        return Response.json({ title: options.target ?? options.title ?? 'Savior', thumbnail_url: options.artwork ?? 'https://i.scdn.co/image/cover' }, { status: options.status ?? 200 });
      default: throw new Error(`Unexpected host: ${url.hostname}`);
    }
  };
}

describe('YouTube links', () => {
  test.each([
    ['Hör mal: ' + link, 'UijW9hGpnzc'],
    ['https://youtu.be/Z19cVpmYIkw?si=tracking', 'Z19cVpmYIkw'],
    ['https://www.youtube.com/watch?list=playlist&v=UijW9hGpnzc', 'UijW9hGpnzc'],
    ['https://youtu.be/UijW9hGpnzc ' + link, 'UijW9hGpnzc'],
    ['Hör mal (https://youtu.be/UijW9hGpnzc).', 'UijW9hGpnzc'],
  ])('accepts %s', (input, id) => expect(youtubeVideoId(input)).toBe(id));

  test.each([
    'https://music.youtube.com/playlist?list=playlist',
    'https://music.youtube.com.evil.example/watch?v=UijW9hGpnzc',
    'https://evil.example@music.youtube.com/watch?v=UijW9hGpnzc',
    'https://music.youtube.com/watch?v=short',
    'https://youtu.be/UijW9hGpnzc https://youtu.be/Z19cVpmYIkw',
    'Savior', 'http://127.0.0.1/watch?v=UijW9hGpnzc',
    'https://open.spotify.com/track/' + first,
  ])('rejects %s', input => expect(() => youtubeVideoId(input)).toThrow());
});

test('resolves metadata without tracking or credentials', async () => {
  const conversion = await resolve(link, undefined, mock({ inspect: url => {
    expect(url.toString()).not.toContain('secretTracking');
    if (url.hostname === 'labs.api.listenbrainz.org') {
      expect(url.searchParams.get('artist_name')).toBe('Red Hot Chili Peppers');
      expect(url.searchParams.get('track_name')).toBe('Savior');
      expect(url.searchParams.get('release_name')).toBe('');
    }
  } }));
  expect(conversion.source.url).toBe('https://music.youtube.com/watch?v=UijW9hGpnzc');
  expect(conversion.candidates[0]?.url).toBe('https://open.spotify.com/track/' + first);
});

test.each([
  ['Plätscher', 'Plätscher'],
  ['  PLÄTSCHER (東京 2024)  ', 'Plätscher — 東京 2024'],
  ['Machine Gun (Live At Fillmore East, 1970 / 50th Anniversary)', 'Machine Gun - Live At Fillmore East, 1970 / 50th Anniversary'],
])('matches Unicode and punctuation: %s', async (title, target) => {
  expect((await resolve(link, undefined, mock({ title, target }))).candidates).toHaveLength(1);
});

test.each([
  ['東京', '大阪'], ['Machine Gun (Live At Fillmore East, 1970)', 'Machine Gun'],
  ['Song (Club Remix)', 'Song (Radio Edit)'],
])('rejects a different recording: %s', async (title, target) => {
  await expect(resolve(link, undefined, mock({ title, target }))).rejects.toMatchObject({ code: 'NO_MATCH' });
});

test('preserves distinct releases and removes duplicate or malformed IDs', async () => {
  const result = await resolve(link, undefined, mock({ ids: [first, second, first, 'https://evil.example'] }));
  expect(result.candidates.map(c => c.url)).toEqual([first, second].map(id => `https://open.spotify.com/track/${id}`));
});

test.each([{ ids: [] }, { status: 404 }])('does not replace missing tracks with search links', async options => {
  await expect(resolve(link, undefined, mock(options))).rejects.toMatchObject({ code: 'NO_MATCH' });
});

test('rejects missing source artist', async () => {
  await expect(resolve(link, undefined, mock({ artist: '' }))).rejects.toMatchObject({ code: 'SOURCE_UNAVAILABLE' });
});

test('preserves upstream rate limits', async () => {
  await expect(resolve(link, undefined, mock({ status: 429 }))).rejects.toMatchObject({ code: 'RATE_LIMITED' });
});

test('maps missing source and network failures', async () => {
  await expect(resolve(link, undefined, async () => new Response('', { status: 404 }))).rejects.toMatchObject({ code: 'SOURCE_UNAVAILABLE' });
  await expect(resolve(link, undefined, async () => { throw new TypeError('offline'); })).rejects.toMatchObject({ code: 'NETWORK' });
  await expect(resolve(link, undefined, async () => new Response('not JSON'))).rejects.toMatchObject({ code: 'NETWORK' });
});

test('only uses HTTPS artwork', async () => {
  const result = await resolve(link, undefined, mock({ artwork: 'javascript:alert(1)' }));
  expect(result.candidates[0]?.artworkUrl).toBeNull();
});

test('cancellation stops an in-flight request', async () => {
  const controller = new AbortController();
  let stopped = false;
  const promise = resolve(link, controller.signal, async (_, init) => new Promise((_, reject) => {
    init.signal!.addEventListener('abort', () => { stopped = true; reject(init.signal!.reason); }, { once: true });
  }));
  controller.abort();
  await expect(promise).rejects.toMatchObject({ code: 'NETWORK' });
  expect(stopped).toBe(true);
});

test('bounds preview requests and preserves lookup order', async () => {
  const ids = Array.from({ length: 12 }, (_, i) => String(i).padStart(22, '0'));
  const base = mock({ ids });
  let active = 0, maxActive = 0, total = 0;
  const result = await resolve(link, undefined, async (url, init) => {
    if (url.hostname !== 'open.spotify.com') return base(url, init);
    active++; total++; maxActive = Math.max(maxActive, active);
    await new Promise(resolve => setTimeout(resolve, 5));
    active--;
    return base(url, init);
  });
  expect(total).toBe(8);
  expect(maxActive).toBeLessThanOrEqual(3);
  expect(result.candidates.map(c => c.url)).toEqual(ids.slice(0, 8).map(id => `https://open.spotify.com/track/${id}`));
});

test.each([
  ['appleMusic', { title: 'Savior (Official Video)', artist: 'RedHotChiliPeppersVEVO' }, 'https://music.apple.com/at/search?term=RedHotChiliPeppers+Savior'],
  ['youtubeMusic', { title: 'Red Hot Chili Peppers - Savior [Official Audio] (4K Remaster)', artist: 'Red Hot Chili Peppers' }, 'https://music.youtube.com/search?q=Red+Hot+Chili+Peppers+-+Savior'],
  ['spotify', { title: 'Savior (Live)', artist: 'Red Hot Chili Peppers' }, 'https://open.spotify.com/search/Red%20Hot%20Chili%20Peppers%20Savior%20(Live)'],
] as const)('search fallback for %s drops video noise', (target, source, url) => {
  expect(searchUrl(target, source, 'AT')).toBe(url);
});
