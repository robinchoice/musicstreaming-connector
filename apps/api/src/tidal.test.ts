import { afterAll, afterEach, beforeAll, describe, expect, spyOn, test } from 'bun:test';
import fc from 'fast-check';
import * as monitoring from './monitoring';
import { resolve, resolveAll } from './lib/music';
import type { Fetch } from './lib/resolver';
import { seconds, tidalPageMeta } from './lib/tidal';

const diagnostics = spyOn(monitoring, 'captureMessage').mockImplementation(() => 'test');
afterEach(() => diagnostics.mockClear());
afterAll(() => diagnostics.mockRestore());

const page = (type: string, title: string, artist: string) => `<html><head>
<meta property="og:type" content="music.${type}">
<meta property="og:title" content="${artist} - ${title}">
<meta property="og:description" content="Listen to ${title} on TIDAL">
<meta property="og:image" content="https://resources.tidal.com/images/cover/640x640.jpg">
</head></html>`;
const deezerTrack = { id: 67238735, title: 'Get Lucky', duration: 248, readable: true, isrc: 'USQX91300108', artist: { name: 'Daft Punk' }, album: { title: 'Get Lucky' } };
const tidalTrack = (id: string, title: string, duration: string, extra: object = {}) => ({
  id, type: 'tracks', attributes: { title, duration, isrc: 'USQX91300108', explicit: false, ...extra },
  relationships: { artists: { data: [{ id: '4', type: 'artists' }] }, albums: { data: [{ id: '20', type: 'albums' }] } },
});
const included = [{ id: '4', type: 'artists', attributes: { name: 'Daft Punk' } }, { id: '20', type: 'albums', attributes: { title: 'Get Lucky', barcodeId: '886443927087' } }];

test('a TIDAL link is read from its page without a key and matched by text', async () => {
  const result = await resolve({ input: 'Hör mal https://tidal.com/browse/track/28048256/u', target: 'deezer', country: 'DE' }, undefined, async url => {
    if (url.hostname === 'tidal.com') {
      expect(url.pathname).toBe('/track/28048256');
      return new Response(page('song', 'Get Lucky', 'Daft Punk &amp; Pharrell Williams'));
    }
    if (url.hostname === 'api.deezer.com') return Response.json({ data: [{ ...deezerTrack, artist: { name: 'Daft Punk' }, title: 'Get Lucky (feat. Pharrell Williams)' }] });
    throw new Error(`unexpected ${url}`);
  });
  expect(result.source).toEqual({ kind: 'song', title: 'Get Lucky', artist: 'Daft Punk & Pharrell Williams', url: 'https://tidal.com/track/28048256' });
  expect(result.sharePath).toBe('/s/td/28048256');
  expect(result.candidates[0]?.url).toBe('https://www.deezer.com/track/67238735');
});

test('without a key TIDAL and Amazon Music get search links', async () => {
  await expect(resolve({ input: 'https://www.deezer.com/track/67238735', target: 'tidal', country: 'DE' }, undefined, async () => Response.json(deezerTrack)))
    .rejects.toMatchObject({ code: 'NO_MATCH', searchUrl: 'https://tidal.com/search?q=Daft+Punk+Get+Lucky' });
  await expect(resolve({ input: 'https://www.deezer.com/track/67238735', target: 'amazonMusic', country: 'GB' }, undefined, async () => Response.json(deezerTrack)))
    .rejects.toMatchObject({ code: 'NO_MATCH', searchUrl: 'https://music.amazon.co.uk/search/Daft%20Punk%20Get%20Lucky' });
});

describe('with a TIDAL key', () => {
  beforeAll(() => Object.assign(process.env, { TIDAL_CLIENT_ID: 'client', TIDAL_CLIENT_SECRET: 'secret' }));
  afterAll(() => { delete process.env.TIDAL_CLIENT_ID; delete process.env.TIDAL_CLIENT_SECRET; });
  let tokens = 0;
  const tidal = (api: (url: URL) => unknown, other: Fetch): Fetch => async (url, init) => {
    if (url.hostname === 'auth.tidal.com') {
      tokens++;
      expect(init.method).toBe('POST');
      expect(new Headers(init.headers).get('authorization')).toBe(`Basic ${btoa('client:secret')}`);
      expect(String(init.body)).toBe('grant_type=client_credentials');
      return Response.json({ access_token: 'token', token_type: 'Bearer', expires_in: 86400 });
    }
    if (url.hostname === 'openapi.tidal.com') {
      expect(new Headers(init.headers).get('authorization')).toBe('Bearer token');
      return Response.json(api(url));
    }
    return other(url, init);
  };

  test('Deezer → TIDAL by ISRC, with one token for several lookups', async () => {
    const fetcher = tidal(url => {
      expect(url.pathname).toBe('/v2/tracks');
      expect(url.searchParams.get('filter[isrc]')).toBe('USQX91300108');
      expect(url.searchParams.get('countryCode')).toBe('AT');
      return { data: [tidalTrack('28048256', 'Get Lucky', 'PT4M8S', { version: 'Radio Edit' })], included };
    }, async () => Response.json(deezerTrack));
    for (let i = 0; i < 2; i++) {
      const result = await resolve({ input: 'https://www.deezer.com/track/67238735', target: 'tidal', country: 'AT' }, undefined, fetcher);
      expect(result.candidates).toEqual([{ title: 'Get Lucky (Radio Edit)', url: 'https://tidal.com/track/28048256', album: 'Get Lucky', durationSeconds: 248, artworkUrl: null }]);
    }
    expect(tokens).toBe(1);
  });

  test('YouTube → TIDAL searches and names the artists of the hits', async () => {
    const result = await resolve({ input: 'https://music.youtube.com/watch?v=5NV6Rdv1a3I', target: 'tidal', country: 'DE' }, undefined, tidal(url => {
      if (url.pathname === '/v2/searchResults') {
        expect(url.searchParams.get('filter[query]')).toBe('Daft Punk Get Lucky');
        return { data: { id: 'Daft Punk Get Lucky', type: 'searchResults', relationships: { tracks: { data: [{ id: '1', type: 'tracks' }, { id: '2', type: 'tracks' }, { id: 'x', type: 'tracks' }] } } } };
      }
      expect(url.pathname).toBe('/v2/tracks');
      expect(url.searchParams.getAll('filter[id]')).toEqual(['1', '2']);
      expect(url.searchParams.getAll('include')).toEqual(['artists', 'albums']);
      return { data: [tidalTrack('1', 'Get Lucky', 'PT6M9S'), tidalTrack('2', 'Get Lucky', 'PT4M8S')], included };
    }, async url => {
      expect(url.hostname).toBe('www.youtube.com');
      return Response.json({ title: 'Get Lucky', author_name: 'Daft Punk - Topic' });
    }), async () => []);
    expect(result.candidates.map(candidate => candidate.url)).toEqual(['https://tidal.com/track/1', 'https://tidal.com/track/2']);
  });

  test('a TIDAL album finds Deezer by its UPC, and the share page links all services', async () => {
    const song = await resolveAll({ input: 'https://tidal.com/album/28048252', country: 'DE' }, undefined, tidal(url => {
      expect(url.pathname).toBe('/v2/albums/28048252');
      expect(url.searchParams.get('include')).toBe('items');
      return {
        data: { id: '28048252', type: 'albums', attributes: { title: 'Random Access Memories', barcodeId: '886443927087' }, relationships: { items: { data: [{ id: '1', type: 'tracks' }] } } },
        included: [{ id: '1', type: 'tracks', attributes: { title: 'Give Life Back to Music' } }],
      };
    }, async url => {
      if (url.hostname === 'tidal.com') return new Response(page('album', 'Random Access Memories', 'Daft Punk'));
      if (url.pathname === '/album/upc:886443927087') return Response.json({ id: 6575789, title: 'Random Access Memories', artist: { name: 'Daft Punk' } });
      if (url.hostname === 'labs.api.listenbrainz.org') {
        expect(url.searchParams.get('track_name')).toBe('Give Life Back to Music');
        return Response.json([]);
      }
      return new Response('', { status: 500 });
    }), async () => [], { search: async () => [], album: async () => { throw new Error('unused'); } });
    expect(song.source).toMatchObject({ kind: 'album', platform: 'tidal', title: 'Random Access Memories', artworkUrl: 'https://resources.tidal.com/images/cover/640x640.jpg' });
    expect(song.sharePath).toBe('/s/album/td/28048252');
    expect(song.links.tidal).toEqual({ url: 'https://tidal.com/album/28048252', found: true });
    expect(song.links.deezer).toEqual({ url: 'https://www.deezer.com/album/6575789', found: true });
    expect(song.links.amazonMusic.found).toBe(false);
  });
});

test('TIDAL page titles split into title and artist', () => {
  const line = fc.string({ minLength: 1 }).filter(value => !/[\n\r]/.test(value));
  fc.assert(fc.property(line, line, (title, artist) => {
    expect(tidalPageMeta(`${artist} - ${title}`, `Listen to ${title} on TIDAL`)).toEqual({ title, artist });
  }));
  expect(tidalPageMeta('Daft Punk - Get Lucky', 'Listen to Something else on TIDAL')).toBeNull();
});

test('ISO 8601 durations become seconds', () => {
  fc.assert(fc.property(fc.nat(9), fc.nat(59), fc.nat(59), (h, m, s) => {
    expect(seconds(`PT${h ? `${h}H` : ''}${m ? `${m}M` : ''}${s}S`)).toBe(h * 3600 + m * 60 + s);
  }));
  expect(seconds('4:08')).toBeUndefined();
});
