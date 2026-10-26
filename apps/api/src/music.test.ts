import { afterAll, afterEach, beforeAll, describe, expect, spyOn, test } from 'bun:test';
import * as monitoring from './monitoring';
import { friendsMessage } from '@app/shared';
import { resolve, resolveAll, sharePath, musicSource, type MusicSearch } from './lib/music';
import type { Fetch } from './lib/resolver';

const diagnostics = spyOn(monitoring, 'captureMessage').mockImplementation(() => 'test');
afterEach(() => diagnostics.mockClear());
afterAll(() => diagnostics.mockRestore());

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
  expect(musicSource(`Hör mal: ${input}`)).toEqual({ kind: 'song', platform: 'appleMusic', id: '945575419', country: 'DE' });
});
test.each(['https://music.apple.com/de/album/savior/945575406?i=', 'https://music.apple.com/library/playlist/123', `${apple} ${youtube}`, 'https://user@music.apple.com/de/song/123'])('rejects ambiguous or non-song link %s', input => {
  expect(() => musicSource(input)).toThrow();
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
  [spotify, { kind: 'song', platform: 'spotify', id: '2Foc5Q5nqNiosCNqttzHof', country: '' }],
  [deezer, { kind: 'song', platform: 'deezer', id: '67238735', country: '' }],
  ['https://deezer.com/track/67238735', { kind: 'song', platform: 'deezer', id: '67238735', country: '' }],
] as const)('accepts %s', (input, source) => expect(musicSource(input)).toEqual(source));
test.each(['https://open.spotify.com/artist/2Foc5Q5nqNiosCNqttzHof', 'https://open.spotify.com/album/short', 'https://open.spotify.com/track/short', 'https://www.deezer.com/de/playlist/123', 'https://deezer.com.evil.example/track/1'])('rejects %s', input => {
  expect(() => musicSource(input)).toThrow();
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

test('spotify.link short links resolve through their Branch page', async () => {
  const shortLink = (page: string) => resolve({ input: 'Hör mal https://spotify.link/6tpneu0iVIb', target: 'deezer', country: 'DE' }, undefined, async url => {
    if (url.hostname === 'spotify.app.link') {
      expect(url.pathname).toBe('/6tpneu0iVIb');
      return new Response(page);
    }
    if (url.hostname === 'open.spotify.com') {
      expect(url.pathname).toBe('/track/2Foc5Q5nqNiosCNqttzHof');
      return new Response('<meta property="og:title" content="Get Lucky (Radio Edit - feat. Pharrell Williams and Nile Rodgers)" /><meta name="music:musician_description" content="Daft Punk" />');
    }
    return Response.json({ data: [deezerTrack] });
  });
  const result = await shortLink('<a href="https://open.spotify.com/track/2Foc5Q5nqNiosCNqttzHof?si=x">Open</a>');
  expect(result.sharePath).toBe('/s/sp/2Foc5Q5nqNiosCNqttzHof');
  expect(result.candidates[0]!.url).toBe('https://www.deezer.com/track/67238735');
  await expect(shortLink('<a href="https://open.spotify.com/playlist/432nsnOM9L55tkiOFnHbI2">Open</a>')).rejects.toMatchObject({ code: 'INVALID_LINK' });
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

test('resolveAll finds every service once and falls back to search per service', async () => {
  let lookups = 0;
  const song = await resolveAll({ input: youtube, country: 'DE' }, undefined, async url => {
    if (url.hostname === 'www.youtube.com') { lookups++; return Response.json({ title: 'Savior', author_name: 'Red Hot Chili Peppers - Topic', thumbnail_url: 'https://i.ytimg.com/vi/UijW9hGpnzc/hqdefault.jpg' }); }
    if (url.hostname === 'itunes.apple.com') return Response.json({ results: [{ ...track, artworkUrl100: 'https://is1-ssl.mzstatic.com/image/100x100bb.jpg' }] });
    if (url.hostname === 'labs.api.listenbrainz.org') return Response.json([]);
    if (url.hostname === 'api.deezer.com') return new Response('', { status: 500 });
    throw new Error(url.hostname);
  }, async () => []);
  expect(lookups).toBe(1);
  expect(song.sharePath).toBe('/s/yt/UijW9hGpnzc');
  expect(song.source).toMatchObject({ platform: 'youtubeMusic', artworkUrl: 'https://is1-ssl.mzstatic.com/image/600x600bb.jpg' });
  expect(song.links).toEqual({
    youtubeMusic: { url: youtube, found: true },
    appleMusic: { url: apple, found: true },
    spotify: { url: 'https://open.spotify.com/search/Red%20Hot%20Chili%20Peppers%20Savior', found: false },
    deezer: { url: 'https://www.deezer.com/search/Red%20Hot%20Chili%20Peppers%20Savior', found: false },
  });
});

test.each([
  [youtube, '/s/yt/UijW9hGpnzc'], [apple, '/s/am/de/945575419'], [spotify, '/s/sp/2Foc5Q5nqNiosCNqttzHof'], [deezer, '/s/dz/67238735'],
])('share path for %s', (input, path) => expect(sharePath(musicSource(input))).toBe(path));

test('friends message has one link for one service and one line per service otherwise', () => {
  const song = { source: { kind: 'song' as const, platform: 'youtubeMusic' as const, title: 'Savior', artist: 'RHCP', url: youtube, artworkUrl: null }, sharePath: '/s/yt/UijW9hGpnzc', links: {
    youtubeMusic: { url: youtube, found: true }, appleMusic: { url: apple, found: true },
    spotify: { url: 'https://open.spotify.com/track/x', found: true }, deezer: { url: 'https://www.deezer.com/track/1', found: true },
  } };
  expect(friendsMessage(song, [{ name: 'Lisa', platform: 'spotify' }, { name: 'Ben', platform: 'spotify' }], 'https://musiclink.pleasance.org'))
    .toBe('🎵 Savior – RHCP\nhttps://open.spotify.com/track/x');
  expect(friendsMessage(song, [{ name: 'Lisa', platform: 'spotify' }, { name: 'Jonas', platform: 'appleMusic' }, { name: 'Ben', platform: 'spotify' }], 'https://musiclink.pleasance.org'))
    .toBe(`🎵 Savior – RHCP\nSpotify (Lisa, Ben): https://open.spotify.com/track/x\nApple Music (Jonas): ${apple}\nAndere: https://musiclink.pleasance.org/s/yt/UijW9hGpnzc`);
  expect(friendsMessage(song, [{ name: 'Lisa', platform: 'spotify' }, { name: 'Jonas', platform: 'appleMusic' }], 'https://songgate.app', { name: 'Robin Ö', platform: 'youtubeMusic' }).split('\n').at(-1))
    .toBe('Andere: https://songgate.app/s/yt/UijW9hGpnzc?from=Robin+%C3%96&service=youtube');
  expect(friendsMessage(song, [{ name: 'Lisa', platform: 'spotify' }], 'https://songgate.app', { name: 'Robin', platform: 'deezer' }))
    .toBe('🎵 Savior – RHCP\nhttps://open.spotify.com/track/x\nAlle Dienste: https://songgate.app/s/yt/UijW9hGpnzc?from=Robin&service=deezer');
  // Group chats: no service means the share page only, tapped services need no friends
  expect(friendsMessage(song, [], 'https://songgate.app', { name: 'Robin', platform: 'deezer' }, []))
    .toBe('🎵 Savior – RHCP\nhttps://songgate.app/s/yt/UijW9hGpnzc?from=Robin&service=deezer');
  expect(friendsMessage(song, [{ name: 'Lisa', platform: 'spotify' }], 'https://songgate.app', null, ['spotify', 'appleMusic']))
    .toBe(`🎵 Savior – RHCP\nSpotify (Lisa): https://open.spotify.com/track/x\nApple Music: ${apple}\nAndere: https://songgate.app/s/yt/UijW9hGpnzc`);
});

test('invalid source metadata reports only a fixed failure class and provider', async () => {
  await expect(resolve({ input: youtube, target: 'appleMusic', country: 'DE' }, undefined,
    async () => Response.json({ title: { private: 'private song title' }, author_name: 'private artist' })))
    .rejects.toMatchObject({ code: 'NETWORK' });
  expect(diagnostics.mock.calls).toEqual([
    ['Music provider failure', { level: 'warning', tags: { provider: 'youtubeMusic', failure: 'invalid_response' } }],
  ]);
});

test.each(['appleMusic', 'spotify', 'deezer'] as const)('invalid %s results preserve NETWORK and report the target', async target => {
  await expect(resolve({ input: youtube, target, country: 'DE' }, undefined, async (url, init) =>
    url.hostname === 'www.youtube.com' ? fetcher(url, init) : new Response('private upstream response')))
    .rejects.toMatchObject({ code: 'NETWORK' });
  expect(diagnostics.mock.calls).toEqual([
    ['Music provider failure', { level: 'warning', tags: { provider: target, failure: 'invalid_response' } }],
  ]);
});

test('a failed target keeps its search fallback without reporting the raw error', async () => {
  const result = await resolveAll({ input: apple, country: 'DE' }, undefined, async (url, init) => {
    if (url.hostname === 'itunes.apple.com') return fetcher(url, init);
    if (url.hostname === 'labs.api.listenbrainz.org') return Response.json([]);
    return Response.json({ data: [] });
  }, async () => { throw new Error('private song https://private.example/?token=private'); });
  expect(result.links.youtubeMusic.found).toBe(false);
  expect(result.links.youtubeMusic.url).toContain('music.youtube.com/search');
  expect(diagnostics.mock.calls).toEqual([
    ['Music provider failure', { level: 'warning', tags: { provider: 'youtubeMusic', failure: 'unexpected' } }],
  ]);
});

test('failed short-link requests report Spotify without the link or network error', async () => {
  await expect(resolve({ input: 'https://spotify.link/6tpneu0iVIb', target: 'appleMusic', country: 'DE' }, undefined,
    async () => { throw new TypeError('private request details'); }))
    .rejects.toMatchObject({ code: 'NETWORK' });
  expect(diagnostics.mock.calls).toEqual([
    ['Music provider failure', { level: 'warning', tags: { provider: 'spotify', failure: 'request_failed' } }],
  ]);
});

test('expected upstream failures and cancellation produce no diagnostic event', async () => {
  for (const status of [404, 429, 500]) {
    await expect(resolve({ input: youtube, target: 'appleMusic', country: 'DE' }, undefined,
      async () => new Response('', { status }))).rejects.toBeDefined();
  }
  const controller = new AbortController();
  controller.abort();
  await expect(resolve({ input: youtube, target: 'appleMusic', country: 'DE' }, controller.signal,
    async (_, init) => { init.signal!.throwIfAborted(); throw new Error('unreachable'); }))
    .rejects.toMatchObject({ code: 'NETWORK' });
  expect(diagnostics).not.toHaveBeenCalled();
});

describe('ISRC and UPC matching with a MusicKit key', async () => {
  const pair = await crypto.subtle.generateKey({ name: 'ECDSA', namedCurve: 'P-256' }, true, ['sign', 'verify']);
  const pkcs8 = Buffer.from(await crypto.subtle.exportKey('pkcs8', pair.privateKey)).toString('base64');
  const pem = `-----BEGIN PRIVATE KEY-----\n${pkcs8.match(/.{1,64}/g)!.join('\n')}\n-----END PRIVATE KEY-----\n`;
  beforeAll(() => Object.assign(process.env, { APPLE_MUSIC_TEAM_ID: 'TEAM123456', APPLE_MUSIC_KEY_ID: 'KEY1234567', APPLE_MUSIC_KEY_BASE64: Buffer.from(pem).toString('base64') }));
  afterAll(() => { delete process.env.APPLE_MUSIC_TEAM_ID; delete process.env.APPLE_MUSIC_KEY_ID; delete process.env.APPLE_MUSIC_KEY_BASE64; });

  const isrc = 'USQX91300108';
  const appleSong = (id: string, album: string, playable = true) => ({ id, attributes: {
    name: 'Get Lucky', url: `https://music.apple.com/de/album/get-lucky/1?i=${id}`, albumName: album, durationInMillis: 369629, isrc,
    artwork: { url: 'https://is1-ssl.mzstatic.com/image/thumb/a/{w}x{h}bb.jpg' }, ...(playable ? { playParams: { id } } : {}),
  } });
  const deezerSource = { ...deezerTrack, isrc };

  test('Deezer → Apple takes the original album by ISRC with a signed developer token', async () => {
    const result = await resolve({ input: deezer, target: 'appleMusic', country: 'AT' }, undefined, async (url, init) => {
      if (url.hostname === 'api.deezer.com') return Response.json(deezerSource);
      expect(url.hostname).toBe('api.music.apple.com');
      expect(url.pathname).toBe('/v1/catalog/at/songs');
      expect(url.searchParams.get('filter[isrc]')).toBe(isrc);
      const [header, payload, signature] = new Headers(init.headers).get('authorization')!.replace('Bearer ', '').split('.');
      expect(JSON.parse(Buffer.from(header!, 'base64url').toString())).toEqual({ alg: 'ES256', kid: 'KEY1234567' });
      expect(JSON.parse(Buffer.from(payload!, 'base64url').toString())).toMatchObject({ iss: 'TEAM123456' });
      expect(await crypto.subtle.verify({ name: 'ECDSA', hash: 'SHA-256' }, pair.publicKey, Buffer.from(signature!, 'base64url'), new TextEncoder().encode(`${header}.${payload}`))).toBe(true);
      return Response.json({ data: [appleSong('1445215790', 'NYE 2018/2019'), appleSong('617154366', 'Random Access Memories'), appleSong('100', 'Unavailable', false)] });
    });
    expect(result.candidates.map(candidate => candidate.url)).toEqual(['https://music.apple.com/de/album/get-lucky/1?i=617154366', 'https://music.apple.com/de/album/get-lucky/1?i=1445215790']);
    expect(result.candidates[0]).toMatchObject({ album: 'Random Access Memories', durationSeconds: 370, artworkUrl: 'https://is1-ssl.mzstatic.com/image/thumb/a/100x100bb.jpg' });
  });

  test('Apple → Deezer reads the ISRC from the Apple Music API and skips the text search', async () => {
    const result = await resolve({ input: apple, target: 'deezer', country: 'DE' }, undefined, async (url, init) => {
      if (url.hostname === 'api.music.apple.com') {
        expect(url.pathname).toBe('/v1/catalog/de/songs/945575419');
        return Response.json({ data: [appleSong('945575419', 'Californication')] });
      }
      if (url.hostname === 'api.deezer.com') {
        expect(url.pathname).toBe(`/track/isrc:${isrc}`);
        return Response.json(deezerSource);
      }
      return fetcher(url, init);
    });
    expect(result.candidates).toEqual([{ title: deezerTrack.title, url: 'https://www.deezer.com/track/67238735', album: 'Get Lucky', durationSeconds: 248, artworkUrl: 'https://cdn-images.dzcdn.net/cover.jpg' }]);
  });

  test('an unknown ISRC falls back to text matching, a rejected key is reported too', async () => {
    for (const apple of [Response.json({ data: [] }), new Response('', { status: 401 })]) {
      const result = await resolve({ input: deezer, target: 'appleMusic', country: 'DE' }, undefined, async url => {
        if (url.hostname === 'api.deezer.com') return Response.json({ ...deezerSource, title: 'Savior', artist: { name: 'Red Hot Chili Peppers' }, duration: 292 });
        if (url.hostname === 'api.music.apple.com') return apple;
        return Response.json({ results: [track] });
      });
      expect(result.candidates[0]!.url).toBe('https://music.apple.com/de/album/savior/945575406?i=945575419');
    }
    expect(diagnostics.mock.calls).toEqual([['ISRC lookup failure', { level: 'warning', tags: { provider: 'appleMusic' } }]]);
  });

  // Albums carry a UPC, which the same key reads
  const album = 'https://music.apple.com/de/album/random-access-memories/617154241';
  const deezerAlbumLink = 'https://www.deezer.com/de/album/6575789';
  const collection = { wrapperType: 'collection', collectionId: 617154241, collectionName: 'Random Access Memories', artistName: 'Daft Punk', collectionViewUrl: album };
  const deezerAlbum = { id: 6575789, title: 'Random Access Memories', upc: '886443927087', artist: { name: 'Daft Punk' }, cover_medium: 'https://cdn-images.dzcdn.net/ram/250.jpg' };

  test('Apple → Deezer takes the album by its UPC and skips the text search', async () => {
    const result = await resolve({ input: album, target: 'deezer', country: 'DE' }, undefined, async url => {
      if (url.hostname === 'api.music.apple.com') {
        expect(url.pathname).toBe('/v1/catalog/de/albums/617154241');
        return Response.json({ data: [{ attributes: { name: 'Random Access Memories', artistName: 'Daft Punk', url: album, upc: '886443927087' } }] });
      }
      if (url.hostname === 'itunes.apple.com') return Response.json({ results: [collection] });
      expect(url.pathname).toBe('/album/upc:886443927087');
      return Response.json(deezerAlbum);
    });
    expect(result.candidates).toEqual([{ title: 'Random Access Memories', url: 'https://www.deezer.com/album/6575789', artworkUrl: 'https://cdn-images.dzcdn.net/ram/250.jpg' }]);
  });

  test('Deezer → Apple by UPC, a rejected key falls back to text and is reported', async () => {
    for (const answer of [Response.json({ data: [{ attributes: { name: 'Random Access Memories', artistName: 'Daft Punk', url: `${album}?l=en`, playParams: { id: '617154241' } } }] }), new Response('', { status: 401 })]) {
      const result = await resolve({ input: deezerAlbumLink, target: 'appleMusic', country: 'DE' }, undefined, async url => {
        if (url.hostname === 'api.deezer.com') return Response.json(deezerAlbum);
        if (url.hostname === 'api.music.apple.com') {
          expect(url.searchParams.get('filter[upc]')).toBe('886443927087');
          return answer;
        }
        return Response.json({ results: [collection] });
      });
      expect(result.candidates[0]!.url).toBe(album);
    }
    expect(diagnostics.mock.calls).toEqual([['UPC lookup failure', { level: 'warning', tags: { provider: 'appleMusic' } }]]);
  });
});
