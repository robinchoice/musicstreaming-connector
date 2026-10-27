import { z } from 'zod';
import { EXIT, Failure } from './command';
import type { Locale, Messages } from '@app/shared';

// A missing match brings the search on the target service along
const errorSchema = z.object({ error: z.string(), searchUrl: z.string().optional() });

// The same HTTP API as web and app, without login: the converter is public
export function createClient(url: string, locale: Locale, m: Messages) {
  async function request<T extends z.ZodType>(method: string, path: string, schema: T, body?: object) {
    let res: Response;
    try {
      res = await fetch(`${url}/api/v1${path}`, {
        method,
        headers: { 'accept-language': locale, ...(body && { 'content-type': 'application/json' }) },
        body: body ? JSON.stringify(body) : null,
      });
    } catch {
      throw new Failure(m.cliUnreachable(url), EXIT.error);
    }
    const json: unknown = await res.json().catch(() => null);
    if (!res.ok) {
      const error = errorSchema.safeParse(json).data;
      throw new Failure(error ? [error.error, error.searchUrl].filter(Boolean).join('\n') : m.cliBadAnswer, EXIT.error);
    }
    const parsed = schema.safeParse(json);
    if (!parsed.success) throw new Failure(m.cliBadAnswer, EXIT.error);
    return parsed.data;
  }

  return {
    get: <T extends z.ZodType>(path: string, schema: T) => request('GET', path, schema),
    post: <T extends z.ZodType>(path: string, schema: T, body: object) => request('POST', path, schema, body),
  };
}

export type Client = ReturnType<typeof createClient>;
