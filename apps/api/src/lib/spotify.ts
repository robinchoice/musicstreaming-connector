import { z } from 'zod';
import type { Session } from './providers';
import { ResolutionError } from './resolver';

// The Spotify Web API with an app token from the client credentials flow, only for finding podcasts:
// songs and albums go through ListenBrainz and Spotify's pages. Without SPOTIFY_CLIENT_ID and
// SPOTIFY_CLIENT_SECRET Spotify links are still read from their pages, podcasts on Spotify get a search link.
let cached: { client: string; token: string; expires: number } | undefined;

async function spotifyToken({ fetcher, signal }: Session, env: Record<string, string | undefined> = process.env, now = Date.now()) {
  const { SPOTIFY_CLIENT_ID: client, SPOTIFY_CLIENT_SECRET: secret } = env;
  if (!client || !secret) return null;
  if (cached?.client === client && cached.expires - now > 60_000) return cached.token;
  const response = await fetcher(new URL('https://accounts.spotify.com/api/token'), {
    method: 'POST', signal, redirect: 'error', body: new URLSearchParams({ grant_type: 'client_credentials' }),
    headers: { authorization: `Basic ${btoa(`${client}:${secret}`)}`, 'content-type': 'application/x-www-form-urlencoded' },
  });
  if (!response.ok) throw new ResolutionError('NETWORK');
  const body = z.object({ access_token: z.string().min(1), expires_in: z.number() }).parse(await response.json());
  cached = { client, token: body.access_token, expires: now + body.expires_in * 1000 };
  return cached.token;
}

// null without a key, so callers fall back to a search link
export async function spotifyApi(path: string, params: Record<string, string>, current: Session): Promise<unknown> {
  const token = await spotifyToken(current);
  if (!token) return null;
  return (await current.request(`https://api.spotify.com/v1/${path}`, params, { authorization: `Bearer ${token}` })).json();
}
