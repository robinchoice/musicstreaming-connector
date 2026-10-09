<script lang="ts">
  import LegalPage from '$lib/components/LegalPage.svelte';
</script>

<LegalPage title="Privacy policy" lang="en" other={{ href: '/datenschutz', label: 'Deutsch' }}>
  <p>MusicLink works without sign-up, without ads and without tracking. This policy applies to the website and the apps for iOS and Android.</p>

  <h2>Controller</h2>
  <p>Robin Wahl, Pleasance, Bugginger Straße 37, 79114 Freiburg, Germany<br />Email: <a href="mailto:hello@pleasance.org">hello@pleasance.org</a></p>

  <h2>Hosting</h2>
  <p>Website and server run at Hetzner Online GmbH, servers located in Germany. Each request creates technically necessary server log files (IP address, time, requested address, browser or app version). They serve only secure operation and are not analysed. Legal basis is Art. 6(1)(f) GDPR.</p>

  <h2>Converting songs</h2>
  <p>When you paste a link or share it from another app, MusicLink sends it to our server. The server reads title and artist from the source platform and looks the song up on the target platform. To do so it queries public interfaces of these providers:</p>
  <ul>
    <li><strong>Apple</strong> (Apple Distribution International, Ireland): iTunes Search API for songs on Apple Music</li>
    <li><strong>YouTube</strong> (Google Ireland Limited, Ireland): search and song details from YouTube Music</li>
    <li><strong>ListenBrainz</strong> (MetaBrainz Foundation, USA): maps title and artist to the matching Spotify songs</li>
    <li><strong>Spotify</strong> (Spotify AB, Sweden) and <strong>Deezer</strong> (Deezer S.A., France): song details for links from these services</li>
  </ul>
  <p>Only the song link or title, artist and album are sent. Our server makes these requests, so your IP address and other details about you do not reach the providers. We don't store links or results permanently. So that shared song links load quickly, the server keeps the result in memory for up to 24 hours, without any reference to you. Legal basis is Art. 6(1)(b) GDPR.</p>
  <p>Your device loads the cover images of the results directly from the platforms' servers (Apple, Google, Spotify, Deezer), which see your IP address. When you open a song in a music app or on a platform, its privacy policy applies.</p>

  <h2>Settings on your device</h2>
  <p>MusicLink stores your preferred target platform, your friends and groups (name and music service) and, if given, your email address for feedback locally on your device. Friends never reach our server. An invite link only contains the name and service you enter yourself. We don't set cookies.</p>

  <h2>Feedback</h2>
  <p>With „Feedback geben“ you can send us bugs and ideas. We transmit your message, a screenshot if you like, your email address and technical details (page, platform, device, window size, latest error messages). The report is stored on our server and forwarded to us by email via Proton AG (Switzerland). The European Commission has issued an adequacy decision for Switzerland. Against abuse we count reports per IP address; this counter is deleted after one hour.</p>
  <p>We only use these details to handle the report and to reply to you. We delete them once the report is done, or on your request. Legal basis is Art. 6(1)(f) GDPR, for the optional email address Art. 6(1)(a) GDPR.</p>

  <h2>Error reports</h2>
  <p>When something crashes, MusicLink sends a technical error report to our own GlitchTip installation at Hetzner in Germany. Website, server and apps use Sentry's open-source SDK for this. Reports go only to our server, not to Functional Software, Inc. (Sentry). They contain the error message, code location, app or browser version, operating system and device type, but no cookies, input or personal data, and are deleted after 90 days. Legal basis is Art. 6(1)(f) GDPR.</p>

  <h2>Your rights</h2>
  <p>You have the right to access, rectification, erasure, restriction of processing, data portability and objection. Write to <a href="mailto:hello@pleasance.org">hello@pleasance.org</a>. You can also lodge a complaint with a data protection authority, for example the State Commissioner for Data Protection and Freedom of Information Baden-Württemberg.</p>

  <p>Last updated: October 2026</p>
</LegalPage>
