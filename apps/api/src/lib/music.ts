import { type Conversion, type ConversionInput } from '@app/shared';
import { Innertube } from 'youtubei.js';
import { z } from 'zod';
import { ResolutionError, resolve as resolveSpotify, searchUrl, youtubeVideoId, type Fetch } from './resolver';

const normalize = (value: string) => value.normalize('NFKC').toLowerCase().replace(/[^\p{L}\p{N}]+/gu, ' ').trim();
function recording(title: string, artists: string[]) {
  const credits = [...artists];
  const name = title.replace(/[\[(]feat(?:uring)?\.?\s+([^\])]+)[\])]/gi, (_, featured: string) => { credits.push(featured); return ''; });
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
type Track = { title: string; artist: string; url: string; durationSeconds?: number };
type YouTubeSong = { id: string; title: string; artists: string[]; album?: string; durationSeconds?: number; artworkUrl: string | null };
export type MusicSearch = (query: string, signal: AbortSignal) => Promise<YouTubeSong[]>;

export function songSource(input: string) {
  const songs = new Map<string, { platform: 'appleMusic' | 'youtubeMusic'; id: string; country: string }>();
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

export async function resolve(input: ConversionInput, requestSignal?: AbortSignal, fetcher: Fetch = fetch, search: MusicSearch = searchYouTube): Promise<Conversion> {
  const parsed = songSource(input.input);
  if (parsed.platform === input.target) throw new ResolutionError('UNSUPPORTED_LINK');
  if (input.target === 'spotify') {
    if (parsed.platform !== 'youtubeMusic') throw new ResolutionError('UNSUPPORTED_LINK');
    return { ...await resolveSpotify(input.input, requestSignal, fetcher), target: input.target };
  }
  const controller = new AbortController();
  const signal = AbortSignal.any([controller.signal, AbortSignal.timeout(20_000), ...(requestSignal ? [requestSignal] : [])]);
  const get = async (origin: string, params: Record<string, string>) => {
    const url = new URL(origin);
    url.search = new URLSearchParams(params).toString();
    const response = await fetcher(url, { signal, redirect: 'error', headers: { 'user-agent': 'MusicLink/0.3' } });
    if (response.status === 429) throw new ResolutionError('RATE_LIMITED');
    if (response.status === 404) throw new ResolutionError('SOURCE_UNAVAILABLE');
    if (!response.ok) throw new ResolutionError('NETWORK');
    return response.json();
  };
  const tracks = (body: unknown) => z.object({ results: z.array(z.unknown()) }).parse(body).results.flatMap(item => {
    const parsed = appleTrack.safeParse(item);
    return parsed.success ? [parsed.data] : [];
  });
  try {
    let source: Track;
    if (parsed.platform === 'youtubeMusic') {
      const metadata = z.object({ title: z.string().min(1), author_name: z.string().min(1) }).parse(await get('https://www.youtube.com/oembed', { url: `https://www.youtube.com/watch?v=${parsed.id}`, format: 'json' }));
      source = { title: metadata.title.trim(), artist: metadata.author_name.replace(/ - Topic$/, '').trim(), url: `https://music.youtube.com/watch?v=${parsed.id}` };
    } else {
      const track = tracks(await get('https://itunes.apple.com/lookup', { id: parsed.id, country: parsed.country, entity: 'song' })).find(track => String(track.trackId) === parsed.id);
      if (!track) throw new ResolutionError('SOURCE_UNAVAILABLE');
      source = { title: track.trackName, artist: track.artistName, url: `https://music.apple.com/${parsed.country.toLowerCase()}/song/${parsed.id}`, durationSeconds: track.trackTimeMillis ? track.trackTimeMillis / 1000 : undefined };
    }
    if (!source.title || !source.artist) throw new ResolutionError('SOURCE_UNAVAILABLE');
    const original = recording(source.title, [source.artist]);
    const matches = (title: string, artists: string[], duration?: number) => {
      const candidate = recording(title, artists);
      return candidate.title === original.title && candidate.artists === original.artists &&
        (source.durationSeconds === undefined || duration === undefined || Math.abs(source.durationSeconds - duration) <= 3);
    };
    let candidates: Conversion['candidates'];
    if (input.target === 'appleMusic') {
      candidates = tracks(await get('https://itunes.apple.com/search', { term: `${source.artist} ${original.title}`, entity: 'song', country: input.country, limit: '25' }))
        .filter(track => track.isStreamable === true && matches(track.trackName, [track.artistName], track.trackTimeMillis ? track.trackTimeMillis / 1000 : undefined))
        .flatMap(track => {
          const url = new URL(track.trackViewUrl);
          if (url.protocol !== 'https:' || url.hostname !== 'music.apple.com' || url.username || url.password) return [];
          const songId = url.searchParams.get('i');
          url.search = '';
          if (songId) url.searchParams.set('i', songId);
          return [{ title: track.trackName, url: url.toString(), album: track.collectionName, durationSeconds: track.trackTimeMillis ? Math.round(track.trackTimeMillis / 1000) : undefined, artworkUrl: track.artworkUrl100?.startsWith('https://') ? track.artworkUrl100 : null }];
        });
    } else {
      candidates = (await search(`${source.artist} ${source.title.replace(/[\[(]feat(?:uring)?\.?\s+[^\])]+[\])]/gi, '').trim()}`, signal))
        .filter(track => /^[A-Za-z0-9_-]{11}$/.test(track.id) && matches(track.title, track.artists, track.durationSeconds))
        .map(track => ({ title: track.title, url: `https://music.youtube.com/watch?v=${track.id}`, album: track.album, durationSeconds: track.durationSeconds, artworkUrl: track.artworkUrl?.startsWith('https://') ? track.artworkUrl : null }));
    }
    candidates = [...new Map(candidates.map(candidate => [candidate.url, candidate])).values()].slice(0, 8);
    if (!candidates.length) throw new ResolutionError('NO_MATCH', searchUrl(input.target, source, input.country));
    return { source, target: input.target, candidates };
  } catch (error) {
    if (error instanceof ResolutionError) throw error;
    throw new ResolutionError('NETWORK');
  } finally { controller.abort(); }
}
