import { type Locale, messages } from '@app/shared';
import { goto, invalidateAll } from '$app/navigation';
import { page } from '$app/state';

// Texts in the current language, e.g. {t().share}. hooks.server.ts takes the
// language from ?lang=, else the cookie, else the browser.
export const t = () => messages[page.data.locale];

// The legal pages have one URL per language, the footer switch goes to the other one
const legal: Record<string, string> = { '/impressum': '/imprint', '/imprint': '/impressum', '/datenschutz': '/privacy', '/privacy': '/datenschutz' };

export async function setLocale(locale: Locale) {
  document.cookie = `locale=${locale}; path=/; max-age=31536000; samesite=lax`;
  const url = new URL(page.url);
  url.searchParams.delete('lang');
  url.pathname = legal[url.pathname] ?? url.pathname;
  if (url.href !== page.url.href) await goto(url, { replaceState: true, noScroll: true, keepFocus: true, invalidateAll: true });
  else await invalidateAll();
  document.documentElement.lang = locale;
}
