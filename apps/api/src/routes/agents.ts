import { APP_NAME } from '@app/shared';
import { type Context, Hono } from 'hono';
import { type Locale, type PublicPage, publicPages } from '../lib/public-pages';

// Public content for other people's agents, after llms.txt (https://llmstxt.org):
// /llms.txt lists the pages, /llms-full.txt holds all of them, every page is
// <path>.md as well. The web server forwards these paths here and answers
// Accept: text/markdown with the .md (hooks.server.ts). ?lang= picks the
// language, since agents rarely send Accept-Language.

const text = {
  de: {
    intro: (full: string) => `Nur öffentliche Inhalte. Jede Seite gibt es auch als Markdown: \`.md\` an die URL hängen, für die Startseite \`/index.md\`. Alles in einer Datei: ${full}`,
    pages: 'Seiten',
    other: 'English',
  },
  en: {
    intro: (full: string) => `Public content only. Every page is also available as Markdown: append \`.md\` to its URL, \`/index.md\` for the start page. Everything in one file: ${full}`,
    pages: 'Pages',
    other: 'Deutsch',
  },
};

const markdownPath = (path: string) => (path === '/' ? '/index.md' : `${path}.md`);

function language(c: Context) {
  const lang = c.req.query('lang');
  const tags = [lang, ...(c.req.header('accept-language') ?? '').split(',')].map(tag => tag?.trim().slice(0, 2).toLowerCase());
  const locale: Locale = tags.find(tag => tag === 'de' || tag === 'en') ?? 'de';
  // Links keep an explicit ?lang= so an agent stays in its language
  return { locale, query: lang ? `?lang=${locale}` : '' };
}

const markdown = (page: PublicPage) => [`# ${page.title}`, `> ${page.description}`, page.body].filter(Boolean).join('\n\n');

function reply(c: Context, body: string, type: string) {
  c.header('content-type', `${type}; charset=utf-8`);
  c.header('vary', 'accept, accept-language');
  return c.body(`${body}\n`);
}

export const agentRoutes = new Hono()
  .get('/llms.txt', c => {
    const { locale, query } = language(c);
    const url = process.env.APP_URL!;
    const other = locale === 'de' ? 'en' : 'de';
    const pages = publicPages(locale, url);
    return reply(c, [
      `# ${APP_NAME}`,
      `> ${pages[0]!.description}`,
      `${text[locale].intro(`${url}/llms-full.txt${query}`)}\n\n${text[locale].other}: ${url}/llms.txt?lang=${other}`,
      `## ${text[locale].pages}`,
      pages.map(page => `- [${page.title}](${url}${markdownPath(page.path)}${query}): ${page.description}`).join('\n'),
    ].join('\n\n'), 'text/plain');
  })
  .get('/llms-full.txt', c => reply(c, publicPages(language(c).locale, process.env.APP_URL!).map(markdown).join('\n\n---\n\n'), 'text/plain'))
  // English legal pages answer in English without ?lang= too
  .get('/:path{.+\\.md}', c => {
    const { locale } = language(c);
    const url = process.env.APP_URL!;
    const pages = [...publicPages(locale, url), ...publicPages(locale === 'de' ? 'en' : 'de', url)];
    const page = pages.find(p => markdownPath(p.path) === c.req.path);
    if (!page) return c.json({ error: 'Nicht gefunden' }, 404);
    return reply(c, markdown(page), 'text/markdown');
  });
