import { platformSchema, type Conversion, type ConversionInput, type Platform, type Song } from '@app/shared';
import { z } from 'zod';
import { findAlbums, loadAlbum, youtubeAlbums, type YouTubeAlbums } from './albums';
import { appleCatalog, appleUrl, codeFailure, https, providerCall, recording, session, spotifyMeta, youtube, type MusicLink, type Session } from './providers';
import { ResolutionError, searchUrl, spotifyCandidates, youtubeVideoId, YOUTUBE_HOSTS, type Fetch } from './resolver';

const appleTrack = z.object({
  wrapperType: z.literal('track'), kind: z.literal('song'), trackId: z.number(),
  trackName: z.string(), artistName: z.string(), trackViewUrl: z.string().url(),
  collectionName: z.string().optional(), trackTimeMillis: z.number().optional(),
  artworkUrl100: z.string().optional(), isStreamable: z.boolean().optional(),
});
const deezerTrack = z.object({
  id: z.number(), title: z.string(), duration: z.number().optional(), readable: z.boolean().optional(),
  isrc: z.string().optional(), artist: z.object({ name: z.string() }), album: z.object({ title: z.string().optional(), cover_medium: z.string().optional(), cover_xl: z.string().optional() }).optional(),
});
// The Apple Music API, unlike the iTunes API, knows each song's ISRC (needs the MusicKit key)
const appleSong = z.object({ id: z.string(), attributes: z.object({
  name: z.string(), url: z.string(), albumName: z.string().optional(), durationInMillis: z.number().optional(),
  isrc: z.string().optional(), artwork: z.object({ url: z.string() }).optional(), playParams: z.unknown().optional(),
}) });
const isrcCode = (value?: string) => value && /^[A-Z]{2}[A-Z0-9]{3}\d{7}$/.test(value) ? { isrc: value } : {};
type Track = { title: string; artist: string; url: string; durationSeconds?: number; artworkUrl: string | null; isrc?: string };
type YouTubeSong = { id: string; title: string; artists: string[]; album?: string; durationSeconds?: number; artworkUrl: string | null };
export type MusicSearch = (query: string, signal: AbortSignal) => Promise<YouTubeSong[]>;

// A song or an album: Apple albums without ?i=, Spotify and Deezer /album/, YouTube Music album playlists and pages
export function musicSource(input: string): MusicLink {
  const links = new Map<string, MusicLink>();
  for (const link of input.match(/https?:\/\/[^\s<>]+/gi) ?? []) {
    let url: URL;
    try { url = new URL(link.replace(/[.,!)\]]+$/, '')); } catch { throw new ResolutionError('INVALID_LINK'); }
    if (url.hostname === 'music.apple.com') {
      const parts = url.pathname.split('/').filter(Boolean);
      const song = parts[1] === 'album' ? url.searchParams.get('i') : parts[1] === 'song' ? parts.at(-1) : null;
      const album = parts[1] === 'album' && !url.searchParams.has('i') ? parts.at(-1) : null;
      const id = song ?? album;
      if (url.username || url.password || !/^[a-z]{2}$/i.test(parts[0] ?? '') || !id || !/^\d{1,12}$/.test(id)) throw new ResolutionError('INVALID_LINK');
      links.set(`apple:${id}`, { kind: song ? 'song' : 'album', platform: 'appleMusic', id, country: parts[0]!.toUpperCase() });
    } else if (YOUTUBE_HOSTS.includes(url.hostname)) {
      if (url.username || url.password) throw new ResolutionError('INVALID_LINK');
      const album = url.pathname === '/playlist' ? url.searchParams.get('list') : url.pathname.startsWith('/browse/') ? url.pathname.slice(8) : null;
      if (album === null) {
        const id = youtubeVideoId(url);
        links.set(`youtube:${id}`, { kind: 'song', platform: 'youtubeMusic', id, country: '' });
      } else {
        if (!/^(?:OLAK5uy_|MPREb_)[A-Za-z0-9_-]{8,40}$/.test(album)) throw new ResolutionError('INVALID_LINK');
        links.set(`youtube:${album}`, { kind: 'album', platform: 'youtubeMusic', id: album, country: '' });
      }
    } else if (url.hostname === 'open.spotify.com' || ['www.deezer.com', 'deezer.com'].includes(url.hostname)) {
      const spotify = url.hostname === 'open.spotify.com';
      const parts = url.pathname.split('/').filter(Boolean);
      const kind = parts.at(-2) === 'track' ? 'song' : parts.at(-2) === 'album' ? 'album' : null;
      const id = kind ? parts.at(-1) : null;
      if (url.username || url.password || !kind || !id || !(spotify ? /^[A-Za-z0-9]{22}$/ : /^\d{1,12}$/).test(id)) throw new ResolutionError('INVALID_LINK');
      links.set(`${spotify ? 'spotify' : 'deezer'}:${kind}:${id}`, { kind, platform: spotify ? 'spotify' : 'deezer', id, country: '' });
    }
  }
  if (links.size > 1) throw new ResolutionError('INVALID_LINK');
  if (!links.size) throw new ResolutionError(input.match(/https?:\/\//i) ? 'UNSUPPORTED_LINK' : 'INVALID_LINK');
  return [...links.values()][0]!;
}

export const searchYouTube: MusicSearch = async (query, signal) => {
  const results = await (await youtube(signal)).music.search(query, { type: 'song' });
  return (results.songs?.contents ?? []).flatMap(item =>
    item.id && item.title && item.artists ? [{
      id: item.id, title: item.title, artists: item.artists.map(artist => artist.name),
      ...(item.album ? { album: item.album.name } : {}), ...(item.duration ? { durationSeconds: item.duration.seconds } : {}),
      artworkUrl: item.thumbnails?.[0]?.url ?? null,
    }] : []);
};

// Share links carry only the source song or album, so the share page needs no storage
export function sharePath(source: MusicLink) {
  const path = { youtubeMusic: `/yt/${source.id}`, appleMusic: `/am/${source.country.toLowerCase()}/${source.id}`, spotify: `/sp/${source.id}`, deezer: `/dz/${source.id}` }[source.platform];
  return source.kind === 'album' ? `/s/album${path}` : `/s${path}`;
}

// spotify.link is a Branch short link for spotify.app.link, whose page names the track or album it opens
async function expandShortLink(input: string, { request, signal }: Session) {
  const short = input.match(/https?:\/\/spotify\.link\/([A-Za-z0-9]{6,20})(?![A-Za-z0-9])/);
  if (!short) return input;
  const page = await providerCall('spotify', signal, async () => (await request(`https://spotify.app.link/${short[1]}`, {})).text());
  const target = page.match(/https:\/\/open\.spotify\.com\/(?:intl-[a-z-]+\/)?(?:track|album)\/[A-Za-z0-9]{22}/)?.[0];
  if (!target) throw new ResolutionError('INVALID_LINK');
  return input.replace(short[0], target);
}

function appleCandidate(link: string, title: string, album: string | undefined, millis: number | undefined, artworkUrl: string | null) {
  const url = appleUrl(link, true);
  return url ? [{ title, url, ...(album === undefined ? {} : { album }), ...(millis ? { durationSeconds: Math.round(millis / 1000) } : {}), artworkUrl }] : [];
}
const deezerCandidate = (track: z.infer<typeof deezerTrack>) => ({ title: track.title, url: `https://www.deezer.com/track/${track.id}`, ...(track.album?.title === undefined ? {} : { album: track.album.title }), ...(track.duration === undefined ? {} : { durationSeconds: track.duration }), artworkUrl: https(track.album?.cover_medium) });

// The ISRC names the recording, so a hit needs no text comparison
async function isrcCandidates(target: Platform, isrc: string, country: string, current: Session): Promise<Conversion['candidates']> {
  try {
    if (target === 'appleMusic') {
      // The oldest song ID is usually the original album, compilations come later
      return (await appleCatalog(`${country.toLowerCase()}/songs`, { 'filter[isrc]': isrc }, appleSong, current))
        .filter(song => song.attributes.playParams !== undefined).toSorted((a, b) => Number(a.id) - Number(b.id))
        .flatMap(({ attributes: song }) => appleCandidate(song.url, song.name, song.albumName, song.durationInMillis, https(song.artwork?.url.replace('{w}x{h}', '100x100'))));
    }
    if (target === 'deezer') {
      // Deezer answers an unknown ISRC with an error object, which does not parse as a track
      const track = deezerTrack.safeParse(await current.get(`https://api.deezer.com/track/isrc:${isrc}`, {}));
      return track.success && track.data.readable !== false ? [deezerCandidate(track.data)] : [];
    }
  } catch {
    codeFailure('ISRC', target, current.signal);
  }
  return [];
}

const appleTracks = (body: unknown) => z.object({ results: z.array(z.unknown()) }).parse(body).results.flatMap(item => {
  const parsed = appleTrack.safeParse(item);
  return parsed.success ? [parsed.data] : [];
});

function loadSource(parsed: MusicLink, current: Session): Promise<Track> {
  const { get, signal } = current;
  return providerCall(parsed.platform, signal, async () => {
    let source: Track;
    if (parsed.platform === 'youtubeMusic') {
      const metadata = z.object({ title: z.string().min(1), author_name: z.string().min(1), thumbnail_url: z.string().optional() }).parse(await get('https://www.youtube.com/oembed', { url: `https://www.youtube.com/watch?v=${parsed.id}`, format: 'json' }));
      source = { title: metadata.title, artist: metadata.author_name.replace(/ - Topic$/, ''), url: `https://music.youtube.com/watch?v=${parsed.id}`, artworkUrl: https(metadata.thumbnail_url) };
    } else if (parsed.platform === 'appleMusic') {
      const [body, isrc] = await Promise.all([
        get('https://itunes.apple.com/lookup', { id: parsed.id, country: parsed.country, entity: 'song' }),
        appleCatalog(`${parsed.country.toLowerCase()}/songs/${parsed.id}`, {}, appleSong, current).then(songs => songs[0]?.attributes.isrc, () => { codeFailure('ISRC', 'appleMusic', signal); return undefined; }),
      ]);
      const track = appleTracks(body).find(track => String(track.trackId) === parsed.id);
      if (!track) throw new ResolutionError('SOURCE_UNAVAILABLE');
      source = { ...isrcCode(isrc), title: track.trackName, artist: track.artistName, url: `https://music.apple.com/${parsed.country.toLowerCase()}/song/${parsed.id}`, ...(track.trackTimeMillis ? { durationSeconds: track.trackTimeMillis / 1000 } : {}), artworkUrl: https(track.artworkUrl100?.replace('/100x100bb.', '/600x600bb.')) };
    } else if (parsed.platform === 'spotify') {
      const html = await current.spotifyPage(`track/${parsed.id}`);
      const duration = Number(spotifyMeta(html, 'music:duration'));
      source = { title: spotifyMeta(html, 'og:title') ?? '', artist: spotifyMeta(html, 'music:musician_description') ?? '', url: `https://open.spotify.com/track/${parsed.id}`, ...(duration > 0 ? { durationSeconds: duration } : {}), artworkUrl: https(spotifyMeta(html, 'og:image')) };
    } else {
      // Deezer reports unknown tracks as an error object with status 200
      const body = await get(`https://api.deezer.com/track/${parsed.id}`, {});
      if (z.object({ error: z.unknown() }).safeParse(body).data?.error) throw new ResolutionError('SOURCE_UNAVAILABLE');
      const track = deezerTrack.parse(body);
      source = { ...isrcCode(track.isrc), title: track.title, artist: track.artist.name, url: `https://www.deezer.com/track/${track.id}`, ...(track.duration === undefined ? {} : { durationSeconds: track.duration }), artworkUrl: https(track.album?.cover_xl) };
    }
    source.title = source.title.trim();
    source.artist = source.artist.trim();
    if (!source.title || !source.artist) throw new ResolutionError('SOURCE_UNAVAILABLE');
    return source;
  });
}

function findCandidates(target: Platform, source: Track, country: string, current: Session, search: MusicSearch): Promise<Conversion['candidates']> {
  const { get, signal } = current;
  return providerCall(target, signal, async () => {
    const exact = source.isrc ? await isrcCandidates(target, source.isrc, country, current) : [];
    if (exact.length) return exact.slice(0, 8);
    const original = recording(source.title, [source.artist]);
    const matches = (title: string, artists: string[], duration?: number) => {
      const candidate = recording(title, artists);
      return candidate.title === original.title && candidate.artists === original.artists &&
        (source.durationSeconds === undefined || duration === undefined || Math.abs(source.durationSeconds - duration) <= 5);
    };
    const query = `${source.artist} ${source.title.replace(/[\[(]feat(?:uring)?\.?\s+[^\])]+[\])]/gi, '').trim()}`;
    let candidates: Conversion['candidates'];
    if (target === 'appleMusic') {
      candidates = appleTracks(await get('https://itunes.apple.com/search', { term: `${source.artist} ${original.title}`, entity: 'song', country, limit: '25' }))
        .filter(track => track.isStreamable === true && matches(track.trackName, [track.artistName], track.trackTimeMillis ? track.trackTimeMillis / 1000 : undefined))
        .flatMap(track => appleCandidate(track.trackViewUrl, track.trackName, track.collectionName, track.trackTimeMillis, https(track.artworkUrl100)));
    } else if (target === 'youtubeMusic') {
      candidates = (await search(query, signal))
        .filter(track => /^[A-Za-z0-9_-]{11}$/.test(track.id) && matches(track.title, track.artists, track.durationSeconds))
        .map(track => ({ title: track.title, url: `https://music.youtube.com/watch?v=${track.id}`, ...(track.album === undefined ? {} : { album: track.album }), ...(track.durationSeconds === undefined ? {} : { durationSeconds: track.durationSeconds }), artworkUrl: https(track.artworkUrl) }));
    } else if (target === 'deezer') {
      candidates = z.object({ data: z.array(z.unknown()) }).parse(await get('https://api.deezer.com/search', { q: query, limit: '25' })).data.flatMap(item => {
        const track = deezerTrack.safeParse(item);
        return !track.success || track.data.readable === false || !matches(track.data.title, [track.data.artist.name], track.data.duration) ? [] : [deezerCandidate(track.data)];
      });
    } else {
      candidates = await spotifyCandidates(source, get);
    }
    return [...new Map(candidates.map(candidate => [candidate.url, candidate])).values()].slice(0, 8);
  });
}

// Source and matcher of a song or an album, so resolve and resolveAll treat both alike
async function lookup(parsed: MusicLink, current: Session, search: MusicSearch, albums: YouTubeAlbums) {
  if (parsed.kind === 'album') {
    const source = await loadAlbum(parsed, current, albums);
    return { source, find: (target: Platform, country: string) => findAlbums(target, source, country, current, albums) };
  }
  const source = await loadSource(parsed, current);
  return { source, find: (target: Platform, country: string) => findCandidates(target, source, country, current, search) };
}

async function withSession<T>(input: string, requestSignal: AbortSignal | undefined, fetcher: Fetch, run: (parsed: MusicLink, current: Session) => Promise<T>): Promise<T> {
  const current = session(requestSignal, fetcher);
  try {
    return await run(musicSource(await expandShortLink(input, current)), current);
  } catch (error) {
    if (error instanceof ResolutionError) throw error;
    throw new ResolutionError('NETWORK');
  } finally { current.controller.abort(); }
}

export async function resolve(input: ConversionInput, requestSignal?: AbortSignal, fetcher: Fetch = fetch, search: MusicSearch = searchYouTube, albums: YouTubeAlbums = youtubeAlbums): Promise<Conversion> {
  return withSession(input.input, requestSignal, fetcher, async (parsed, current) => {
    if (parsed.platform === input.target) throw new ResolutionError('UNSUPPORTED_LINK');
    const { source, find } = await lookup(parsed, current, search, albums);
    const candidates = await find(input.target, input.country);
    if (!candidates.length) throw new ResolutionError('NO_MATCH', searchUrl(input.target, source, input.country));
    return { source: { kind: parsed.kind, title: source.title, artist: source.artist, url: source.url }, target: input.target, candidates, sharePath: sharePath(parsed) };
  });
}

// The best match on every service at once, for the share page and for friends. A service
// that finds nothing or fails gets a search link, so one slow service never blocks the rest.
export async function resolveAll(input: { input: string; country: string }, requestSignal?: AbortSignal, fetcher: Fetch = fetch, search: MusicSearch = searchYouTube, albums: YouTubeAlbums = youtubeAlbums): Promise<Song> {
  return withSession(input.input, requestSignal, fetcher, async (parsed, current) => {
    const { source, find } = await lookup(parsed, current, search, albums);
    const targets = platformSchema.options;
    const bests = await Promise.all(targets.map(target => target === parsed.platform ? undefined
      : find(target, input.country).then(candidates => candidates[0], () => undefined)));
    const links = Object.fromEntries(targets.map((target, i) => [target, target === parsed.platform ? { url: source.url, found: true }
      : bests[i] ? { url: bests[i].url, found: true } : { url: searchUrl(target, source, input.country), found: false }])) as Song['links'];
    // YouTube thumbnails of songs are letterboxed video frames, a square album cover from another service looks better
    const artworkUrl = parsed.platform === 'youtubeMusic' && parsed.kind === 'song' ? bests.find(best => best?.artworkUrl)?.artworkUrl?.replace('/100x100bb.', '/600x600bb.') ?? source.artworkUrl : source.artworkUrl;
    return { source: { kind: parsed.kind, platform: parsed.platform, title: source.title, artist: source.artist, url: source.url, artworkUrl }, sharePath: sharePath(parsed), links };
  });
}
