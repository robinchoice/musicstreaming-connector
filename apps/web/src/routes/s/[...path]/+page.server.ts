import { error } from '@sveltejs/kit';
import { countries, type Song } from '@app/shared';
import type { PageServerLoad } from './$types';

// The inverse of sharePath in the API: back to a link the resolver understands
function sourceLink(path: string) {
  const [kind, a, b] = path.split('/');
  if (kind === 'yt' && a && !b) return `https://music.youtube.com/watch?v=${a}`;
  if (kind === 'am' && a && b) return `https://music.apple.com/${a}/song/${b}`;
  if (kind === 'sp' && a && !b) return `https://open.spotify.com/track/${a}`;
  if (kind === 'dz' && a && !b) return `https://www.deezer.com/track/${a}`;
}

export const load: PageServerLoad = async ({ params, fetch, request, url }) => {
  const link = sourceLink(params.path);
  if (!link) error(404, 'Diesen Song-Link gibt es nicht.');
  const region = request.headers.get('accept-language')?.match(/^[a-z]{2}-([a-z]{2})/i)?.[1]?.toUpperCase();
  const country = countries.find(code => code === region) ?? 'DE';
  const response = await fetch(`/api/v1/song?${new URLSearchParams({ input: link, country })}`);
  const body = await response.json();
  if (!response.ok) error(response.status === 429 ? 503 : 404, body.error ?? 'Der Song konnte nicht geladen werden.');
  return { song: body as Song, origin: url.origin };
};
