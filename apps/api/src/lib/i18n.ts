import { messages, pickLocale } from '@app/shared';
import type { Context } from 'hono';

// The language the client asks for. Web, app and CLI send the chosen one as Accept-Language.
export const locale = (c: Context) => pickLocale(c.req.header('accept-language'));

// Texts in that language
export const t = (c: Context) => messages[locale(c)];
