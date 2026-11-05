import { z } from 'zod';
import { type Locale, messages } from './messages';

export const APP_NAME = 'Songgate';
export const APP_BAND = { from: 3.85, to: 4.55 };
// True once Songgate is live as 1.0 (starter README, "Live als 1.0"). From then on
// the bug button waits for the test mode switch, see testMode in the web's feedback.svelte.ts.
export const LIVE = true;
export { bandColor, bandGradient, DEEP, GLOW } from './band';
export { type Kind, type Locale, type Messages, messages, pickLocale } from './messages';
import type { Kind } from './messages';

export const platformSchema = z.enum(['appleMusic', 'youtubeMusic', 'spotify', 'deezer', 'tidal', 'amazonMusic']);
export type Platform = z.infer<typeof platformSchema>;
export const platforms = { appleMusic: 'Apple Music', youtubeMusic: 'YouTube Music', spotify: 'Spotify', deezer: 'Deezer', tidal: 'TIDAL', amazonMusic: 'Amazon Music' } as const satisfies Record<Platform, string>;
// Amazon Music has no open catalogue: it is never a source and always gets a search link
export const serviceOrder: Platform[] = ['spotify', 'appleMusic', 'youtubeMusic', 'deezer', 'tidal', 'amazonMusic'];
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
  [/(?:music|podcasts|itunes)\.apple\.com\//, 'appleMusic'], [/youtu(?:be\.com|\.be)\//, 'youtubeMusic'],
  [/open\.spotify\.com\/|spotify\.link\//, 'spotify'], [/deezer\.com\//, 'deezer'], [/tidal\.com\//, 'tidal'],
];

// The service a pasted link comes from, before the API has looked at it
export const sourceOf = (input: string): Platform | undefined => sources.find(([pattern]) => pattern.test(input))?.[1];

export const isPodcast = (kind: Kind) => kind === 'podcast' || kind === 'episode';
// TIDAL has no podcasts, Apple's podcasts live in Apple Podcasts
export const servicesFor = (kind: Kind): Platform[] => isPodcast(kind) ? serviceOrder.filter(platform => platform !== 'tidal') : serviceOrder;
export const serviceName = (platform: Platform, kind: Kind) => platform === 'appleMusic' && isPodcast(kind) ? 'Apple Podcasts' : platforms[platform];
// Other podcast apps, subscribed by Apple ID or RSS feed
export interface PodcastApp { name: string; url: string }

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
  // Shows and episodes only
  apps?: PodcastApp[];
}

// Friends live on the device only. An invite link carries a name and a service.
export interface Friend { name: string; platform: Platform }
export const inviteSlugs: Record<Platform, string> = { appleMusic: 'apple', youtubeMusic: 'youtube', spotify: 'spotify', deezer: 'deezer', tidal: 'tidal', amazonMusic: 'amazon' };

// A share page may name its sender, so the recipient can save them and answer with their own service
export function shareUrl(origin: string, path: string, from: Friend | null): string {
  return from ? `${origin}${path}?${new URLSearchParams({ from: from.name, service: inviteSlugs[from.platform] })}` : `${origin}${path}`;
}

// Without services only the share page, for group chats where everyone picks their own.
// One service gets its link, several get one line each plus the share page for everyone else.
// With an own invite the share page comes along for one service too, so the recipient can save the sender.
// The services default to those of the friends, who are named next to their service.
export function friendsMessage(song: Song, friends: Friend[], origin: string, from: Friend | null = null, chosen: Platform[] = [...new Set(friends.map(friend => friend.platform))], locale: Locale = 'de'): string {
  const m = messages[locale];
  const { kind, title, artist } = song.source;
  const head = `${isPodcast(kind) ? '🎙️' : kind === 'album' ? '💿' : '🎵'} ${artist ? `${title} – ${artist}` : title}`;
  // A friend whose service has no podcasts gets the share page
  const services = chosen.filter(platform => servicesFor(kind).includes(platform));
  const everyone = shareUrl(origin, song.sharePath, from);
  // Every message ends with where it was made, so recipients find Songgate too
  const footer = `\n\n${m.sharedWith} ${origin.replace(/^https?:\/\//, '')}`;
  if (!services.length) return [head, everyone].join('\n') + footer;
  if (services.length === 1) return [head, song.links[services[0]!].url, ...(from ? [`${m.allServices}: ${everyone}`] : [])].join('\n') + footer;
  const lines = services.map(platform => {
    const names = friends.filter(friend => friend.platform === platform).map(friend => friend.name);
    return `${serviceName(platform, kind)}${names.length ? ` (${names.join(', ')})` : ''}: ${song.links[platform].url}`;
  });
  return [head, ...lines, `${m.others}: ${everyone}`].join('\n') + footer;
}
