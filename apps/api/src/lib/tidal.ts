import { z } from 'zod';
import type { Session } from './providers';
import { ResolutionError } from './resolver';

// The TIDAL API (JSON:API) with an app token from the client credentials flow.
// Without TIDAL_CLIENT_ID and TIDAL_CLIENT_SECRET Songgate reads TIDAL links from their pages
// and offers only a search on TIDAL.
let cached: { client: string; token: string; expires: number } | undefined;

async function tidalToken({ fetcher, signal }: Session, env: Record<string, string | undefined> = process.env, now = Date.now()) {
  const { TIDAL_CLIENT_ID: client, TIDAL_CLIENT_SECRET: secret } = env;
  if (!client || !secret) return null;
  if (cached?.client === client && cached.expires - now > 60_000) return cached.token;
  const response = await fetcher(new URL('https://auth.tidal.com/v1/oauth2/token'), {
    method: 'POST', signal, redirect: 'error', body: new URLSearchParams({ grant_type: 'client_credentials' }),
    headers: { authorization: `Basic ${btoa(`${client}:${secret}`)}`, 'content-type': 'application/x-www-form-urlencoded' },
  });
  if (!response.ok) throw new ResolutionError('NETWORK');
  const body = z.object({ access_token: z.string().min(1), expires_in: z.number() }).parse(await response.json());
  cached = { client, token: body.access_token, expires: now + body.expires_in * 1000 };
  return cached.token;
}

const identifier = z.object({ id: z.string(), type: z.string() });
const resource = identifier.extend({
  attributes: z.record(z.string(), z.unknown()).default({}),
  relationships: z.record(z.string(), z.object({ data: z.union([z.array(identifier), identifier, z.null()]).optional() })).default({}),
});
type Resource = z.infer<typeof resource>;
const document = z.object({ data: z.union([z.array(resource), resource]), included: z.array(resource).default([]) });

export type TidalDocument = { data: Resource[]; included: Resource[] };

// Array parameters such as include repeat their key, as in the API's OpenAPI description
export async function tidalCatalog(path: string, params: [string, string][], current: Session): Promise<TidalDocument | null> {
  const token = await tidalToken(current);
  if (!token) return null;
  const response = await current.request(`https://openapi.tidal.com/v2/${path}`, params, { authorization: `Bearer ${token}`, accept: 'application/vnd.api+json' });
  const body = document.parse(await response.json());
  return { data: Array.isArray(body.data) ? body.data : [body.data], included: body.included };
}

// The included resources a relationship points to, in its order
export function related(doc: TidalDocument, item: Resource, name: string) {
  const data = item.relationships[name]?.data;
  return (Array.isArray(data) ? data : data ? [data] : [])
    .flatMap(link => doc.included.filter(other => other.id === link.id && other.type === link.type));
}

const trackAttributes = z.object({ title: z.string(), version: z.string().nullish(), isrc: z.string().optional(), duration: z.string().optional() });
const albumAttributes = z.object({ title: z.string(), version: z.string().nullish(), barcodeId: z.string().optional() });
const artistAttributes = z.object({ name: z.string() });

// "PT4M52S"
export function seconds(duration?: string) {
  const parts = duration?.match(/^PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+(?:\.\d+)?)S)?$/);
  return parts ? Number(parts[1] ?? 0) * 3600 + Number(parts[2] ?? 0) * 60 + Number(parts[3] ?? 0) : undefined;
}

const named = (attributes: { title: string; version?: string | null | undefined }) => attributes.version ? `${attributes.title} (${attributes.version})` : attributes.title;
const artists = (doc: TidalDocument, item: Resource) => related(doc, item, 'artists').flatMap(artist => artistAttributes.safeParse(artist.attributes).data?.name ?? []);

export function tidalTracks(doc: TidalDocument) {
  return doc.data.flatMap(item => {
    const attributes = trackAttributes.safeParse(item.attributes).data;
    if (item.type !== 'tracks' || !attributes || !/^\d{1,12}$/.test(item.id)) return [];
    const album = albumAttributes.safeParse(related(doc, item, 'albums')[0]?.attributes).data;
    const durationSeconds = seconds(attributes.duration);
    return [{
      id: item.id, title: named(attributes), artists: artists(doc, item), url: `https://tidal.com/track/${item.id}`,
      ...(attributes.isrc ? { isrc: attributes.isrc } : {}), ...(durationSeconds === undefined ? {} : { durationSeconds }), ...(album ? { album: album.title } : {}),
    }];
  });
}

export function tidalAlbums(doc: TidalDocument) {
  return doc.data.flatMap(item => {
    const attributes = albumAttributes.safeParse(item.attributes).data;
    if (item.type !== 'albums' || !attributes || !/^\d{1,12}$/.test(item.id)) return [];
    const firstTrack = trackAttributes.safeParse(related(doc, item, 'items')[0]?.attributes).data?.title;
    return [{
      id: item.id, title: named(attributes), artists: artists(doc, item), url: `https://tidal.com/album/${item.id}`,
      ...(attributes.barcodeId ? { upc: attributes.barcodeId } : {}), ...(firstTrack ? { firstTrack } : {}),
    }];
  });
}

// Search results carry only IDs worth knowing; the second call names their artists
export async function tidalSearch(kind: 'tracks' | 'albums', query: string, country: string, current: Session) {
  const results = await tidalCatalog('searchResults', [['filter[query]', query.slice(0, 256)], ['countryCode', country], ['include', kind]], current);
  const ids = (results?.data[0]?.relationships[kind]?.data ?? []);
  const found = (Array.isArray(ids) ? ids : [ids]).map(link => link.id).filter(id => /^\d{1,12}$/.test(id)).slice(0, 10);
  if (!found.length) return null;
  return tidalCatalog(kind, [...found.map((id): [string, string] => ['filter[id]', id]), ['countryCode', country], ['include', 'artists'], ...(kind === 'tracks' ? [['include', 'albums'] as [string, string]] : [])], current);
}

// TIDAL's public pages: og:title is "Artist - Title", og:description "Listen to Title on TIDAL"
export function tidalPageMeta(title?: string, description?: string) {
  const name = description?.match(/^Listen to (.+) on TIDAL$/)?.[1];
  const artist = name && title?.endsWith(` - ${name}`) ? title.slice(0, -name.length - 3) : undefined;
  return name && artist ? { title: name, artist } : null;
}
