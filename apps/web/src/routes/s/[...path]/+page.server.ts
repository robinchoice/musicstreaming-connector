import { error } from '@sveltejs/kit';
import { countries, messages, serviceName, servicesFor, type Song, sourceLink } from '@app/shared';
import { platformForSlug } from '#lib/friends.svelte.ts';
import type { PageServerLoad } from './$types';

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
  const found = servicesFor(song.source.kind).filter(platform => song.links[platform].found).map(platform => serviceName(platform, song.source.kind));
  // Optional sender, see shareUrl in packages/shared
  const name = (url.searchParams.get('from') ?? '').trim().slice(0, 40);
  const platform = platformForSlug(url.searchParams.get('service') ?? '');
  const from = name && platform ? { name, platform } : null;
  return {
    song,
    from,
    meta: { title: [song.source.title, song.source.artist].filter(Boolean).join(' · '), description: m.shareMeta(from?.name ?? null, found.join(', ')), image: song.source.artworkUrl ?? undefined },
  };
};
