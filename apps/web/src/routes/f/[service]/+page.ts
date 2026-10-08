import { platforms } from '@app/shared';
import { platformForSlug } from '$lib/friends.svelte';
import type { PageLoad } from './$types';

export const load: PageLoad = ({ params, url }) => {
  const platform = platformForSlug(params.service);
  const name = (url.searchParams.get('name') ?? '').trim().slice(0, 40);
  if (!platform || !name) return {};
  return {
    meta: { title: `${name} hört auf ${platforms[platform]}`, description: `Speicher ${name} in MusicLink, dann landen deine Songs immer direkt in ${platforms[platform]}.` },
  };
};
