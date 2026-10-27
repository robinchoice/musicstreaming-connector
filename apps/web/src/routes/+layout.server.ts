import type { LayoutServerLoad } from './$types';

// Every page gets the language from hooks.server.ts, see $lib/i18n.ts
export const load: LayoutServerLoad = ({ locals }) => ({ locale: locals.locale });
