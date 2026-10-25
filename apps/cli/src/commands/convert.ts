import { countries, inviteSlugs, type Platform, platformSchema, platforms } from '@app/shared';
import { z } from 'zod';
import { type Command, EXIT, Failure, str } from '../command';
import { SLUG } from '../config';

const kind = z.enum(['song', 'album']);
const songSchema = z.object({
  source: z.object({ kind, platform: platformSchema, title: z.string(), artist: z.string(), url: z.string(), artworkUrl: z.string().nullable() }),
  sharePath: z.string(),
  links: z.record(platformSchema, z.object({ url: z.string(), found: z.boolean() })),
});
const conversionSchema = z.object({
  target: platformSchema,
  source: z.object({ kind, title: z.string(), artist: z.string(), url: z.string() }),
  sharePath: z.string(),
  candidates: z.array(z.object({ title: z.string(), url: z.string(), album: z.string().exactOptional() })),
});

// --to takes the short names of the invite links: apple, youtube, spotify, deezer
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
          `${conversion.source.title} – ${conversion.source.artist} → ${platforms[target]}`,
          ...conversion.candidates.map((hit) => `  ${[hit.title, hit.album].filter(Boolean).join(' · ')}  ${hit.url}`),
          `${m.cliForEveryone}: ${shareUrl}`,
        ].join('\n'),
      };
    }

    const song = await api.get(`/song?${new URLSearchParams({ input, country })}`, songSchema);
    const shareUrl = url + song.sharePath;
    const width = Math.max(...Object.values(platforms).map((name) => name.length)) + 2;
    return {
      data: { ...song, shareUrl },
      text: [
        `${song.source.title} – ${song.source.artist}`,
        ...platformSchema.options.map((platform) => {
          const { url, found } = song.links[platform];
          return `  ${platforms[platform].padEnd(width)}${url}${found ? '' : `  (${m.cliSearchOnly})`}`;
        }),
        `${m.cliForEveryone}: ${shareUrl}`,
      ].join('\n'),
    };
  },
};
