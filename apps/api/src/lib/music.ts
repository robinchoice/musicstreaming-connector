import { platforms, type Conversion, type ConversionInput, type Platform, type Song } from '@app/shared';
import { Innertube } from 'youtubei.js';
import { z } from 'zod';
import { ResolutionError, searchUrl, spotifyCandidates, youtubeVideoId, type Fetch } from './resolver';

const normalize = (value: string) => value.normalize('NFKC').toLowerCase().replace(/[^\p{L}\p{N}]+/gu, ' ').trim();
function recording(title: string, artists: string[]) {
  const credits = [...artists];
  const name = title
    .replace(/[\[(]feat(?:uring)?\.?\s+([^\])]+)[\])]/gi, (_, featured: string) => { credits.push(featured); return ''; })
    .replace(/\s+-\s+feat(?:uring)?\.?\s+([^\])]+)(?=[\])])/gi, (_, featured: string) => { credits.push(featured); return ''; });
  return {
    title: normalize(name),
    artists: [...new Set(credits.flatMap(artist => artist.split(/,| & | and /i)).map(normalize).filter(Boolean))].sort().join('|'),
  };
}
const appleTrack = z.object({
  wrapperType: z.literal('track'), kind: z.literal('song'), trackId: z.number(),
  trackName: z.string(), artistName: z.string(), trackViewUrl: z.string().url(),
  collectionName: z.string().optional(), trackTimeMillis: z.number().optional(),
  artworkUrl100: z.string().optional(), isStreamable: z.boolean().optional(),
});
const deezerTrack = z.object({
  id: z.number(), title: z.string(), duration: z.number().optional(), readable: z.boolean().optional(),
  artist: z.object({ name: z.string() }), album: z.object({ title: z.string().optional(), cover_medium: z.string().optional(), cover_xl: z.string().optional() }).optional(),
});
type Track = { title: string; artist: string; url: string; durationSeconds?: number; artworkUrl: string | null };
type Source = ReturnType<typeof songSource>;
const https = (url?: string | null) => url?.startsWith('https://') ? url : null;
type YouTubeSong = { id: string; title: string; artists: string[]; album?: string; durationSeconds?: number; artworkUrl: string | null };
export type MusicSearch = (query: string, signal: AbortSignal) => Promise<YouTubeSong[]>;

export function songSource(input: string) {
  const songs = new Map<string, { platform: Platform; id: string; country: string }>();
  for (const link of input.match(/https?:\/\/[^\s<>]+/gi) ?? []) {
    let url: URL;
    try { url = new URL(link.replace(/[.,!)\]]+$/, '')); } catch { throw new ResolutionError('INVALID_LINK'); }
    if (url.hostname === 'music.apple.com') {
      const parts = url.pathname.split('/').filter(Boolean);
      const id = parts[1] === 'album' ? url.searchParams.get('i') : parts[1] === 'song' ? parts.at(-1) : null;
      if (url.username || url.password || !/^[a-z]{2}$/i.test(parts[0] ?? '') || !id || !/^\d{1,12}$/.test(id)) throw new ResolutionError('INVALID_LINK');
      songs.set(`apple:${id}`, { platform: 'appleMusic', id, country: parts[0]!.toUpperCase() });
    } else if (['music.youtube.com', 'www.youtube.com', 'youtube.com', 'm.youtube.com', 'youtu.be'].includes(url.hostname)) {
      const id = youtubeVideoId(link);
      songs.set(`youtube:${id}`, { platform: 'youtubeMusic', id, country: '' });
    } else if (url.hostname === 'open.spotify.com' || ['www.deezer.com', 'deezer.com'].includes(url.hostname)) {
      const spotify = url.hostname === 'open.spotify.com';
      const parts = url.pathname.split('/').filter(Boolean);
      const id = parts.at(-2) === 'track' ? parts.at(-1) : null;
      if (url.username || url.password || !id || !(spotify ? /^[A-Za-z0-9]{22}$/ : /^\d{1,12}$/).test(id)) throw new ResolutionError('INVALID_LINK');
      songs.set(`${spotify ? 'spotify' : 'deezer'}:${id}`, { platform: spotify ? 'spotify' : 'deezer', id, country: '' });
    }
  }
  if (songs.size > 1) throw new ResolutionError('INVALID_LINK');
  if (!songs.size) throw new ResolutionError(input.match(/https?:\/\//i) ? 'UNSUPPORTED_LINK' : 'INVALID_LINK');
  return [...songs.values()][0]!;
}

export const searchYouTube: MusicSearch = async (query, signal) => {
  const youtube = await Innertube.create({
    retrieve_player: false, enable_session_cache: false,
    fetch: Object.assign((url: Parameters<typeof fetch>[0], init?: RequestInit) => fetch(url, { ...init, signal }), { preconnect: fetch.preconnect }),
  });
  const results = await youtube.music.search(query, { type: 'song' });
  return (results.songs?.contents ?? []).flatMap(item =>
    item.id && item.title && item.artists ? [{
      id: item.id, title: item.title, artists: item.artists.map(artist => artist.name),
      album: item.album?.name, durationSeconds: item.duration?.seconds,
      artworkUrl: item.thumbnails?.[0]?.url ?? null,
    }] : []);
};

// Spotify has no open metadata API; the public track page carries title, artists and duration as meta tags.
function spotifyMeta(html: string, name: string) {
  const value = html.match(new RegExp(`<meta (?:property|name)="${name}" content="([^"]*)"`))?.[1];
  return value?.replace(/&(amp|quot|lt|gt|#x27|#39);/g, (_, entity: string) => ({ amp: '&', quot: '"', lt: '<', gt: '>', '#x27': "'", '#39': "'" })[entity]!);
}

// Share links carry only the source song, so the share page needs no storage
export function sharePath(source: Source) {
  return { youtubeMusic: `/s/yt/${source.id}`, appleMusic: `/s/am/${source.country.toLowerCase()}/${source.id}`, spotify: `/s/sp/${source.id}`, deezer: `/s/dz/${source.id}` }[source.platform];
}

function session(requestSignal: AbortSignal | undefined, fetcher: Fetch) {
  const controller = new AbortController();
  const signal = AbortSignal.any([controller.signal, AbortSignal.timeout(20_000), ...(requestSignal ? [requestSignal] : [])]);
  const request = async (origin: string, params: Record<string, string>, headers = { 'user-agent': 'MusicLink/0.3' }) => {
    const url = new URL(origin);
    url.search = new URLSearchParams(params).toString();
    const response = await fetcher(url, { signal, redirect: 'error', headers });
    if (response.status === 429) throw new ResolutionError('RATE_LIMITED');
    if (response.status === 404) throw new ResolutionError('SOURCE_UNAVAILABLE');
    if (!response.ok) throw new ResolutionError('NETWORK');
    return response;
  };
  const get = async (origin: string, params: Record<string, string>) => (await request(origin, params)).json();
  return { controller, signal, request, get };
}
type Session = ReturnType<typeof session>;

const appleTracks = (body: unknown) => z.object({ results: z.array(z.unknown()) }).parse(body).results.flatMap(item => {
  const parsed = appleTrack.safeParse(item);
  return parsed.success ? [parsed.data] : [];
});

async function loadSource(parsed: Source, { request, get }: Session): Promise<Track> {
  let source: Track;
  if (parsed.platform === 'youtubeMusic') {
    const metadata = z.object({ title: z.string().min(1), author_name: z.string().min(1), thumbnail_url: z.string().optional() }).parse(await get('https://www.youtube.com/oembed', { url: `https://www.youtube.com/watch?v=${parsed.id}`, format: 'json' }));
    source = { title: metadata.title, artist: metadata.author_name.replace(/ - Topic$/, ''), url: `https://music.youtube.com/watch?v=${parsed.id}`, artworkUrl: https(metadata.thumbnail_url) };
  } else if (parsed.platform === 'appleMusic') {
    const track = appleTracks(await get('https://itunes.apple.com/lookup', { id: parsed.id, country: parsed.country, entity: 'song' })).find(track => String(track.trackId) === parsed.id);
    if (!track) throw new ResolutionError('SOURCE_UNAVAILABLE');
    source = { title: track.trackName, artist: track.artistName, url: `https://music.apple.com/${parsed.country.toLowerCase()}/song/${parsed.id}`, durationSeconds: track.trackTimeMillis ? track.trackTimeMillis / 1000 : undefined, artworkUrl: https(track.artworkUrl100?.replace('/100x100bb.', '/600x600bb.')) };
  } else if (parsed.platform === 'spotify') {
    const html = await (await request(`https://open.spotify.com/track/${parsed.id}`, {}, { 'user-agent': 'Mozilla/5.0 (compatible; MusicLink/0.3)' })).text();
    const duration = Number(spotifyMeta(html, 'music:duration'));
    source = { title: spotifyMeta(html, 'og:title') ?? '', artist: spotifyMeta(html, 'music:musician_description') ?? '', url: `https://open.spotify.com/track/${parsed.id}`, durationSeconds: duration > 0 ? duration : undefined, artworkUrl: https(spotifyMeta(html, 'og:image')) };
  } else {
    // Deezer reports unknown tracks as an error object with status 200
    const body = await get(`https://api.deezer.com/track/${parsed.id}`, {}) as { error?: unknown };
    if (body.error) throw new ResolutionError('SOURCE_UNAVAILABLE');
    const track = deezerTrack.parse(body);
    source = { title: track.title, artist: track.artist.name, url: `https://www.deezer.com/track/${track.id}`, durationSeconds: track.duration, artworkUrl: https(track.album?.cover_xl) };
  }
  source.title = source.title.trim();
  source.artist = source.artist.trim();
  if (!source.title || !source.artist) throw new ResolutionError('SOURCE_UNAVAILABLE');
  return source;
}

async function findCandidates(target: Platform, source: Track, country: string, session: Session, search: MusicSearch): Promise<Conversion['candidates']> {
  const { get, signal } = session;
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
      .flatMap(track => {
        const url = new URL(track.trackViewUrl);
        if (url.protocol !== 'https:' || url.hostname !== 'music.apple.com' || url.username || url.password) return [];
        const songId = url.searchParams.get('i');
        url.search = '';
        if (songId) url.searchParams.set('i', songId);
        return [{ title: track.trackName, url: url.toString(), album: track.collectionName, durationSeconds: track.trackTimeMillis ? Math.round(track.trackTimeMillis / 1000) : undefined, artworkUrl: https(track.artworkUrl100) }];
      });
  } else if (target === 'youtubeMusic') {
    candidates = (await search(query, signal))
      .filter(track => /^[A-Za-z0-9_-]{11}$/.test(track.id) && matches(track.title, track.artists, track.durationSeconds))
      .map(track => ({ title: track.title, url: `https://music.youtube.com/watch?v=${track.id}`, album: track.album, durationSeconds: track.durationSeconds, artworkUrl: https(track.artworkUrl) }));
  } else if (target === 'deezer') {
    candidates = z.object({ data: z.array(z.unknown()) }).parse(await get('https://api.deezer.com/search', { q: query, limit: '25' })).data.flatMap(item => {
      const track = deezerTrack.safeParse(item);
      if (!track.success || track.data.readable === false || !matches(track.data.title, [track.data.artist.name], track.data.duration)) return [];
      return [{ title: track.data.title, url: `https://www.deezer.com/track/${track.data.id}`, album: track.data.album?.title, durationSeconds: track.data.duration, artworkUrl: https(track.data.album?.cover_medium) }];
    });
  } else {
    candidates = await spotifyCandidates(source, get);
  }
  return [...new Map(candidates.map(candidate => [candidate.url, candidate])).values()].slice(0, 8);
}

export async function resolve(input: ConversionInput, requestSignal?: AbortSignal, fetcher: Fetch = fetch, search: MusicSearch = searchYouTube): Promise<Conversion> {
  const parsed = songSource(input.input);
  if (parsed.platform === input.target) throw new ResolutionError('UNSUPPORTED_LINK');
  const current = session(requestSignal, fetcher);
  try {
    const source = await loadSource(parsed, current);
    const candidates = await findCandidates(input.target, source, input.country, current, search);
    if (!candidates.length) throw new ResolutionError('NO_MATCH', searchUrl(input.target, source, input.country));
    return { source: { title: source.title, artist: source.artist, url: source.url }, target: input.target, candidates, sharePath: sharePath(parsed) };
  } catch (error) {
    if (error instanceof ResolutionError) throw error;
    throw new ResolutionError('NETWORK');
  } finally { current.controller.abort(); }
}

// The best match on every service at once, for the share page and for friends. A service
// that finds nothing or fails gets a search link, so one slow service never blocks the rest.
export async function resolveAll(input: { input: string; country: string }, requestSignal?: AbortSignal, fetcher: Fetch = fetch, search: MusicSearch = searchYouTube): Promise<Song> {
  const parsed = songSource(input.input);
  const current = session(requestSignal, fetcher);
  try {
    const source = await loadSource(parsed, current);
    const targets = Object.keys(platforms) as Platform[];
    const bests = await Promise.all(targets.map(target => target === parsed.platform ? undefined
      : findCandidates(target, source, input.country, current, search).then(candidates => candidates[0], () => undefined)));
    const links = Object.fromEntries(targets.map((target, i) => [target, target === parsed.platform ? { url: source.url, found: true }
      : bests[i] ? { url: bests[i].url, found: true } : { url: searchUrl(target, source, input.country), found: false }])) as Song['links'];
    // YouTube thumbnails are letterboxed video frames, a square album cover from another service looks better
    const artworkUrl = parsed.platform === 'youtubeMusic' ? bests.find(best => best?.artworkUrl)?.artworkUrl?.replace('/100x100bb.', '/600x600bb.') ?? source.artworkUrl : source.artworkUrl;
    return { source: { platform: parsed.platform, title: source.title, artist: source.artist, url: source.url, artworkUrl }, sharePath: sharePath(parsed), links };
  } catch (error) {
    if (error instanceof ResolutionError) throw error;
    throw new ResolutionError('NETWORK');
  } finally { current.controller.abort(); }
}
