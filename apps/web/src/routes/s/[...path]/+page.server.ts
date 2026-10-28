import { error } from '@sveltejs/kit';
import { countries, messages, platformSchema, platforms, type Song } from '@app/shared';
import { platformForSlug } from '$lib/friends.svelte';
import type { PageServerLoad } from './$types';

// The inverse of sharePath in the API: back to a link the resolver understands
function sourceLink(path: string) {
  const [kind, a, b, c] = path.split('/');
  if (kind === 'yt' && a && !b) return `https://music.youtube.com/watch?v=${a}`;
  if (kind === 'am' && a && b && !c) return `https://music.apple.com/${a}/song/${b}`;
  if (kind === 'sp' && a && !b) return `https://open.spotify.com/track/${a}`;
  if (kind === 'dz' && a && !b) return `https://www.deezer.com/track/${a}`;
  if (kind !== 'album') return;
  if (a === 'yt' && b && !c) return b.startsWith('MPREb_') ? `https://music.youtube.com/browse/${b}` : `https://music.youtube.com/playlist?list=${b}`;
  if (a === 'am' && b && c) return `https://music.apple.com/${b}/album/${c}`;
  if (a === 'sp' && b && !c) return `https://open.spotify.com/album/${b}`;
  if (a === 'dz' && b && !c) return `https://www.deezer.com/album/${b}`;
}

export const load: PageServerLoad = async ({ params, fetch, request, url, locals }) => {
  const m = messages[locals.locale];
  const link = sourceLink(params.path);
  if (!link) error(404, m.linkUnknown);
  const region = request.headers.get('accept-language')?.match(/^[a-z]{2}-([a-z]{2})/i)?.[1]?.toUpperCase();
  const country = countries.find(code => code === region) ?? 'DE';
  const response = await fetch(`/api/v1/song?${new URLSearchParams({ input: link, country })}`, { headers: { 'accept-language': locals.locale } });
  const body = await response.json();
  // Busy or unreachable services are temporary, only a song that cannot be found is a 404
  if (!response.ok) error(response.status === 429 || response.status >= 500 ? 503 : 404, body.error ?? m.linkFailed);
  const song = body as Song;
  const found = platformSchema.options.filter(platform => song.links[platform].found).map(platform => platforms[platform]);
  // Optional sender, see shareUrl in packages/shared
  const name = (url.searchParams.get('from') ?? '').trim().slice(0, 40);
  const platform = platformForSlug(url.searchParams.get('service') ?? '');
  const from = name && platform ? { name, platform } : null;
  return {
    song,
    from,
    meta: { title: `${song.source.title} · ${song.source.artist}`, description: m.shareMeta(from?.name ?? null, found.join(', ')), image: song.source.artworkUrl ?? undefined },
  };
};
