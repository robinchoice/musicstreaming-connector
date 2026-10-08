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

// What web and app send along with feedback. The API adds its own version.
export const feedbackContextSchema = z.object({
  platform: z.enum(['web', 'ios', 'android']),
  page: z.string().max(500),
  device: z.string().max(300),
  viewport: z.string().max(50),
  // Failed API calls as "METHOD /path → status", newest first
  errors: z.array(z.string().max(300)).max(5),
});

export type FeedbackContext = z.infer<typeof feedbackContextSchema>;

// Shown to the tester as they are; zod's own messages are not
export const feedbackErrors = {
  tooShort: 'Schreib bitte mindestens 5 Zeichen.',
  invalidEmail: 'Die Mail-Adresse stimmt nicht.',
} as const;

export const feedbackSchema = z.object({
  kind: z.enum(['bug', 'idea']),
  message: z.string().trim().min(5, feedbackErrors.tooShort).max(5000),
  // Optional, there are no accounts. Only testers who leave it can be thanked.
  email: z.email(feedbackErrors.invalidEmail).max(255).toLowerCase().optional(),
  // PNG or JPEG, up to about 5 MB
  screenshot: z.base64().max(7_000_000).optional(),
  context: feedbackContextSchema,
});

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
  sharePath: string;
  candidates: { title: string; url: string; artworkUrl: string | null; album?: string; durationSeconds?: number }[];
}

export interface Song {
  source: { platform: Platform; title: string; artist: string; url: string; artworkUrl: string | null };
  sharePath: string;
  // found is false when only a search on that service is left
  links: Record<Platform, { url: string; found: boolean }>;
}

// Friends live on the device only. An invite link carries a name and a service.
export interface Friend { name: string; platform: Platform }
export const inviteSlugs: Record<Platform, string> = { appleMusic: 'apple', youtubeMusic: 'youtube', spotify: 'spotify', deezer: 'deezer' };

// One link if everyone uses the same service, otherwise one line per service plus the share page for everyone else
export function friendsMessage(song: Song, friends: Friend[], origin: string): string {
  const head = `🎵 ${song.source.title} – ${song.source.artist}`;
  const services = [...new Set(friends.map(friend => friend.platform))];
  if (services.length === 1) return `${head}\n${song.links[services[0]!].url}`;
  const lines = services.map(platform => `${platforms[platform]} (${friends.filter(friend => friend.platform === platform).map(friend => friend.name).join(', ')}): ${song.links[platform].url}`);
  return [head, ...lines, `Andere: ${origin}${song.sharePath}`].join('\n');
}
