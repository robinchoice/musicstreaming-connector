import { afterAll, afterEach, expect, spyOn, test } from 'bun:test';
import * as monitoring from './monitoring';
import { friendsMessage } from '@app/shared';
import type { YouTubeAlbums } from './lib/albums';
import { musicSource, resolve, resolveAll, sharePath } from './lib/music';
import type { Fetch } from './lib/resolver';

const diagnostics = spyOn(monitoring, 'captureMessage').mockImplementation(() => 'test');
afterEach(() => diagnostics.mockClear());
afterAll(() => diagnostics.mockRestore());

const apple = 'https://music.apple.com/de/album/random-access-memories/617154241';
const deezer = 'https://www.deezer.com/de/album/6575789';
const spotify = 'https://open.spotify.com/intl-de/album/4m2880jivSbbyEGAKfITCa?si=tracking';
const youtube = 'https://music.youtube.com/playlist?list=OLAK5uy_kNhM2yaBTOVwrcZJepB1C9P3-n5_Sfy5c&si=tracking';
const collection = { wrapperType: 'collection', collectionId: 617154241, collectionName: 'Random Access Memories', artistName: 'Daft Punk', collectionViewUrl: `${apple}?uo=4`, artworkUrl100: 'https://is1-ssl.mzstatic.com/ram/100x100bb.jpg' };
const deezerAlbum = { id: 6575789, title: 'Random Access Memories', upc: '886443927087', artist: { name: 'Daft Punk' }, cover_medium: 'https://cdn-images.dzcdn.net/ram/250.jpg', cover_xl: 'https://cdn-images.dzcdn.net/ram/1000.jpg', tracks: { data: [{ title: 'Give Life Back to Music' }] } };
const spotifyAlbum = '<meta property="og:title" content="Listen to Random Access Memories - Album by Daft Punk | Spotify"/><meta property="og:image" content="https://i.scdn.co/image/ram"/>';
const noYouTube: YouTubeAlbums = { search: async () => [], album: async () => { throw new Error('unused'); } };

test.each([
  [apple, { kind: 'album', platform: 'appleMusic', id: '617154241', country: 'DE' }, '/s/album/am/de/617154241'],
  ['https://music.apple.com/us/album/617154241', { kind: 'album', platform: 'appleMusic', id: '617154241', country: 'US' }, '/s/album/am/us/617154241'],
  [deezer, { kind: 'album', platform: 'deezer', id: '6575789', country: '' }, '/s/album/dz/6575789'],
  [spotify, { kind: 'album', platform: 'spotify', id: '4m2880jivSbbyEGAKfITCa', country: '' }, '/s/album/sp/4m2880jivSbbyEGAKfITCa'],
  [youtube, { kind: 'album', platform: 'youtubeMusic', id: 'OLAK5uy_kNhM2yaBTOVwrcZJepB1C9P3-n5_Sfy5c', country: '' }, '/s/album/yt/OLAK5uy_kNhM2yaBTOVwrcZJepB1C9P3-n5_Sfy5c'],
  ['https://music.youtube.com/browse/MPREb_K8qWMWVqXGi', { kind: 'album', platform: 'youtubeMusic', id: 'MPREb_K8qWMWVqXGi', country: '' }, '/s/album/yt/MPREb_K8qWMWVqXGi'],
] as const)('accepts album %s', (input, source, path) => {
  expect(musicSource(`Hör mal: ${input}`)).toEqual(source);
  expect(sharePath(source)).toBe(path);
});
test.each([
  'https://music.youtube.com/playlist?list=PLx0sYbCqOb8TBPRdmBHs5Iftvv9TPboYG',
  'https://music.youtube.com/browse/UCabc',
  'https://user@open.spotify.com/album/4m2880jivSbbyEGAKfITCa',
  `${apple} ${deezer}`,
])('rejects %s', input => expect(() => musicSource(input)).toThrow());

test('Deezer → Apple matches name and artist, the same title without edition comes after', async () => {
  const result = await resolve({ input: deezer, target: 'appleMusic', country: 'DE' }, undefined, async url => {
    if (url.hostname === 'api.deezer.com') return Response.json(deezerAlbum);
    expect(url.pathname).toBe('/search');
    expect(url.searchParams.get('entity')).toBe('album');
    expect(url.searchParams.get('term')).toBe('Daft Punk Random Access Memories');
    return Response.json({ results: [
      { ...collection, collectionId: 2, collectionName: 'Random Access Memories (10th Anniversary Edition)', collectionViewUrl: 'https://music.apple.com/de/album/ram-10/2?uo=4' },
      collection,
      { ...collection, collectionId: 3, artistName: 'Baby Rockstar', collectionViewUrl: 'https://music.apple.com/de/album/lullaby/3' },
      { ...collection, collectionId: 4, collectionName: 'Random Access Memories - Single', collectionViewUrl: 'https://evil.example/album/4' },
    ] });
  });
  expect(result.source).toEqual({ kind: 'album', title: 'Random Access Memories', artist: 'Daft Punk', url: 'https://www.deezer.com/album/6575789' });
  expect(result.sharePath).toBe('/s/album/dz/6575789');
  expect(result.candidates).toEqual([
    { title: 'Random Access Memories', url: apple, artworkUrl: collection.artworkUrl100 },
    { title: 'Random Access Memories (10th Anniversary Edition)', url: 'https://music.apple.com/de/album/ram-10/2', artworkUrl: collection.artworkUrl100 },
  ]);
});

test('Apple → Spotify finds the album through its first track', async () => {
  const result = await resolve({ input: apple, target: 'spotify', country: 'DE' }, undefined, async url => {
    if (url.hostname === 'itunes.apple.com') {
      expect(url.pathname).toBe('/lookup');
      return Response.json({ results: [{ ...collection, collectionName: 'Random Access Memories - EP' }, { wrapperType: 'track', kind: 'song', trackName: 'Give Life Back to Music' }] });
    }
    if (url.hostname === 'labs.api.listenbrainz.org') {
      expect(url.searchParams.get('track_name')).toBe('Give Life Back to Music');
      expect(url.searchParams.get('artist_name')).toBe('Daft Punk');
      return Response.json([{ spotify_track_ids: ['0dEIca2nhcxDUV8C5QkPYb', '5aPrFctv3WJZyJ99Ld7leT', '10fbCavbRqZcQmZNIgK5Ti'] }]);
    }
    expect(url.hostname).toBe('open.spotify.com');
    if (url.pathname === '/track/10fbCavbRqZcQmZNIgK5Ti') return new Response('', { status: 404 });
    const album = url.pathname === '/track/0dEIca2nhcxDUV8C5QkPYb' ? ['4m2880jivSbbyEGAKfITCa', 'Random Access Memories'] : ['2noRn2Aes5aoNVsU6iWThc', 'Discovery'];
    return new Response(`<meta property="og:description" content="Daft Punk · ${album[1]} · Song · 2013"/><meta property="og:image" content="https://i.scdn.co/image/ram"/><meta name="music:album" content="https://open.spotify.com/album/${album[0]}"/>`);
  });
  expect(result.source.title).toBe('Random Access Memories');
  expect(result.candidates).toEqual([{ title: 'Random Access Memories', url: 'https://open.spotify.com/album/4m2880jivSbbyEGAKfITCa', artworkUrl: 'https://i.scdn.co/image/ram' }]);
});

test('Spotify → YouTube Music reads the album page and searches albums', async () => {
  const albums: YouTubeAlbums = {
    ...noYouTube,
    search: async query => {
      expect(query).toBe('Daft Punk Random Access Memories');
      return [
        { id: 'MPREb_OgeEnoHTsCm', title: 'Random Access Memories (Drumless Edition)', artists: ['Daft Punk'], artworkUrl: null },
        { id: 'MPREb_K8qWMWVqXGi', title: 'Random Access Memories', artists: ['Daft Punk'], artworkUrl: 'https://yt3.googleusercontent.com/ram' },
        { id: 'MPREb_YNtsUtpBxzs', title: 'Lullaby Renditions of Daft Punk - Random Access Memories', artists: ['Baby Rockstar'], artworkUrl: null },
      ];
    },
  };
  const result = await resolve({ input: spotify, target: 'youtubeMusic', country: 'DE' }, undefined, async url => {
    expect(url.pathname).toBe('/album/4m2880jivSbbyEGAKfITCa');
    expect(url.search).toBe('');
    return new Response(spotifyAlbum);
  }, async () => [], albums);
  expect(result.source).toEqual({ kind: 'album', title: 'Random Access Memories', artist: 'Daft Punk', url: 'https://open.spotify.com/album/4m2880jivSbbyEGAKfITCa' });
  expect(result.candidates.map(candidate => candidate.url)).toEqual(['https://music.youtube.com/browse/MPREb_K8qWMWVqXGi', 'https://music.youtube.com/browse/MPREb_OgeEnoHTsCm']);
});

test('resolveAll finds an album from YouTube Music everywhere, by UPC-less text and search fallback', async () => {
  const albums: YouTubeAlbums = {
    ...noYouTube,
    album: async id => {
      expect(id).toBe('OLAK5uy_kNhM2yaBTOVwrcZJepB1C9P3-n5_Sfy5c');
      return { title: 'Random Access Memories', artist: 'Daft Punk', url: 'https://music.youtube.com/playlist?list=OLAK5uy_kNhM2yaBTOVwrcZJepB1C9P3-n5_Sfy5c', artworkUrl: 'https://yt3.googleusercontent.com/ram', firstTrack: 'Give Life Back to Music' };
    },
  };
  const album = await resolveAll({ input: youtube, country: 'DE' }, undefined, async url => {
    if (url.hostname === 'itunes.apple.com') return Response.json({ results: [collection] });
    if (url.hostname === 'api.deezer.com') {
      expect(url.pathname).toBe('/search/album');
      return Response.json({ data: [deezerAlbum] });
    }
    if (url.hostname === 'labs.api.listenbrainz.org') return Response.json([{ spotify_track_ids: [] }]);
    throw new Error(`unexpected ${url}`);
  }, async () => [], albums);
  expect(album.source).toEqual({ kind: 'album', platform: 'youtubeMusic', title: 'Random Access Memories', artist: 'Daft Punk', url: 'https://music.youtube.com/playlist?list=OLAK5uy_kNhM2yaBTOVwrcZJepB1C9P3-n5_Sfy5c', artworkUrl: 'https://yt3.googleusercontent.com/ram' });
  expect(album.sharePath).toBe('/s/album/yt/OLAK5uy_kNhM2yaBTOVwrcZJepB1C9P3-n5_Sfy5c');
  expect(album.links).toEqual({
    appleMusic: { url: apple, found: true },
    youtubeMusic: { url: 'https://music.youtube.com/playlist?list=OLAK5uy_kNhM2yaBTOVwrcZJepB1C9P3-n5_Sfy5c', found: true },
    spotify: { url: 'https://open.spotify.com/search/Daft%20Punk%20Random%20Access%20Memories', found: false },
    deezer: { url: 'https://www.deezer.com/album/6575789', found: true },
  });
  expect(friendsMessage(album, [{ name: 'Ada', platform: 'deezer' }], 'https://songgate.app')).toBe('💿 Random Access Memories – Daft Punk\nhttps://www.deezer.com/album/6575789\n\nGeteilt mit songgate.app');
});

test('an unknown Deezer album is unavailable, a missing match offers the search', async () => {
  await expect(resolve({ input: deezer, target: 'appleMusic', country: 'DE' }, undefined, async () => Response.json({ error: { code: 800 } })))
    .rejects.toMatchObject({ code: 'SOURCE_UNAVAILABLE' });
  const fetcher: Fetch = async url => url.hostname === 'api.deezer.com' ? Response.json(deezerAlbum) : Response.json({ results: [] });
  await expect(resolve({ input: deezer, target: 'appleMusic', country: 'DE' }, undefined, fetcher))
    .rejects.toMatchObject({ code: 'NO_MATCH', searchUrl: 'https://music.apple.com/de/search?term=Daft+Punk+Random+Access+Memories' });
});
