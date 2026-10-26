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
          'Share songs and albums from YouTube Music, Apple Music, Spotify or Deezer as a link for your people’s favourite player. No account, no stored song history. The website is in German.',
          '## Paste a link',
          'Copy a song or album link in your music app via “Share” and paste it. Songgate finds it on all four services at once.',
          '## One link for everyone',
          'By default the message carries one link for everyone, where each person picks their own service. In a group chat that gives a single preview with the cover.',
          '## Pick services, friends or groups',
          'Tap the services you want and the message gets one line per service. Save friends with their music service, and picking them or a group picks their services. Friends and groups stay on your device, an invite link only carries a name and a service.',
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
        'Teile Songs und Alben aus YouTube Music, Apple Music, Spotify oder Deezer als Link für den Lieblingsplayer deiner Menschen. Ohne Konto, ohne gespeicherte Song-Historie.',
        '## Link einfügen',
        'Den Song- oder Albumlink in deiner Musik-App über „Teilen“ kopieren und einfügen. Songgate findet ihn bei allen vier Diensten auf einmal.',
        '## Ein Link für alle',
        'Voreingestellt enthält die Nachricht einen Link für alle, auf dem jeder seinen Dienst wählt. Im Gruppenchat gibt das eine einzige Vorschau mit Cover.',
        '## Dienste, Freunde oder Gruppen wählen',
        'Tippe Dienste an, dann bekommt die Nachricht eine Zeile pro Dienst. Speichere Freunde mit ihrem Musikdienst, dann wählen sie oder eine Gruppe ihre Dienste vor. Freunde und Gruppen bleiben auf deinem Gerät, ein Einladungslink enthält nur Namen und Dienst.',
      ].join('\n\n'),
    },
    { path: '/impressum', title: 'Impressum', description: `Anbieter und Kontakt von ${APP_NAME}.`, body: fullText('/impressum') },
    { path: '/datenschutz', title: 'Datenschutz', description: `${APP_NAME} funktioniert ohne Anmeldung, ohne Werbung und ohne Tracking.`, body: fullText('/datenschutz') },
  ];
}
