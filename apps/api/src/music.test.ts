import { expect, test } from 'bun:test';
import { resolve, songSource, type MusicSearch } from './lib/music';
import type { Fetch } from './lib/resolver';

const youtube = 'https://music.youtube.com/watch?v=UijW9hGpnzc';
const apple = 'https://music.apple.com/de/album/savior/945575406?i=945575419';
const track = { wrapperType: 'track', kind: 'song', trackId: 945575419, trackName: 'Savior', artistName: 'Red Hot Chili Peppers', trackViewUrl: `${apple}&uo=4`, collectionName: 'Californication', trackTimeMillis: 292198, isStreamable: true };
const song = { id: 'UijW9hGpnzc', title: 'Savior', artists: ['Red Hot Chili Peppers'], durationSeconds: 293, album: 'Californication', artworkUrl: null };
const fetcher: Fetch = async url => Response.json(url.hostname === 'www.youtube.com' ? { title: 'Savior', author_name: 'Red Hot Chili Peppers - Topic' } : { results: [track] });

test('YouTube → Apple uses the chosen storefront, filters versions and cleans tracking', async () => {
  const result = await resolve({ input: youtube, target: 'appleMusic', country: 'AT' }, undefined, async (url, init) => {
    if (url.pathname === '/search') {
      expect(url.searchParams.get('country')).toBe('AT');
      return Response.json({ results: [track, track, { ...track, trackName: 'Savior (Live)' }, { ...track, artistName: 'Cover Artist' }, { ...track, isStreamable: false }, { ...track, trackViewUrl: 'https://evil.example/song' }] });
    }
    return fetcher(url, init);
  });
  expect(result.target).toBe('appleMusic');
  expect(result.candidates).toHaveLength(1);
  expect(result.candidates[0]).toMatchObject({ url: apple, album: 'Californication', durationSeconds: 292 });
});

test('Apple → YouTube uses source storefront and matches artist, version and duration', async () => {
  const search: MusicSearch = async (query, signal) => {
    expect(query).toBe('Red Hot Chili Peppers Savior');
    expect(signal.aborted).toBe(false);
    return [song, song, { ...song, id: 'nAYaCX4Bdpo', durationSeconds: 280 }, { ...song, title: 'Savior (Live)' }, { ...song, artists: ['Cover Artist'] }];
  };
  const result = await resolve({ input: apple, target: 'youtubeMusic', country: 'US' }, undefined, async (url, init) => {
    expect(url.searchParams.get('country')).toBe('DE');
    expect(url.searchParams.get('id')).toBe('945575419');
    return fetcher(url, init);
  }, search);
  expect(result.candidates).toHaveLength(1);
  expect(result.candidates[0]!.url).toBe(youtube);
});

test.each([apple, 'https://music.apple.com/de/song/savior/945575419', 'https://music.apple.com/de/song/945575419'])('accepts Apple song form %s', input => {
  expect(songSource(`Hör mal: ${input}`)).toEqual({ platform: 'appleMusic', id: '945575419', country: 'DE' });
});
test.each(['https://music.apple.com/de/album/savior/945575406', 'https://music.apple.com/library/playlist/123', `${apple} ${youtube}`, 'https://user@music.apple.com/de/song/123'])('rejects ambiguous or non-song link %s', input => {
  expect(() => songSource(input)).toThrow();
});
test('rejects same source and destination before network calls', async () => {
  await expect(resolve({ input: apple, target: 'appleMusic', country: 'DE' })).rejects.toMatchObject({ code: 'UNSUPPORTED_LINK' });
});
test('reports no match with a search fallback instead of an incorrect recording', async () => {
  await expect(resolve({ input: apple, target: 'youtubeMusic', country: 'DE' }, undefined, fetcher, async () => [])).rejects.toMatchObject({ code: 'NO_MATCH', searchUrl: 'https://music.youtube.com/search?q=Red+Hot+Chili+Peppers+Savior' });
});
test.each([[429, 'RATE_LIMITED'], [404, 'SOURCE_UNAVAILABLE'], [500, 'NETWORK']] as const)('preserves upstream status %s', async (status, code) => {
  await expect(resolve({ input: apple, target: 'youtubeMusic', country: 'DE' }, undefined, async () => new Response('', { status }))).rejects.toMatchObject({ code });
});
test('propagates cancellation to provider requests', async () => {
  const controller = new AbortController();
  controller.abort();
  await expect(resolve({ input: youtube, target: 'appleMusic', country: 'DE' }, controller.signal, async (_, init) => {
    expect(init.signal?.aborted).toBe(true);
    init.signal?.throwIfAborted();
    throw new Error('unreachable');
  })).rejects.toMatchObject({ code: 'NETWORK' });
});


test('featured credits may move between title and artist without conflating editions', async () => {
  const sourceTitle = 'Get Lucky (feat. Pharrell Williams and Nile Rodgers)';
  const original = { ...track, trackName: 'Get Lucky', artistName: 'Daft Punk, Pharrell Williams & Nile Rodgers', trackTimeMillis: 369629 };
  const fetchCredits: Fetch = async url => Response.json(url.hostname === 'www.youtube.com'
    ? { title: sourceTitle, author_name: 'Daft Punk - Topic' }
    : { results: [original, { ...original, trackName: 'Get Lucky (Drumless Edition)' }, { ...original, trackName: 'Get Lucky (Radio Edit - feat. Pharrell Williams and Nile Rodgers)' }, { ...original, artistName: 'Daft Punk, Other Singer & Nile Rodgers' }] });
  const appleResult = await resolve({ input: youtube, target: 'appleMusic', country: 'DE' }, undefined, fetchCredits);
  expect(appleResult.candidates).toHaveLength(1);
  const youtubeResult = await resolve({ input: apple, target: 'youtubeMusic', country: 'DE' }, undefined, fetchCredits, async () => [
    { ...song, title: sourceTitle, artists: ['Daft Punk', 'Pharrell Williams', 'Nile Rodgers'], durationSeconds: 370 },
    { ...song, title: 'Get Lucky (Radio Edit - feat. Pharrell Williams and Nile Rodgers)', artists: ['Daft Punk', 'Pharrell Williams', 'Nile Rodgers'], durationSeconds: 249 },
  ]);
  expect(youtubeResult.candidates).toHaveLength(1);
});

const spotify = 'https://open.spotify.com/intl-de/track/2Foc5Q5nqNiosCNqttzHof?si=tracking';
const deezer = 'https://www.deezer.com/de/track/67238735';
const deezerTrack = { id: 67238735, title: 'Get Lucky (Radio Edit - feat. Pharrell Williams and Nile Rodgers)', duration: 248, readable: true, artist: { name: 'Daft Punk' }, album: { title: 'Get Lucky', cover_medium: 'https://cdn-images.dzcdn.net/cover.jpg' } };

test.each([
  [spotify, { platform: 'spotify', id: '2Foc5Q5nqNiosCNqttzHof', country: '' }],
  [deezer, { platform: 'deezer', id: '67238735', country: '' }],
  ['https://deezer.com/track/67238735', { platform: 'deezer', id: '67238735', country: '' }],
] as const)('accepts %s', (input, source) => expect(songSource(input)).toEqual(source));
test.each(['https://open.spotify.com/album/2Foc5Q5nqNiosCNqttzHof', 'https://open.spotify.com/track/short', 'https://www.deezer.com/de/playlist/123', 'https://deezer.com.evil.example/track/1'])('rejects %s', input => {
  expect(() => songSource(input)).toThrow();
});

test('Spotify → Deezer reads the track page and matches artist, version and duration', async () => {
  const result = await resolve({ input: spotify, target: 'deezer', country: 'DE' }, undefined, async url => {
    if (url.hostname === 'open.spotify.com') {
      expect(url.pathname).toBe('/track/2Foc5Q5nqNiosCNqttzHof');
      expect(url.search).toBe('');
      return new Response('<meta property="og:title" content="Get Lucky (Radio Edit) [feat. Pharrell Williams and Nile Rodgers]" /><meta name="music:duration" content="248" /><meta name="music:musician_description" content="Daft Punk, Pharrell Williams, Nile Rodgers" />');
    }
    expect(url.searchParams.get('q')).toBe('Daft Punk, Pharrell Williams, Nile Rodgers Get Lucky (Radio Edit)');
    return Response.json({ data: [
      deezerTrack,
      { ...deezerTrack, id: 1, title: 'Get Lucky (Radio Edit) [feat. Pharrell Williams and Nile Rodgers]', artist: { name: 'Daft Punk, Pharrell Williams & Nile Rodgers' }, duration: 369 },
      { ...deezerTrack, id: 2, title: 'Get Lucky (Radio Edit) [feat. Pharrell Williams and Nile Rodgers]', artist: { name: 'Daft Punk, Pharrell Williams & Nile Rodgers' }, readable: false },
    ] });
  });
  expect(result.source).toMatchObject({ title: 'Get Lucky (Radio Edit) [feat. Pharrell Williams and Nile Rodgers]', artist: 'Daft Punk, Pharrell Williams, Nile Rodgers', url: 'https://open.spotify.com/track/2Foc5Q5nqNiosCNqttzHof' });
  expect(result.candidates).toEqual([{ title: deezerTrack.title, url: 'https://www.deezer.com/track/67238735', album: 'Get Lucky', durationSeconds: 248, artworkUrl: 'https://cdn-images.dzcdn.net/cover.jpg' }]);
});

test('Deezer → Spotify looks up the source and reports unknown tracks', async () => {
  const result = await resolve({ input: deezer, target: 'spotify', country: 'DE' }, undefined, async url => {
    if (url.hostname === 'api.deezer.com') return Response.json({ ...deezerTrack, title: 'Savior', artist: { name: 'Red Hot Chili Peppers' } });
    if (url.hostname === 'labs.api.listenbrainz.org') {
      expect(url.searchParams.get('artist_name')).toBe('Red Hot Chili Peppers');
      return Response.json([{ spotify_track_ids: ['0O8RjwNco465s5o9Ix9IYj'] }]);
    }
    return Response.json({ title: 'Savior', thumbnail_url: null });
  });
  expect(result.candidates[0]!.url).toBe('https://open.spotify.com/track/0O8RjwNco465s5o9Ix9IYj');
  await expect(resolve({ input: deezer, target: 'spotify', country: 'DE' }, undefined, async () => Response.json({ error: { code: 800 } }))).rejects.toMatchObject({ code: 'SOURCE_UNAVAILABLE' });
});
