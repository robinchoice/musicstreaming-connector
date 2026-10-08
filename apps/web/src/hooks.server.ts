import { captureException } from './monitoring.server';
import type { Handle, HandleServerError } from '@sveltejs/kit';
import { dev } from '$app/environment';
import dns from 'node:dns';

// Docker's embedded DNS doesn't answer AAAA queries, which otherwise stalls
// the AAAA-before-A lookup order until it times out.
dns.setDefaultResultOrder('ipv4first');

// In production this server forwards /api to the API service, so browser and
// API share one origin and the session cookie needs no CORS. In dev Vite's
// proxy does the same for the browser; server-side loads come through here.
const API_ORIGIN = process.env.API_INTERNAL_URL || (dev ? 'http://localhost:3000' : 'http://api:3000');

export const handle: Handle = async ({ event, resolve }) => {
  if (!event.url.pathname.startsWith('/api/')) return resolve(event);

  const headers = new Headers(event.request.headers);
  headers.delete('host');

  const res = await fetch(`${API_ORIGIN}${event.url.pathname}${event.url.search}`, {
    method: event.request.method,
    headers,
    body: event.request.method !== 'GET' && event.request.method !== 'HEAD' ? event.request.body : undefined,
    // @ts-expect-error — Bun supports duplex
    duplex: 'half',
  });

  // fetch() already decompresses the body, so forwarding the upstream's
  // content-encoding/content-length would mismatch the actual bytes sent.
  const responseHeaders = new Headers(res.headers);
  responseHeaders.delete('content-encoding');
  responseHeaders.delete('content-length');

  return new Response(res.body, { status: res.status, statusText: res.statusText, headers: responseHeaders });
};

export const handleError: HandleServerError = ({ error }) => {
  captureException(error);
};
