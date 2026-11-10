import { clientToken, type Session } from './providers';

// The Spotify Web API with an app token from the client credentials flow, only for finding podcasts:
// songs and albums go through ListenBrainz and Spotify's pages. Without SPOTIFY_CLIENT_ID and
// SPOTIFY_CLIENT_SECRET Spotify links are still read from their pages, podcasts on Spotify get a search link.

// null without a key, so callers fall back to a search link
export async function spotifyApi(path: string, params: Record<string, string>, current: Session): Promise<unknown> {
  const token = await clientToken('https://accounts.spotify.com/api/token', process.env.SPOTIFY_CLIENT_ID, process.env.SPOTIFY_CLIENT_SECRET, current);
  if (!token) return null;
  return (await current.request(`https://api.spotify.com/v1/${path}`, params, { authorization: `Bearer ${token}` })).json();
}
