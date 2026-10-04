import { z } from 'zod';

export const APP_NAME = 'MusicLink';

export const platforms = { appleMusic: 'Apple Music', youtubeMusic: 'YouTube Music', spotify: 'Spotify' } as const;
export const conversionInput = z.object({
  input: z.string().trim().min(1).max(4096),
  target: z.enum(['appleMusic', 'youtubeMusic', 'spotify']),
  country: z.enum(['DE', 'AT', 'CH', 'US', 'GB']).default('DE'),
});
export type ConversionInput = z.infer<typeof conversionInput>;

export const failureMessages = {
  INVALID_LINK: 'Teile bitte einen einzelnen Song aus YouTube Music oder Apple Music mit MusicLink.',
  UNSUPPORTED_LINK: 'Teile einen Song aus YouTube Music oder Apple Music und wähle einen anderen Zieldienst.',
  SOURCE_UNAVAILABLE: 'Die Angaben zu diesem Song konnten nicht geladen werden.',
  NO_MATCH: 'Für diese Aufnahme wurde kein passender Treffer gefunden.',
  RATE_LIMITED: 'Der Musikdienst erhält gerade zu viele Anfragen. Versuche es später erneut.',
  NETWORK: 'Die Musikdienste sind gerade nicht erreichbar. Versuche es erneut.',
} as const;

export type FailureCode = keyof typeof failureMessages;

export interface Conversion {
  target: keyof typeof platforms;
  source: { title: string; artist: string; url: string };
  candidates: { title: string; url: string; artworkUrl: string | null; album?: string; durationSeconds?: number }[];
}
