import { APP_NAME, APP_TAGLINE } from '@app/shared';

export type Locale = 'de' | 'en';

// A page anyone sees without a shared link. Agents get it as <path>.md,
// listed in llms.txt and joined in llms-full.txt (routes/agents.ts). body is
// Markdown below the title and description. path is the page's URL, so the
// browser test can open it.
export type PublicPage = { path: string; title: string; description: string; body?: string };

// Every static public page in the given language. Shared songs and invites are
// not listed: they belong to whoever shared them. The legal texts stay in their
// Svelte pages only, so there is one binding version; their Markdown points there.
export function publicPages(locale: Locale, url: string): PublicPage[] {
  const fullText = (path: string) => (locale === 'de' ? `Der vollständige Text steht unter ${url}${path}.` : `The full text is at ${url}${path}.`);
  if (locale === 'en') {
    return [
      {
        path: '/',
        title: APP_NAME,
        description: 'One link for a song that opens in everyone’s own streaming service.',
        body: [
          'Share songs from YouTube Music, Apple Music, Spotify or Deezer as a link for your people’s favourite player. No account, no stored song history. The website is in German.',
          '## How it works',
          '1. Bring a song: copy its link in your music app via “Share”.\n2. Find the recording: Songgate looks for the matching song on the target service and shows the matches.\n3. Pass it on: copy the right link and share it. Or share one link for everyone, where each person picks their own service.',
          '## Friends and groups',
          'Save friends with their music service, and Songgate builds one message with a link per service. Friends and groups stay on your device, an invite link only carries a name and a service.',
        ].join('\n\n'),
      },
      { path: '/imprint', title: 'Imprint', description: `Provider and contact of ${APP_NAME}.`, body: fullText('/imprint') },
      { path: '/privacy', title: 'Privacy policy', description: `${APP_NAME} works without sign-up, without ads and without tracking.`, body: fullText('/privacy') },
    ];
  }
  return [
    {
      path: '/',
      title: APP_NAME,
      description: APP_TAGLINE,
      body: [
        'Teile Songs aus YouTube Music, Apple Music, Spotify oder Deezer als Link für den Lieblingsplayer deiner Menschen. Ohne Konto, ohne gespeicherte Song-Historie.',
        '## So funktioniert’s',
        '1. Song mitbringen: Den Link in deiner Musik-App über „Teilen“ kopieren.\n2. Aufnahme finden: Songgate sucht den passenden Song beim Zieldienst und zeigt dir die Treffer.\n3. Freude weitergeben: Passenden Link kopieren und teilen. Oder ein Link für alle, auf dem jeder seinen Dienst wählt.',
        '## Freunde und Gruppen',
        'Speichere Freunde mit ihrem Musikdienst, dann baut Songgate eine Nachricht mit einem Link pro Dienst. Freunde und Gruppen bleiben auf deinem Gerät, ein Einladungslink enthält nur Namen und Dienst.',
      ].join('\n\n'),
    },
    { path: '/impressum', title: 'Impressum', description: `Anbieter und Kontakt von ${APP_NAME}.`, body: fullText('/impressum') },
    { path: '/datenschutz', title: 'Datenschutz', description: `${APP_NAME} funktioniert ohne Anmeldung, ohne Werbung und ohne Tracking.`, body: fullText('/datenschutz') },
  ];
}
