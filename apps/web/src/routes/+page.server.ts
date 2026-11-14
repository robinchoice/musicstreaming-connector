import { redirect } from '@sveltejs/kit';
import type { PageServerLoad } from './$types';

export const load: PageServerLoad = ({ url, request }) => {
  // Bookmarklets and shortcuts open /?q=<link>, the converter lives on /app
  if (url.searchParams.has('q')) redirect(307, `/app${url.search}`);
  // Phones see only their own store. iPads asking for desktop pages look like a Mac and get both.
  const agent = request.headers.get('user-agent') ?? '';
  const device: 'ios' | 'android' | null = /iPhone|iPad|iPod/.test(agent) ? 'ios' : /Android/.test(agent) ? 'android' : null;
  return { device };
};
