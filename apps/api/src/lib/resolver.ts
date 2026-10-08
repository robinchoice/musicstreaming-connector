import { failureMessages, type Conversion, type FailureCode, type Platform } from '@app/shared';
import { z } from 'zod';

export class ResolutionError extends Error {
  constructor(public code: FailureCode, public searchUrl?: string) {
    super(failureMessages[code]);
  }
}

export function searchUrl(target: Platform, source: { title: string; artist: string }, country = 'DE') {
  const artist = source.artist.replace(/VEVO$/i, '').trim();
  const title = source.title.replace(/[\[(][^\])]*\b(?:official|video|audio|lyrics?|remaster(?:ed)?|4k|hd)\b[^\])]*[\])]/gi, '').replace(/\s+/g, ' ').trim();
  const query = title.toLowerCase().includes(artist.toLowerCase()) ? title : `${artist} ${title}`;
  if (target === 'spotify') return `https://open.spotify.com/search/${encodeURIComponent(query)}`;
  if (target === 'deezer') return `https://www.deezer.com/search/${encodeURIComponent(query)}`;
  const url = new URL(target === 'appleMusic' ? `https://music.apple.com/${country.toLowerCase()}/search` : 'https://music.youtube.com/search');
  url.searchParams.set(target === 'appleMusic' ? 'term' : 'q', query);
  return url.toString();
}

export function youtubeVideoId(input: string) {
  const links = input.match(/https?:\/\/[^\s<>]+/gi) ?? [];
  if (!links.length) throw new ResolutionError('INVALID_LINK');
  const ids = new Set<string>();
  for (const link of links) {
    let url: URL;
    try {
      url = new URL(link.replace(/[.,!)\]]+$/, ''));
    } catch {
      throw new ResolutionError('INVALID_LINK');
    }
    if (!['music.youtube.com', 'www.youtube.com', 'youtube.com', 'm.youtube.com', 'youtu.be'].includes(url.hostname)) continue;
    if (url.username || url.password) throw new ResolutionError('INVALID_LINK');
    const id = url.hostname === 'youtu.be' ? url.pathname.slice(1) : url.pathname === '/watch' ? url.searchParams.get('v') : null;
    if (!id || !/^[A-Za-z0-9_-]{11}$/.test(id)) throw new ResolutionError('INVALID_LINK');
    ids.add(id);
  }
  if (!ids.size) throw new ResolutionError('UNSUPPORTED_LINK');
  if (ids.size !== 1) throw new ResolutionError('INVALID_LINK');
  return [...ids][0]!;
}

const metadataSchema = z.object({
  title: z.string(),
  author_name: z.string().default(''),
  thumbnail_url: z.string().nullable().optional(),
});
const lookupSchema = z.array(z.object({ spotify_track_ids: z.array(z.string()).default([]) }));
const normalizedTitle = (title: string) => title.toLowerCase().replace(/[^\p{L}\p{N}]+/gu, ' ').trim();
export type Fetch = (url: URL, init: RequestInit) => Promise<Response>;
type Get = (origin: string, params: Record<string, string>) => Promise<unknown>;

// ListenBrainz maps artist and title to Spotify IDs; Spotify's oEmbed confirms each track still exists.
export async function spotifyCandidates(source: { title: string; artist: string }, get: Get) {
  const entries = lookupSchema.parse(await get('https://labs.api.listenbrainz.org/spotify-id-from-metadata/json', {
    artist_name: source.artist, track_name: source.title, release_name: '',
  }));
  const ids = [...new Set(entries.flatMap(entry => entry.spotify_track_ids))]
    .filter(id => /^[A-Za-z0-9]{22}$/.test(id)).slice(0, 8);
  const candidates: Conversion['candidates'] = [];
  for (let i = 0; i < ids.length; i += 3) {
    const batch = await Promise.all(ids.slice(i, i + 3).map(async id => {
      const url = `https://open.spotify.com/track/${id}`;
      let metadata: z.infer<typeof metadataSchema>;
      try {
        metadata = metadataSchema.parse(await get('https://open.spotify.com/oembed', { url }));
      } catch (error) {
        if (error instanceof ResolutionError && error.code === 'SOURCE_UNAVAILABLE') return null;
        throw error;
      }
      if (normalizedTitle(metadata.title) !== normalizedTitle(source.title)) return null;
      return { title: metadata.title, url, artworkUrl: metadata.thumbnail_url?.startsWith('https://') ? metadata.thumbnail_url : null };
    }));
    candidates.push(...batch.filter(candidate => candidate !== null));
  }
  return candidates;
}

export async function resolve(input: string, requestSignal?: AbortSignal, fetcher: Fetch = fetch): Promise<Omit<Conversion, 'target'>> {
  const id = youtubeVideoId(input);
  const controller = new AbortController();
  const signals = [controller.signal, AbortSignal.timeout(20_000)];
  if (requestSignal) signals.push(requestSignal);
  const signal = AbortSignal.any(signals);

  async function get(origin: string, params: Record<string, string>) {
    const url = new URL(origin);
    url.search = new URLSearchParams(params).toString();
    const response = await fetcher(url, {
      signal: AbortSignal.any([signal, AbortSignal.timeout(8_000)]),
      headers: { 'user-agent': 'MusicLink/0.2 (YouTube to Spotify)' },
      redirect: 'error',
    });
    if (response.status === 404) throw new ResolutionError('SOURCE_UNAVAILABLE');
    if (response.status === 429) throw new ResolutionError('RATE_LIMITED');
    if (!response.ok) throw new ResolutionError('NETWORK');
    return response.json();
  }

  try {
    const metadata = metadataSchema.parse(await get('https://www.youtube.com/oembed', {
      url: `https://www.youtube.com/watch?v=${id}`, format: 'json',
    }));
    const source = {
      title: metadata.title.trim(),
      artist: metadata.author_name.replace(/ - Topic$/, '').trim(),
      url: `https://music.youtube.com/watch?v=${id}`,
    };
    if (!source.title || !source.artist) throw new ResolutionError('SOURCE_UNAVAILABLE');
    const candidates = await spotifyCandidates(source, get);
    if (!candidates.length) throw new ResolutionError('NO_MATCH', searchUrl('spotify', source));
    return { source, candidates };
  } catch (error) {
    if (error instanceof ResolutionError) throw error;
    throw new ResolutionError('NETWORK');
  } finally {
    controller.abort();
  }
}
