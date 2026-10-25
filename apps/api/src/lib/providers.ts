import type { Platform } from '@app/shared';
import { Innertube } from 'youtubei.js';
import { z } from 'zod';
import { captureMessage } from '../monitoring';
import { appleMusicToken } from './apple-music';
import { ResolutionError, type Fetch } from './resolver';

// Plumbing shared by the song and the album lookups

export type MusicLink = { kind: 'song' | 'album'; platform: Platform; id: string; country: string };

export const normalize = (value: string) => value.normalize('NFKC').toLowerCase().replace(/[^\p{L}\p{N}]+/gu, ' ').trim();
export function recording(title: string, artists: string[]) {
  const credits = [...artists];
  const name = title
    .replace(/[\[(]feat(?:uring)?\.?\s+([^\])]+)[\])]/gi, (_, featured: string) => { credits.push(featured); return ''; })
    .replace(/\s+-\s+feat(?:uring)?\.?\s+([^\])]+)(?=[\])])/gi, (_, featured: string) => { credits.push(featured); return ''; });
  return {
    title: normalize(name),
    artists: [...new Set(credits.flatMap(artist => artist.split(/,| & | and /i)).map(normalize).filter(Boolean))].sort().join('|'),
  };
}
export const https = (url?: string | null) => url?.startsWith('https://') ? url : null;

// Spotify has no open metadata API; its public pages carry titles, artists and links as meta tags.
export function spotifyMeta(html: string, name: string) {
  return spotifyMetas(html, name)[0];
}
export function spotifyMetas(html: string, name: string) {
  return [...html.matchAll(new RegExp(`<meta (?:property|name)="${name}" content="([^"]*)"`, 'g'))].map(match =>
    match[1]!.replace(/&(amp|quot|lt|gt|#x27|#39);/g, (_, entity: string) => ({ amp: '&', quot: '"', lt: '<', gt: '>', '#x27': "'", '#39': "'" })[entity]!));
}

export function session(requestSignal: AbortSignal | undefined, fetcher: Fetch) {
  const controller = new AbortController();
  const signal = AbortSignal.any([controller.signal, AbortSignal.timeout(20_000), ...(requestSignal ? [requestSignal] : [])]);
  const request = async (origin: string, params: Record<string, string>, headers: Record<string, string> = { 'user-agent': 'Songgate/0.3' }) => {
    const url = new URL(origin);
    url.search = new URLSearchParams(params).toString();
    const response = await fetcher(url, { signal, redirect: 'error', headers });
    if (response.status === 429) throw new ResolutionError('RATE_LIMITED');
    if (response.status === 404) throw new ResolutionError('SOURCE_UNAVAILABLE');
    if (!response.ok) throw new ResolutionError('NETWORK');
    return response;
  };
  const get = async (origin: string, params: Record<string, string>): Promise<unknown> => (await request(origin, params)).json();
  const spotifyPage = async (path: string) => (await request(`https://open.spotify.com/${path}`, {}, { 'user-agent': 'Mozilla/5.0 (compatible; Songgate/0.3)' })).text();
  return { controller, signal, request, get, spotifyPage };
}
export type Session = ReturnType<typeof session>;

export async function providerCall<T>(provider: Platform, signal: AbortSignal, call: () => Promise<T>): Promise<T> {
  try {
    return await call();
  } catch (error) {
    if (!(error instanceof ResolutionError) && !signal.aborted) {
      const failure = error instanceof z.ZodError || error instanceof SyntaxError ? 'invalid_response'
        : error instanceof TypeError ? 'request_failed' : 'unexpected';
      captureMessage('Music provider failure', { level: 'warning', tags: { provider, failure } });
    }
    throw error;
  }
}

export async function appleCatalog<T extends z.ZodType>(path: string, params: Record<string, string>, item: T, { request }: Session): Promise<z.infer<T>[]> {
  const token = await appleMusicToken();
  if (!token) return [];
  const body: unknown = await (await request(`https://api.music.apple.com/v1/catalog/${path}`, params, { authorization: `Bearer ${token}` })).json();
  return z.object({ data: z.array(item) }).parse(body).data;
}

// A failed ISRC or UPC lookup leaves text matching; reported so a broken MusicKit key gets noticed
export function codeFailure(code: 'ISRC' | 'UPC', provider: Platform, signal: AbortSignal) {
  if (!signal.aborted) captureMessage(`${code} lookup failure`, { level: 'warning', tags: { provider } });
}

export const youtube = (signal: AbortSignal) => Innertube.create({
  retrieve_player: false, enable_session_cache: false,
  fetch: Object.assign((url: Parameters<typeof fetch>[0], init?: RequestInit) => fetch(url, { ...init, signal }), { preconnect: fetch.preconnect }),
});
