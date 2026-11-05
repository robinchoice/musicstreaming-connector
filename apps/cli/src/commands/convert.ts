import { countries, inviteSlugs, type Platform, platformSchema, serviceName, servicesFor } from '@app/shared';
import { z } from 'zod';
import { type Command, EXIT, Failure, str } from '../command';
import { SLUG } from '../config';

const kind = z.enum(['song', 'album', 'podcast', 'episode']);
const songSchema = z.object({
  source: z.object({ kind, platform: platformSchema, title: z.string(), artist: z.string(), url: z.string(), artworkUrl: z.string().nullable() }),
  sharePath: z.string(),
  links: z.record(platformSchema, z.object({ url: z.string(), found: z.boolean() })),
  apps: z.array(z.object({ name: z.string(), url: z.string() })).exactOptional(),
});
// "Title – Artist", a show without publisher only by its title
const heading = (source: { title: string; artist: string }) => (source.artist ? `${source.title} – ${source.artist}` : source.title);
const conversionSchema = z.object({
  target: platformSchema,
  source: z.object({ kind, title: z.string(), artist: z.string(), url: z.string() }),
  sharePath: z.string(),
  candidates: z.array(z.object({ title: z.string(), url: z.string(), album: z.string().exactOptional() })),
});

// --to takes the short names of the invite links: apple, youtube, spotify, deezer, tidal, amazon
const targets = Object.fromEntries(Object.entries(inviteSlugs).map(([platform, slug]) => [slug, platform as Platform]));

// The core of Songgate: what the web shows for a shared link. Without --to like
// the share page (GET /song), with --to like the converter in web and app (POST /convert).
export const convert: Command = {
  help: (m) => [
    ['convert <link>|-', m.cliConvertHelp],
    [`convert <link>|- --to ${Object.keys(targets).join('|')}`, m.cliConvertToHelp],
    [`  --country ${countries.join('|')}`, m.cliCountryHelp],
  ],
  options: { to: { type: 'string' }, country: { type: 'string' } },
  async run({ api, url, values, positionals, m, io }) {
    const to = str(values.to);
    const country = str(values.country)?.toUpperCase() ?? 'DE';
    const target = to === undefined ? undefined : targets[to];
    if (to !== undefined && !target) throw new Failure(m.cliBadOptions(`--to ${Object.keys(targets).join('|')}`, SLUG), EXIT.usage);
    if (!countries.some((code) => code === country)) throw new Failure(m.cliBadOptions(`--country ${countries.join('|')}`, SLUG), EXIT.usage);
    const [link, ...extra] = positionals;
    if (extra.length > 0) throw new Failure(m.cliBadOptions(extra.join(' '), SLUG), EXIT.usage);
    const input = (link === '-' ? await io.stdin() : (link ?? '')).trim();
    if (!input) throw new Failure(m.cliMissingLink(SLUG), EXIT.usage);

    if (target) {
      const conversion = await api.post('/convert', conversionSchema, { input, target, country });
      const shareUrl = url + conversion.sharePath;
      return {
        data: { ...conversion, shareUrl },
        text: [
          `${heading(conversion.source)} → ${serviceName(target, conversion.source.kind)}`,
          ...conversion.candidates.map((hit) => `  ${[hit.title, hit.album].filter(Boolean).join(' · ')}  ${hit.url}`),
          `${m.cliForEveryone}: ${shareUrl}`,
        ].join('\n'),
      };
    }

    const song = await api.get(`/song?${new URLSearchParams({ input, country })}`, songSchema);
    const shareUrl = url + song.sharePath;
    const services = servicesFor(song.source.kind);
    const names = services.map((platform) => serviceName(platform, song.source.kind));
    const width = Math.max(...names.map((name) => name.length), ...(song.apps ?? []).map((app) => app.name.length)) + 2;
    return {
      data: { ...song, shareUrl },
      text: [
        heading(song.source),
        ...services.map((platform, i) => {
          const { url, found } = song.links[platform];
          return `  ${names[i]!.padEnd(width)}${url}${found ? '' : `  (${m.cliSearchOnly})`}`;
        }),
        ...(song.apps?.length ? [`${m.otherApps}:`, ...song.apps.map((app) => `  ${app.name.padEnd(width)}${app.url}`)] : []),
        `${m.cliForEveryone}: ${shareUrl}`,
      ].join('\n'),
    };
  },
};
