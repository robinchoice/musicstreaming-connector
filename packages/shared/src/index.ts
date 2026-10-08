import { z } from 'zod';

export const APP_NAME = 'MusicLink';
export const APP_BAND = { from: 3.85, to: 4.55 };
export { bandColor, bandGradient, DEEP, GLOW } from './band';

export const platforms = { appleMusic: 'Apple Music', youtubeMusic: 'YouTube Music', spotify: 'Spotify', deezer: 'Deezer' } as const;
export type Platform = keyof typeof platforms;
export const countries = ['DE', 'AT', 'CH', 'US', 'GB'] as const;
export const conversionInput = z.object({
  input: z.string().trim().min(1).max(4096),
  target: z.enum(['appleMusic', 'youtubeMusic', 'spotify', 'deezer']),
  country: z.enum(countries).default('DE'),
});
export type ConversionInput = z.infer<typeof conversionInput>;

export const failureMessages = {
  INVALID_LINK: 'Teile bitte einen einzelnen Song aus YouTube Music, Apple Music, Spotify oder Deezer mit MusicLink.',
  UNSUPPORTED_LINK: 'Teile einen Song aus YouTube Music, Apple Music, Spotify oder Deezer und wähle einen anderen Zieldienst.',
  SOURCE_UNAVAILABLE: 'Die Angaben zu diesem Song konnten nicht geladen werden.',
  NO_MATCH: 'Für diese Aufnahme wurde kein passender Treffer gefunden.',
  RATE_LIMITED: 'Der Musikdienst erhält gerade zu viele Anfragen. Versuche es später erneut.',
  NETWORK: 'Die Musikdienste sind gerade nicht erreichbar. Versuche es erneut.',
} as const;

export type FailureCode = keyof typeof failureMessages;

const sources: [RegExp, Platform][] = [
  [/music\.apple\.com\//, 'appleMusic'], [/youtu(?:be\.com|\.be)\//, 'youtubeMusic'],
  [/open\.spotify\.com\//, 'spotify'], [/deezer\.com\//, 'deezer'],
];

export function targetsFor(input: string): Platform[] {
  const source = sources.find(([pattern]) => pattern.test(input))?.[1];
  return (Object.keys(platforms) as Platform[]).filter(platform => platform !== source);
}

export interface Conversion {
  target: Platform;
  source: { title: string; artist: string; url: string };
  candidates: { title: string; url: string; artworkUrl: string | null; album?: string; durationSeconds?: number }[];
}
