import { messages, platforms } from '@app/shared';
import { platformForSlug } from '$lib/friends.svelte';
import type { PageLoad } from './$types';

export const load: PageLoad = async ({ params, url, parent }) => {
  const m = messages[(await parent()).locale];
  const platform = platformForSlug(params.service);
  const name = (url.searchParams.get('name') ?? '').trim().slice(0, 40);
  if (!platform || !name) return {};
  return {
    meta: { title: m.listensOn(name, platforms[platform]), description: m.saveFriendMeta(name, platforms[platform]) },
  };
};
