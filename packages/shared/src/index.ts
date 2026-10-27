import { z } from 'zod';
import { type Locale, messages } from './messages';

export const APP_NAME = 'Songgate';
export const APP_BAND = { from: 3.85, to: 4.55 };
// True once Songgate is live as 1.0 (starter README, "Live als 1.0"). From then on
// the bug button waits for the test mode switch, see testMode in the web's feedback.svelte.ts.
export const LIVE = false;
export { bandColor, bandGradient, DEEP, GLOW } from './band';
export { type Locale, type Messages, messages, pickLocale } from './messages';

export const platforms = { appleMusic: 'Apple Music', youtubeMusic: 'YouTube Music', spotify: 'Spotify', deezer: 'Deezer' } as const;
export type Platform = keyof typeof platforms;
export const serviceOrder: Platform[] = ['spotify', 'appleMusic', 'youtubeMusic', 'deezer'];
export const platformSchema = z.enum(['appleMusic', 'youtubeMusic', 'spotify', 'deezer']);
export const countries = ['DE', 'AT', 'CH', 'US', 'GB'] as const;
export const conversionInput = z.object({
  input: z.string().trim().min(1).max(4096),
  target: platformSchema,
  country: z.enum(countries).default('DE'),
});
export type ConversionInput = z.infer<typeof conversionInput>;

export type FailureCode = keyof (typeof messages)['de']['failures'];

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

export const feedbackSchema = z.object({
  kind: z.enum(['bug', 'idea']),
  // Messages are keys from messages.ts, the API shows them in the client's language
  message: z.string().trim().min(5, 'feedbackTooShort').max(5000),
  // Optional, there are no accounts. Only testers who leave it can be thanked.
  email: z.email('invalidEmail').max(255).toLowerCase().optional(),
  // PNG or JPEG, up to about 5 MB
  screenshot: z.base64().max(7_000_000).optional(),
  context: feedbackContextSchema,
});

const sources: [RegExp, Platform][] = [
  [/music\.apple\.com\//, 'appleMusic'], [/youtu(?:be\.com|\.be)\//, 'youtubeMusic'],
  [/open\.spotify\.com\/|spotify\.link\//, 'spotify'], [/deezer\.com\//, 'deezer'],
];

// The service a pasted link comes from, before the API has looked at it
export const sourceOf = (input: string): Platform | undefined => sources.find(([pattern]) => pattern.test(input))?.[1];

export type Kind = 'song' | 'album';

export interface Conversion {
  target: Platform;
  source: { kind: Kind; title: string; artist: string; url: string };
  sharePath: string;
  candidates: { title: string; url: string; artworkUrl: string | null; album?: string; durationSeconds?: number }[];
}

export interface Song {
  source: { kind: Kind; platform: Platform; title: string; artist: string; url: string; artworkUrl: string | null };
  sharePath: string;
  // found is false when only a search on that service is left
  links: Record<Platform, { url: string; found: boolean }>;
}

// Friends live on the device only. An invite link carries a name and a service.
export interface Friend { name: string; platform: Platform }
export const inviteSlugs: Record<Platform, string> = { appleMusic: 'apple', youtubeMusic: 'youtube', spotify: 'spotify', deezer: 'deezer' };

// A share page may name its sender, so the recipient can save them and answer with their own service
export function shareUrl(origin: string, path: string, from: Friend | null): string {
  return from ? `${origin}${path}?${new URLSearchParams({ from: from.name, service: inviteSlugs[from.platform] })}` : `${origin}${path}`;
}

// Without services only the share page, for group chats where everyone picks their own.
// One service gets its link, several get one line each plus the share page for everyone else.
// With an own invite the share page comes along for one service too, so the recipient can save the sender.
// The services default to those of the friends, who are named next to their service.
export function friendsMessage(song: Song, friends: Friend[], origin: string, from: Friend | null = null, services: Platform[] = [...new Set(friends.map(friend => friend.platform))], locale: Locale = 'de'): string {
  const m = messages[locale];
  const head = `${song.source.kind === 'album' ? '💿' : '🎵'} ${song.source.title} – ${song.source.artist}`;
  const everyone = shareUrl(origin, song.sharePath, from);
  if (!services.length) return [head, everyone].join('\n');
  if (services.length === 1) return [head, song.links[services[0]!].url, ...(from ? [`${m.allServices}: ${everyone}`] : [])].join('\n');
  const lines = services.map(platform => {
    const names = friends.filter(friend => friend.platform === platform).map(friend => friend.name);
    return `${platforms[platform]}${names.length ? ` (${names.join(', ')})` : ''}: ${song.links[platform].url}`;
  });
  return [head, ...lines, `${m.others}: ${everyone}`].join('\n');
}
