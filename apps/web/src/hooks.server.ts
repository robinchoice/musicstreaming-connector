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

// Public content for agents comes from the API, see apps/api/src/routes/agents.ts
const AGENT_PATH = /^\/llms(-full)?\.txt$|\.md$/;

export const handle: Handle = async ({ event, resolve }) => {
  const { pathname, search } = event.url;
  if (pathname.startsWith('/api/') || AGENT_PATH.test(pathname)) return proxy(event.request, `${API_ORIGIN}${pathname}${search}`);
  return (await markdown(event.request, event.url)) ?? resolve(event);
};

// Agents that ask for Markdown get a public page as its .md, all others the HTML
async function markdown(request: Request, url: URL) {
  if (request.method !== 'GET' || !request.headers.get('accept')?.includes('text/markdown')) return;
  const path = url.pathname === '/' ? '/index.md' : `${url.pathname.replace(/\/$/, '')}.md`;
  const response = await proxy(request, `${API_ORIGIN}${path}${url.search}`);
  if (response.ok) return response;
}

async function proxy(request: Request, target: string) {
  const headers = new Headers(request.headers);
  headers.delete('host');

  const res = await fetch(target, {
    method: request.method,
    headers,
    body: request.method !== 'GET' && request.method !== 'HEAD' ? request.body : undefined,
    // @ts-expect-error — Bun supports duplex
    duplex: 'half',
  });

  // fetch() already decompresses the body, so forwarding the upstream's
  // content-encoding/content-length would mismatch the actual bytes sent.
  const responseHeaders = new Headers(res.headers);
  responseHeaders.delete('content-encoding');
  responseHeaders.delete('content-length');

  return new Response(res.body, { status: res.status, statusText: res.statusText, headers: responseHeaders });
}

export const handleError: HandleServerError = ({ error }) => {
  captureException(error);
};
