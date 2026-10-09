<script lang="ts">
  import LegalPage from '$lib/components/LegalPage.svelte';
</script>

<LegalPage title="Datenschutz" lang="de" other={{ href: '/privacy', label: 'English' }}>
  <p>MusicLink funktioniert ohne Anmeldung, ohne Werbung und ohne Tracking. Diese Erklärung gilt für die Website und die Apps für iOS und Android.</p>

  <h2>Verantwortlicher</h2>
  <p>Robin Wahl, Pleasance, Bugginger Straße 37, 79114 Freiburg<br />E-Mail: <a href="mailto:hello@pleasance.org">hello@pleasance.org</a></p>

  <h2>Hosting</h2>
  <p>Website und Server laufen bei der Hetzner Online GmbH, Serverstandort ist Deutschland. Beim Aufruf fallen technisch notwendige Server-Logfiles an (IP-Adresse, Zeitpunkt, aufgerufene Adresse, Browser bzw. App-Version). Sie dienen nur dem sicheren Betrieb und werden nicht ausgewertet. Rechtsgrundlage ist Art. 6 Abs. 1 lit. f DSGVO.</p>

  <h2>Songs umwandeln</h2>
  <p>Wenn du einen Link einfügst oder aus einer anderen App teilst, schickt MusicLink ihn an unseren Server. Der Server liest Titel und Interpret bei der jeweiligen Plattform aus und sucht den Song bei der Zielplattform. Dafür fragt er öffentliche Schnittstellen dieser Anbieter ab:</p>
  <ul>
    <li><strong>Apple</strong> (Apple Distribution International, Irland): iTunes Search API für Songs aus Apple Music</li>
    <li><strong>YouTube</strong> (Google Ireland Limited, Irland): Suche und Song-Angaben von YouTube Music</li>
    <li><strong>ListenBrainz</strong> (MetaBrainz Foundation, USA): ordnet Titel und Interpret den passenden Spotify-Songs zu</li>
    <li><strong>Spotify</strong> (Spotify AB, Schweden) und <strong>Deezer</strong> (Deezer S.A., Frankreich): Song-Angaben zu Links dieser Dienste</li>
  </ul>
  <p>Übermittelt werden nur der Song-Link bzw. Titel, Interpret und Album. Diese Abfragen stellt unser Server, deine IP-Adresse und andere Angaben zu dir gehen dabei nicht an die Anbieter. Links und Ergebnisse speichern wir nicht dauerhaft. Damit geteilte Song-Links schnell laden, behält der Server das Ergebnis bis zu 24 Stunden im Arbeitsspeicher, ohne Bezug zu dir. Rechtsgrundlage ist Art. 6 Abs. 1 lit. b DSGVO.</p>
  <p>Die Cover der Ergebnisse lädt dein Gerät direkt von den Servern der Plattformen (Apple, Google, Spotify, Deezer). Dabei sehen diese deine IP-Adresse. Öffnest du einen Song in einer Musik-App oder auf einer Plattform, gilt deren Datenschutzerklärung.</p>

  <h2>Einstellungen auf deinem Gerät</h2>
  <p>Deine bevorzugte Zielplattform, deine Freunde und Gruppen (Name und Musikdienst) und, falls angegeben, deine E-Mail-Adresse für Feedback merkt sich MusicLink lokal auf deinem Gerät. Freunde erreichen unseren Server nicht. Ein Einladungslink enthält nur den Namen und den Dienst, die du selbst angibst. Cookies setzen wir nicht.</p>

  <h2>Feedback</h2>
  <p>Über „Feedback geben“ kannst du uns Fehler und Ideen schicken. Dabei übertragen wir deine Nachricht, auf Wunsch einen Screenshot und deine E-Mail-Adresse sowie technische Angaben (Seite, Plattform, Gerät, Fenstergröße, letzte Fehlermeldungen). Die Meldung wird auf unserem Server gespeichert und per E-Mail über die Proton AG (Schweiz) an uns weitergeleitet. Für die Schweiz besteht ein Angemessenheitsbeschluss der EU-Kommission. Gegen Missbrauch zählen wir Meldungen pro IP-Adresse, dieser Zähler wird nach einer Stunde gelöscht.</p>
  <p>Wir nutzen die Angaben nur, um die Meldung zu bearbeiten und dir zu antworten. Wir löschen sie, sobald sie erledigt ist, oder auf deinen Wunsch. Rechtsgrundlage ist Art. 6 Abs. 1 lit. f DSGVO, für die freiwillige E-Mail-Adresse Art. 6 Abs. 1 lit. a DSGVO.</p>

  <h2>Fehlerberichte</h2>
  <p>Stürzt etwas ab, schickt MusicLink einen technischen Fehlerbericht an unsere eigene GlitchTip-Installation bei Hetzner in Deutschland. Dafür nutzen Website, Server und Apps das Open-Source-SDK von Sentry. Die Berichte gehen nur an unseren Server, nicht an die Functional Software, Inc. (Sentry). Sie enthalten Fehlermeldung, Programmstelle, App- bzw. Browser-Version, Betriebssystem und Gerätetyp, aber keine Cookies, Eingaben oder personenbezogenen Angaben, und werden nach 90 Tagen gelöscht. Rechtsgrundlage ist Art. 6 Abs. 1 lit. f DSGVO.</p>

  <h2>Deine Rechte</h2>
  <p>Du hast das Recht auf Auskunft, Berichtigung, Löschung, Einschränkung der Verarbeitung, Datenübertragbarkeit und Widerspruch. Schreib uns dafür an <a href="mailto:hello@pleasance.org">hello@pleasance.org</a>. Außerdem kannst du dich bei einer Datenschutz-Aufsichtsbehörde beschweren, zum Beispiel beim Landesbeauftragten für den Datenschutz und die Informationsfreiheit Baden-Württemberg.</p>

  <p>Stand: Oktober 2026</p>
</LegalPage>
