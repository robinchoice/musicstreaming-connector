import { afterAll, afterEach, expect, spyOn, test } from 'bun:test';
import fc from 'fast-check';
import * as monitoring from './monitoring';
import { friendsMessage, type Song } from '@app/shared';
import type { YouTubeAlbums } from './lib/albums';
import { musicSource, resolve, resolveAll, sharePath, type MusicSearch } from './lib/music';
import { episodeScore, showScore, type YouTubePodcasts } from './lib/podcasts';
import { ResolutionError, type Fetch } from './lib/resolver';

const diagnostics = spyOn(monitoring, 'captureMessage').mockImplementation(() => 'test');
afterEach(() => diagnostics.mockClear());
afterAll(() => diagnostics.mockRestore());

const appleShowLink = 'https://podcasts.apple.com/de/podcast/the-daily/id1200361736';
const appleEpisodeLink = `${appleShowLink.replace('the-daily', 'a-landslide-victory-for-democrats')}?i=1000799791974&uo=4`;
const released = '2026-11-04T10:51:00Z';
const show = { wrapperType: 'track', kind: 'podcast', collectionId: 1200361736, collectionName: 'The Daily', artistName: 'The New York Times', feedUrl: 'https://feeds.simplecast.com/Sl5CSM3S', artworkUrl600: 'https://is1-ssl.mzstatic.com/daily/600x600bb.jpg' };
const episode = { wrapperType: 'podcastEpisode', kind: 'podcast-episode', trackId: 1000799791974, trackName: 'A Landslide Victory for Democrats', collectionId: 1200361736, collectionName: 'The Daily', releaseDate: released, trackTimeMillis: 2082000, feedUrl: show.feedUrl, artworkUrl600: 'https://is1-ssl.mzstatic.com/episode/600x600bb.jpg' };
const deezerShow = { id: 52913, title: 'The Daily', available: true, picture_medium: 'https://cdn-images.dzcdn.net/daily/250.jpg', picture_xl: 'https://cdn-images.dzcdn.net/daily/1000.jpg' };
const deezerEpisode = { id: 957764821, title: 'A Landslide Victory for Democrats', release_date: '2026-11-04 10:51:32', duration: 2224, available: true, picture_xl: 'https://cdn-images.dzcdn.net/episode/1000.jpg', podcast: { id: 52913, title: 'The Daily' } };
const noSongs: MusicSearch = async () => [];
const noAlbums: YouTubeAlbums = { search: async () => [], album: async () => { throw new Error('unused'); } };
const youtube = (overrides: Partial<YouTubePodcasts> = {}): YouTubePodcasts => ({
  episode: async () => null,
  show: async () => { throw new Error('unused'); },
  shows: async () => [],
  episodes: async () => [],
  ...overrides,
});
// Routes by host and path, anything else fails the test
const services = (routes: Record<string, (url: URL, init: RequestInit) => unknown>): Fetch => async (url, init) => {
  const route = routes[`${url.hostname}${url.pathname}`];
  if (!route) throw new Error(`unexpected ${url}`);
  const body = route(url, init);
  return body instanceof Response ? body : Response.json(body);
};

test.each([
  [appleShowLink, { kind: 'podcast', platform: 'appleMusic', id: '1200361736', country: 'DE' }, '/s/podcast/am/de/1200361736'],
  ['https://podcasts.apple.com/podcast/id1200361736', { kind: 'podcast', platform: 'appleMusic', id: '1200361736', country: 'US' }, '/s/podcast/am/us/1200361736'],
  [appleEpisodeLink, { kind: 'episode', platform: 'appleMusic', id: '1000799791974', country: 'DE', show: '1200361736' }, '/s/episode/am/de/1200361736/1000799791974'],
  ['https://open.spotify.com/show/3IM0lmZxpFAY7CwMuv9H4g?si=x', { kind: 'podcast', platform: 'spotify', id: '3IM0lmZxpFAY7CwMuv9H4g', country: '' }, '/s/podcast/sp/3IM0lmZxpFAY7CwMuv9H4g'],
  ['https://open.spotify.com/intl-de/episode/5UxOyOLAC4usAfIblpKROk', { kind: 'episode', platform: 'spotify', id: '5UxOyOLAC4usAfIblpKROk', country: '' }, '/s/episode/sp/5UxOyOLAC4usAfIblpKROk'],
  ['https://www.deezer.com/de/show/52913', { kind: 'podcast', platform: 'deezer', id: '52913', country: '' }, '/s/podcast/dz/52913'],
  ['https://www.deezer.com/episode/957764821', { kind: 'episode', platform: 'deezer', id: '957764821', country: '' }, '/s/episode/dz/957764821'],
  ['https://music.youtube.com/playlist?list=PLdMrbgYfVl-s16D_iT2BJCJ90pWtTO1A4', { kind: 'podcast', platform: 'youtubeMusic', id: 'PLdMrbgYfVl-s16D_iT2BJCJ90pWtTO1A4', country: '' }, '/s/podcast/yt/PLdMrbgYfVl-s16D_iT2BJCJ90pWtTO1A4'],
  ['https://music.youtube.com/browse/MPSPPLdMrbgYfVl-s16D_iT2BJCJ90pWtTO1A4', { kind: 'podcast', platform: 'youtubeMusic', id: 'PLdMrbgYfVl-s16D_iT2BJCJ90pWtTO1A4', country: '' }, '/s/podcast/yt/PLdMrbgYfVl-s16D_iT2BJCJ90pWtTO1A4'],
] as const)('accepts podcast link %s', (input, source, path) => {
  expect(musicSource(`Hör mal: ${input}`)).toEqual(source);
  expect(sharePath(source)).toBe(path);
});
test.each([
  'https://podcasts.apple.com/de/podcast/the-daily',
  'https://podcasts.apple.com/de/podcast/the-daily/id1200361736?i=abc',
  'https://podcasts.apple.com/de/artist/the-new-york-times/121664449',
  'https://user@podcasts.apple.com/de/podcast/id1200361736',
  'https://open.spotify.com/show/short',
])('rejects podcast link %s', input => expect(() => musicSource(input)).toThrow());

test('an Apple episode is found by show, title and date, and names the other podcast apps', async () => {
  const fetcher = services({
    'itunes.apple.com/lookup': url => {
      expect(url.searchParams.get('id')).toBe('1200361736');
      expect(url.searchParams.get('entity')).toBe('podcastEpisode');
      return { results: [show, { ...episode, trackId: 1, trackName: 'Older' }, episode] };
    },
    'api.deezer.com/search/podcast': url => {
      expect(url.searchParams.get('q')).toBe('The Daily');
      return { data: [{ ...deezerShow, id: 1, title: 'The Daily T' }, deezerShow] };
    },
    'api.deezer.com/podcast/52913/episodes': () => ({ data: [{ ...deezerEpisode, id: 1, release_date: '2026-10-01 10:00:00' }, deezerEpisode], total: 2 }),
  });
  const podcasts = youtube({
    episodes: async query => {
      expect(query).toBe('The Daily A Landslide Victory for Democrats');
      return [
        { id: 'aaaaaaaaaaa', title: 'A Landslide Victory for Democrats', show: 'The Daily T Podcast', artworkUrl: null },
        { id: 'OfYuvCcw5ho', title: 'A Landslide Victory for Democrats', show: 'The Daily', artworkUrl: 'https://i.ytimg.com/episode.jpg' },
      ];
    },
  });
  const song = await resolveAll({ input: appleEpisodeLink, country: 'DE' }, undefined, fetcher, noSongs, noAlbums, podcasts);
  expect(song.source).toEqual({ kind: 'episode', platform: 'appleMusic', title: 'A Landslide Victory for Democrats', artist: 'The Daily', url: 'https://podcasts.apple.com/de/podcast/id1200361736?i=1000799791974', artworkUrl: episode.artworkUrl600 });
  expect(song.sharePath).toBe('/s/episode/am/de/1200361736/1000799791974');
  expect(song.links).toEqual({
    appleMusic: { url: 'https://podcasts.apple.com/de/podcast/id1200361736?i=1000799791974', found: true },
    youtubeMusic: { url: 'https://music.youtube.com/watch?v=OfYuvCcw5ho', found: true },
    // No Spotify key: a search only
    spotify: { url: 'https://open.spotify.com/search/The%20Daily%20A%20Landslide%20Victory%20for%20Democrats', found: false },
    deezer: { url: 'https://www.deezer.com/episode/957764821', found: true },
    tidal: { url: 'https://tidal.com/search?q=The+Daily+A+Landslide+Victory+for+Democrats', found: false },
    amazonMusic: { url: 'https://music.amazon.de/search/The%20Daily%20A%20Landslide%20Victory%20for%20Democrats', found: false },
  });
  expect(song.apps).toEqual([
    { name: 'Overcast', url: 'https://overcast.fm/itunes1200361736' },
    { name: 'Pocket Casts', url: 'https://pca.st/itunes/1200361736' },
    { name: 'Castro', url: 'https://castro.fm/itunes/1200361736' },
    { name: 'AntennaPod', url: 'https://antennapod.org/deeplink/subscribe?url=https%3A%2F%2Ffeeds.simplecast.com%2FSl5CSM3S' },
    { name: 'RSS', url: 'https://feeds.simplecast.com/Sl5CSM3S' },
  ]);
});

test('a Spotify episode finds Apple by its show, a rerun with another date does not count', async () => {
  const page = '<meta property="og:title" content="A Landslide Victory for Democrats"/><meta property="og:description" content="The Daily · Episode"/><meta name="music:release_date" content="2026-11-04T10:51:00Z"/><meta name="music:duration" content="2080"/><meta property="og:image" content="https://i.scdn.co/image/daily"/>';
  const fetcher = services({
    'open.spotify.com/episode/5UxOyOLAC4usAfIblpKROk': () => new Response(page),
    'itunes.apple.com/search': url => url.searchParams.get('entity') === 'podcast'
      ? { results: [{ ...show, collectionId: 2, collectionName: 'Daily Expresso' }, show] }
      : { results: [{ ...episode, trackId: 3, releaseDate: '2026-11-20T10:00:00Z' }, { ...episode, collectionId: 2 }, episode] },
  });
  const result = await resolve({ input: 'https://open.spotify.com/episode/5UxOyOLAC4usAfIblpKROk', target: 'appleMusic', country: 'DE' }, undefined, fetcher, noSongs, noAlbums, youtube());
  expect(result.source).toEqual({ kind: 'episode', title: 'A Landslide Victory for Democrats', artist: 'The Daily', url: 'https://open.spotify.com/episode/5UxOyOLAC4usAfIblpKROk' });
  expect(result.candidates.map(candidate => candidate.url)).toEqual(['https://podcasts.apple.com/de/podcast/id1200361736?i=1000799791974']);
  expect(result.sharePath).toBe('/s/episode/sp/5UxOyOLAC4usAfIblpKROk');
});

test('with a Spotify key a Deezer episode finds its Spotify show and episode', async () => {
  process.env.SPOTIFY_CLIENT_ID = 'client';
  process.env.SPOTIFY_CLIENT_SECRET = 'secret';
  try {
    const fetcher = services({
      'api.deezer.com/episode/957764821': () => deezerEpisode,
      'accounts.spotify.com/api/token': (_, init) => {
        expect(init.method).toBe('POST');
        return { access_token: 'token', expires_in: 3600 };
      },
      'api.spotify.com/v1/search': (url, init) => {
        expect(new Headers(init.headers).get('authorization')).toBe('Bearer token');
        expect(url.searchParams.get('type')).toBe('show');
        return { shows: { items: [null, { id: '1IM0lmZxpFAY7CwMuv9H4g', name: 'The Daily T', publisher: 'Telegraph', images: [] }, { id: '3IM0lmZxpFAY7CwMuv9H4g', name: 'The Daily', publisher: 'The New York Times', images: [] }] } };
      },
      'api.spotify.com/v1/shows/3IM0lmZxpFAY7CwMuv9H4g/episodes': () => ({ items: [{ id: '5UxOyOLAC4usAfIblpKROk', name: 'A Landslide Victory for Democrats', release_date: '2026-11-04', images: [{ url: 'https://i.scdn.co/image/episode' }] }] }),
    });
    const result = await resolve({ input: 'https://www.deezer.com/episode/957764821', target: 'spotify', country: 'DE' }, undefined, fetcher, noSongs, noAlbums, youtube());
    expect(result.candidates).toEqual([{ title: 'A Landslide Victory for Democrats', url: 'https://open.spotify.com/episode/5UxOyOLAC4usAfIblpKROk', artworkUrl: 'https://i.scdn.co/image/episode' }]);
  } finally {
    delete process.env.SPOTIFY_CLIENT_ID;
    delete process.env.SPOTIFY_CLIENT_SECRET;
  }
});

test('a YouTube video that is a podcast episode becomes one, other videos stay songs', async () => {
  const podcasts = youtube({
    episode: async id => id === 'OfYuvCcw5ho' ? { title: 'A Landslide Victory for Democrats', artist: 'The Daily', show: 'The Daily', url: `https://music.youtube.com/watch?v=${id}`, artworkUrl: null, released: Date.parse(released) } : null,
  });
  const fetcher = services({
    'www.youtube.com/oembed': () => ({ title: 'Never Gonna Give You Up', author_name: 'Rick Astley - Topic' }),
    'itunes.apple.com/search': url => url.searchParams.get('entity') === 'podcast' ? { results: [show] }
      : url.searchParams.get('entity') === 'podcastEpisode' ? { results: [episode] } : { results: [] },
  });
  const result = await resolve({ input: 'https://youtu.be/OfYuvCcw5ho', target: 'appleMusic', country: 'DE' }, undefined, fetcher, noSongs, noAlbums, podcasts);
  expect(result.source.kind).toBe('episode');
  expect(result.sharePath).toBe('/s/episode/yt/OfYuvCcw5ho');
  await expect(resolve({ input: 'https://youtu.be/dQw4w9WgXcQ', target: 'appleMusic', country: 'DE' }, undefined, fetcher, noSongs, noAlbums, podcasts))
    .rejects.toMatchObject({ code: 'NO_MATCH', searchUrl: 'https://music.apple.com/de/search?term=Rick+Astley+Never+Gonna+Give+You+Up' });
  // A failed check leaves a song
  const broken = youtube({ episode: async () => { throw new TypeError('fetch failed'); } });
  await expect(resolve({ input: 'https://youtu.be/dQw4w9WgXcQ', target: 'appleMusic', country: 'DE' }, undefined, fetcher, noSongs, noAlbums, broken))
    .rejects.toMatchObject({ code: 'NO_MATCH' });
});

test('a YouTube playlist that is no podcast is not supported', async () => {
  const podcasts = youtube({ show: async () => { throw new ResolutionError('UNSUPPORTED_LINK'); } });
  await expect(resolve({ input: 'https://music.youtube.com/playlist?list=PLx0sYbCqOb8TBPRdmBHs5Iftvv9TPboYG', target: 'appleMusic', country: 'DE' }, undefined, services({}), noSongs, noAlbums, podcasts))
    .rejects.toMatchObject({ code: 'UNSUPPORTED_LINK' });
});

test('an Apple episode older than the lookup comes from its page, behind Apple redirect', async () => {
  const pageUrl = 'https://podcasts.apple.com/de/podcast/old-one/id1200361736?i=1000536795154';
  const fetcher = services({
    'itunes.apple.com/lookup': () => ({ results: [show, episode] }),
    'podcasts.apple.com/de/podcast/id1200361736': (url, init) => {
      expect(init.redirect).toBe('manual');
      return new Response(null, { status: 301, headers: { location: pageUrl } });
    },
    'podcasts.apple.com/de/podcast/old-one/id1200361736': () => new Response('<meta property="og:title" content="An Old One &amp; More"/><meta property="og:description" content="Podcast-Folge · The Daily · 27. September 2021 · 35 Min."/><script>{"datePublished":"2021-09-27"}</script>'),
    'itunes.apple.com/search': () => ({ results: [] }),
  });
  const result = await resolve({ input: 'https://podcasts.apple.com/de/podcast/x/id1200361736?i=1000536795154', target: 'deezer', country: 'DE' }, undefined, async (url, init) => {
    if (url.hostname === 'api.deezer.com') return Response.json({ data: [] });
    return fetcher(url, init);
  }, noSongs, noAlbums, youtube()).catch((error: unknown) => error);
  expect(result).toMatchObject({ code: 'NO_MATCH', searchUrl: 'https://www.deezer.com/search/The%20Daily%20An%20Old%20One%20%26%20More' });
});

test('an old Deezer episode is looked for where the show’s pace puts it', async () => {
  // One episode a week, 400 in all, the newest first
  const at = (index: number) => new Date(Date.parse('2026-11-01T00:00:00Z') - index * 7 * 86_400_000).toISOString();
  const pages: string[] = [];
  const fetcher = services({
    'itunes.apple.com/lookup': () => ({ results: [show, { ...episode, trackName: 'Episode 250', releaseDate: at(250) }] }),
    'api.deezer.com/search/podcast': () => ({ data: [deezerShow] }),
    'api.deezer.com/podcast/52913/episodes': url => {
      const index = Number(url.searchParams.get('index'));
      pages.push(String(index));
      return { data: Array.from({ length: 100 }, (_, i) => ({ id: 1000 + index + i, title: `Episode ${index + i}`, release_date: at(index + i).replace('T', ' ').slice(0, 19) })), total: 400 };
    },
  });
  const result = await resolve({ input: appleEpisodeLink, target: 'deezer', country: 'DE' }, undefined, fetcher, noSongs, noAlbums, youtube());
  expect(pages).toEqual(['0', '200']);
  expect(result.candidates.map(candidate => candidate.url)).toEqual(['https://www.deezer.com/episode/1250']);
});

test('show names match in full or by their first part', () => {
  expect(showScore('The Daily', 'Daily')).toBe(2);
  expect(showScore('Hotel Matze Podcast', 'hotel matze')).toBe(2);
  expect(showScore('Lage der Nation - der Politik-Podcast aus Berlin', 'Lage der Nation')).toBe(1);
  expect(showScore('Alle Folgen | Baywatch Berlin', 'Baywatch Berlin')).toBe(1);
  expect(showScore('The Daily T', 'The Daily')).toBe(0);
  expect(showScore('', '')).toBe(0);
  const name = fc.string({ minLength: 4 }).filter(value => /\p{L}{4}/u.test(value));
  fc.assert(fc.property(name, name, (a, b) => showScore(a, a) === 2 && showScore(a, b) === showScore(b, a)));
});

test('episode titles match in full, contained or not, and dates far apart never', () => {
  const at = Date.parse(released);
  const score = episodeScore({ title: 'A Landslide Victory for Democrats', artist: '', show: 'The Daily', url: '', artworkUrl: null, released: at });
  expect(score('A Landslide Victory for Democrats', at + 3600_000)).toBe(2);
  expect(score('#12 A Landslide Victory for Democrats | The Daily')).toBe(1);
  expect(score('A Landslide Victory for Democrats', at + 5 * 86_400_000)).toBe(0);
  expect(score('Democrats')).toBe(0);
  fc.assert(fc.property(fc.string({ minLength: 1 }).filter(value => /\p{L}/u.test(value)), fc.integer({ min: 0, max: 2e12 }), (title, time) =>
    episodeScore({ title, artist: '', show: '', url: '', artworkUrl: null, released: time })(title, time) === 2));
});

test('a podcast message names Apple Podcasts and gives a TIDAL friend the share page', () => {
  const song: Song = {
    source: { kind: 'podcast', platform: 'deezer', title: 'The Daily', artist: '', url: 'https://www.deezer.com/show/52913', artworkUrl: null },
    sharePath: '/s/podcast/dz/52913',
    links: {
      appleMusic: { url: 'https://podcasts.apple.com/de/podcast/id1200361736', found: true }, youtubeMusic: { url: 'https://music.youtube.com/playlist?list=PL1', found: true },
      spotify: { url: 'https://open.spotify.com/search/The%20Daily', found: false }, deezer: { url: 'https://www.deezer.com/show/52913', found: true },
      tidal: { url: 'https://tidal.com/search?q=The+Daily', found: false }, amazonMusic: { url: 'https://music.amazon.de/search/The%20Daily', found: false },
    },
  };
  const friends = [{ name: 'Lisa', platform: 'appleMusic' as const }, { name: 'Ben', platform: 'tidal' as const }, { name: 'Jo', platform: 'deezer' as const }];
  expect(friendsMessage(song, friends, 'https://songgate.app'))
    .toBe('🎙️ The Daily\nApple Podcasts (Lisa): https://podcasts.apple.com/de/podcast/id1200361736\nDeezer (Jo): https://www.deezer.com/show/52913\nAndere: https://songgate.app/s/podcast/dz/52913\n\nGeteilt mit songgate.app');
  expect(friendsMessage(song, [friends[1]!], 'https://songgate.app'))
    .toBe('🎙️ The Daily\nhttps://songgate.app/s/podcast/dz/52913\n\nGeteilt mit songgate.app');
});
