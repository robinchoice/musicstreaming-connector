/// Every text the app shows, one class per language. A text missing in one
/// language is a compile error. Web and API have theirs in packages/shared,
/// the iOS share extension in ShareTexts (ios/ShareExtension/ShareModel.swift).
enum AppLocale {
  de(De()),
  en(En());

  const AppLocale(this.messages);
  final Messages messages;
}

abstract class Messages {
  const Messages();

  // API
  String get serviceUnavailable;
  String get searchTimeout;
  String get sendTimeout;
  String get offline;
  String get invalidAnswer;

  // Converter
  String get preferencesFailed;
  String get setupSaveFailed;
  String get settingsTitle;
  String get settings;
  String get openGuide;
  String get friendsAndInvite;
  String get giveFeedback;
  String get testMode;
  String get testModeHint;
  String get support;
  String supportIntro(String app);
  String get supportSong;
  String get supportSingle;
  String get supportAlbum;
  String get supportThanks;
  String get supportUnavailable;
  String get supportFailed;

  /// Label of the language button, in the language it switches to
  String get otherLanguage;
  String get privacy;
  String get imprint;
  String get sharedLinkUnreadable;
  String get clipboardEmpty;
  String get messageCopied;
  String get copyFailed;
  String get shareFailed;
  String get backToInput;
  String get headline;
  String get intro;
  String get linkHint;
  String get paste;
  String get find;
  String get searching;
  String get linkFrom;
  String get shareDirectTitle;
  String get shareDirectBody;
  String get shareDirectButton;
  String get shareAndroid;
  String get privacyNote;
  String kindFrom(bool album, String? service);
  String get otherLink;
  String get hintEveryone;
  String hintOne(String service, bool withName);
  String get hintSeveral;
  String get share;
  String get copy;
  String get searchOnly;
  String get source;
  String get found;
  String get madeBy;

  // Share setup
  String get shareMenuFallback;
  String get back;
  String get setupKicker;
  String get welcomeKicker;
  String get setupTitle;
  String get setupTitleAccent;
  String get welcomeTitle;
  String get welcomeTitleAccent;
  String get setupIntro;
  String get welcomeIntro;
  List<(String, String, String)> get setupSteps;
  String get tryAgain;
  String get setUpWithExample;
  String get continueToApp;
  String get setUpLater;
  String get guideReopen;
  String get orderNote;
  List<String> get welcomePoints;
  String get setUpShareMenu;
  String get laterTryNow;

  // Friends
  String get toWhom;
  String get edit;
  String get everyone;
  String get addNew;
  String get saveAsGroup;
  String groupOf(String names);
  String get groupNameLabel;
  String get friendsEmpty;
  String get cancel;
  String get save;
  String get addFriend;
  String get name;
  String get listensOn;
  String get myInvite;
  String get inviteQrLabel;
  String get scanHint;
  String get done;
  String get friends;
  String get friendsIntro;
  String get shareMyInvite;
  String shareInviteAs(String name, String service);
  String get showInviteQr;
  String get addFriendManually;
  String get noFriends;
  String get editFriend;
  String remove(String name);
  String get groups;
  String get groupsHint;
  String get invite;
  String get inviteIncomplete;
  String friendListensOn(String name, String service);
  String saveFriendHint(String name, String service);
  String saveName(String name);
  String get notNow;
  String inviteText(String service, String url);

  /// Lines in the message, the same as friendsMessage in packages/shared
  String get allServices;
  String get others;
  String get sharedWith;

  // Feedback
  String get reportBug;
  String get feedbackThanks;
  String get feedbackThanksReply;
  String get bugPlaceholder;
  String get ideaPlaceholder;
  String get removeScreenshot;
  String get markSpot;
  String get whatIsSent;
  String get contextPage;
  String get contextDevice;
  String get contextViewport;
  String get contextErrors;
  String get emailLabel;
  String get send;
  String get markHint;

  // Update
  String get updateTitle;
  String updateBody(String app);
  String get updateNow;
}

class De extends Messages {
  const De();

  @override
  String get serviceUnavailable => 'Der Dienst ist gerade nicht erreichbar.';
  @override
  String get searchTimeout => 'Die Suche dauert zu lange. Versuche es erneut.';
  @override
  String get sendTimeout => 'Das Senden dauert zu lange. Versuche es erneut.';
  @override
  String get offline => 'Keine Verbindung zum Server. Versuche es erneut.';
  @override
  String get invalidAnswer => 'Der Dienst hat eine ungültige Antwort gesendet.';

  @override
  String get preferencesFailed => 'Einstellungen konnten nicht geladen werden.';
  @override
  String get setupSaveFailed =>
      'Die Einrichtung konnte nicht gespeichert werden.';
  @override
  String get settingsTitle => 'Deine Einstellungen';
  @override
  String get settings => 'Einstellungen';
  @override
  String get openGuide => 'Favoriten-Anleitung öffnen';
  @override
  String get friendsAndInvite => 'Freunde und Einladung';
  @override
  String get giveFeedback => 'Feedback geben';
  @override
  String get testMode => 'Testmodus';
  @override
  String get testModeHint =>
      'Zeigt den Käfer-Knopf, mit dem du Fehler samt Screenshot meldest.';
  @override
  String get support => 'Unterstützen';
  @override
  String supportIntro(String app) =>
      '$app bleibt gratis. Wenn es dir gefällt, unterstütze es mit einem einmaligen Kauf. Er schaltet nichts frei, er hilft nur, $app weiterzubauen.';
  @override
  String get supportSong => 'Ein Song';
  @override
  String get supportSingle => 'Eine Single';
  @override
  String get supportAlbum => 'Ein Album';
  @override
  String get supportThanks => 'Danke für deine Unterstützung!';
  @override
  String get supportUnavailable =>
      'Der Store ist gerade nicht erreichbar. Du kannst es später noch einmal versuchen.';
  @override
  String get supportFailed => 'Der Kauf hat nicht geklappt.';
  @override
  String get otherLanguage => 'English';
  @override
  String get privacy => 'Datenschutz';
  @override
  String get imprint => 'Impressum';
  @override
  String get sharedLinkUnreadable =>
      'Der geteilte Link konnte nicht gelesen werden.';
  @override
  String get clipboardEmpty => 'In der Zwischenablage ist kein Link.';
  @override
  String get messageCopied => 'Nachricht kopiert.';
  @override
  String get copyFailed => 'Die Nachricht konnte nicht kopiert werden.';
  @override
  String get shareFailed =>
      'Teilen nicht möglich. Kopiere stattdessen die Nachricht.';
  @override
  String get backToInput => 'Zurück zum Musiklink';
  @override
  String get headline => 'Teil Musik. Jeder hört sie in seinem Dienst.';
  @override
  String get intro =>
      'Füge einen Song- oder Albumlink ein. Songgate findet ihn bei Spotify, Apple Music, YouTube Music und Deezer.';
  @override
  String get linkHint => 'Song- oder Albumlink';
  @override
  String get paste => 'Einfügen';
  @override
  String get find => 'Finden';
  @override
  String get searching => 'Suche bei allen vier Diensten …';
  @override
  String get linkFrom => 'Link aus ';
  @override
  String get shareDirectTitle => 'Nächstes Mal direkt teilen';
  @override
  String get shareDirectBody =>
      'Hole Songgate nach vorne ins Teilen-Menü. Dann sparst du dir das Einfügen.';
  @override
  String get shareDirectButton => 'So richtest du es ein';
  @override
  String get shareAndroid =>
      'Direkt aus deiner Musik-App: Öffne bei einem Song das Teilen-Menü und wähle Songgate.';
  @override
  String get privacyNote =>
      'Ohne Konto. Freunde und Gruppen bleiben auf deinem Gerät. Dein Link geht an unseren Dienst, die Treffer liefern Apple, YouTube, Spotify, Deezer und ListenBrainz.';
  @override
  String kindFrom(bool album, String? service) =>
      '${album ? 'Album' : 'Song'}${service == null ? '' : ' aus $service'}';
  @override
  String get otherLink => 'Anderen Link einfügen';
  @override
  String get hintEveryone =>
      'Ein Link für alle. Jede und jeder wählt den eigenen Dienst, ideal für Gruppenchats.';
  @override
  String hintOne(String service, bool withName) =>
      'Direktlink für $service${withName ? ', dazu der Link für alle mit deinem Namen' : ''}.';
  @override
  String get hintSeveral =>
      'Eine Zeile pro Dienst, für alle anderen der Link für alle.';
  @override
  String get share => 'Teilen';
  @override
  String get copy => 'Kopieren';
  @override
  String get searchOnly => 'Nur Suche';
  @override
  String get source => 'Quelle';
  @override
  String get found => 'Gefunden';
  @override
  String get madeBy => 'ein Werkzeug von';

  @override
  String get shareMenuFallback =>
      'Öffne bei einem Song in deiner Musik-App das Teilen-Menü und folge dieser Anleitung.';
  @override
  String get back => 'Zurück';
  @override
  String get setupKicker => 'EINMAL KURZ EINRICHTEN';
  @override
  String get welcomeKicker => 'WENIGER SUCHEN. MEHR MUSIK.';
  @override
  String get setupTitle => 'Beim nächsten Song\n';
  @override
  String get setupTitleAccent => 'gleich zur Hand.';
  @override
  String get welcomeTitle => 'Dein Song.\n';
  @override
  String get welcomeTitleAccent => 'Ihr Lieblingsplayer.';
  @override
  String get setupIntro =>
      'Füge Songgate zu deinen Favoriten im iPhone-Teilen-Menü hinzu.';
  @override
  String get welcomeIntro =>
      'Teile Musik in dem Dienst, den deine Freunde nutzen. Direkt aus deiner Musik-App.';
  @override
  List<(String, String, String)> get setupSteps => const [
    (
      '01',
      '„Mehr“ öffnen',
      'In der Reihe mit den Apps ganz nach rechts wischen.',
    ),
    (
      '02',
      '„Bearbeiten“ → Plus bei Songgate',
      'Damit kommt Songgate zu deinen Favoriten.',
    ),
    (
      '03',
      'Songgate nach oben ziehen',
      'Über den Griff rechts. Dann auf „Fertig“ tippen.',
    ),
  ];
  @override
  String get tryAgain => 'Noch einmal ausprobieren';
  @override
  String get setUpWithExample => 'Mit Beispiel-Song einrichten';
  @override
  String get continueToApp => 'Weiter zur App';
  @override
  String get setUpLater => 'Später einrichten';
  @override
  String get guideReopen =>
      'Du kannst die Anleitung jederzeit wieder öffnen. Deine Favoriten verwaltest du selbst im iOS-Menü.';
  @override
  String get orderNote => 'Die Reihenfolge legst du selbst im iOS-Menü fest.';
  @override
  List<String> get welcomePoints => const [
    'Ohne Anmeldung loslegen',
    'In deiner Musik-App bleiben',
    'Songgate einmal nach vorne holen',
  ];
  @override
  String get setUpShareMenu => 'Teilen-Menü einrichten';
  @override
  String get laterTryNow => 'Später · direkt ausprobieren';

  @override
  String get toWhom => 'An wen?';
  @override
  String get edit => 'Bearbeiten';
  @override
  String get everyone => 'Alle';
  @override
  String get addNew => '+ Neu';
  @override
  String get saveAsGroup => 'Als Gruppe speichern';
  @override
  String groupOf(String names) => 'Gruppe aus $names';
  @override
  String get groupNameLabel => 'Name, z. B. WG';
  @override
  String get friendsEmpty =>
      'Speichere, wer welchen Dienst hört. Dann bekommt jeder den Link für seinen Player.';
  @override
  String get cancel => 'Abbrechen';
  @override
  String get save => 'Speichern';
  @override
  String get addFriend => 'Freund hinzufügen';
  @override
  String get name => 'Name';
  @override
  String get listensOn => 'Hört auf';
  @override
  String get myInvite => 'Meine Einladung';
  @override
  String get inviteQrLabel => 'QR-Code deiner Einladung';
  @override
  String get scanHint => 'Lass den Code mit der Kamera scannen.';
  @override
  String get done => 'Fertig';
  @override
  String get friends => 'Freunde';
  @override
  String get friendsIntro =>
      'Damit Songgate weiß, wohin deine Songs sollen. Alles bleibt auf diesem Handy.';
  @override
  String get shareMyInvite => 'Meine Einladung teilen';
  @override
  String shareInviteAs(String name, String service) =>
      'Einladung teilen ($name · $service)';
  @override
  String get showInviteQr => 'Einladung als QR-Code zeigen';
  @override
  String get addFriendManually => 'Freund von Hand hinzufügen';
  @override
  String get noFriends =>
      'Noch keine Freunde. Schick deine Einladung, wer sie öffnet, kann dich speichern und dir seine zurückschicken.';
  @override
  String get editFriend => 'Freund bearbeiten';
  @override
  String remove(String name) => '$name entfernen';
  @override
  String get groups => 'Gruppen';
  @override
  String get groupsHint =>
      'Gruppen legst du beim Teilen an: mehrere Freunde wählen, dann „Als Gruppe speichern“.';
  @override
  String get invite => 'Einladung';
  @override
  String get inviteIncomplete =>
      'Diese Einladung ist unvollständig. Bitte um einen neuen Link.';
  @override
  String friendListensOn(String name, String service) =>
      '$name hört auf $service';
  @override
  String saveFriendHint(String name, String service) =>
      'Speicher $name, dann landen deine Songs bei $name immer direkt in $service.';
  @override
  String saveName(String name) => '$name speichern';
  @override
  String get notNow => 'Nicht jetzt';
  @override
  String inviteText(String service, String url) =>
      'Ich höre auf $service. Speicher mich in Songgate, dann bekomme ich deine Songs immer passend:\n$url';
  @override
  String get allServices => 'Alle Dienste';
  @override
  String get others => 'Andere';
  @override
  String get sharedWith => 'Geteilt mit';

  @override
  String get reportBug => 'Fehler melden';
  @override
  String get feedbackThanks => 'Danke für dein Feedback!';
  @override
  String get feedbackThanksReply => 'Danke! Wir melden uns per Mail.';
  @override
  String get bugPlaceholder => 'Was ist passiert? Was hast du erwartet?';
  @override
  String get ideaPlaceholder =>
      'Was fehlt dir, was wünschst du dir, was gefällt dir?';
  @override
  String get removeScreenshot => 'Screenshot entfernen';
  @override
  String get markSpot => 'Stelle markieren';
  @override
  String get whatIsSent => 'Was mitgeschickt wird';
  @override
  String get contextPage => 'Seite';
  @override
  String get contextDevice => 'Gerät';
  @override
  String get contextViewport => 'Fenster';
  @override
  String get contextErrors => 'Letzte Fehler';
  @override
  String get emailLabel =>
      'Deine Mail, falls wir uns melden dürfen (freiwillig)';
  @override
  String get send => 'Senden';
  @override
  String get markHint => 'Zieh einen Rahmen um die Stelle, die nicht stimmt.';

  @override
  String get updateTitle => 'Update nötig';
  @override
  String updateBody(String app) =>
      'Diese Version von $app ist zu alt. Aktualisiere die App, um weiter Songs zu teilen.';
  @override
  String get updateNow => 'Jetzt aktualisieren';
}

class En extends Messages {
  const En();

  @override
  String get serviceUnavailable => 'The service can’t be reached right now.';
  @override
  String get searchTimeout =>
      'The search is taking too long. Please try again.';
  @override
  String get sendTimeout => 'Sending is taking too long. Please try again.';
  @override
  String get offline => 'No connection to the server. Please try again.';
  @override
  String get invalidAnswer => 'The service sent an invalid response.';

  @override
  String get preferencesFailed => 'Your settings couldn’t be loaded.';
  @override
  String get setupSaveFailed => 'The setup couldn’t be saved.';
  @override
  String get settingsTitle => 'Your settings';
  @override
  String get settings => 'Settings';
  @override
  String get openGuide => 'Open the favourites guide';
  @override
  String get friendsAndInvite => 'Friends and invite';
  @override
  String get giveFeedback => 'Give feedback';
  @override
  String get testMode => 'Test mode';
  @override
  String get testModeHint =>
      'Shows the bug button for reporting problems with a screenshot.';
  @override
  String get support => 'Support';
  @override
  String supportIntro(String app) =>
      '$app stays free. If you like it, support it with a one-off purchase. It unlocks nothing, it just helps keep $app going.';
  @override
  String get supportSong => 'A song';
  @override
  String get supportSingle => 'A single';
  @override
  String get supportAlbum => 'An album';
  @override
  String get supportThanks => 'Thank you for your support!';
  @override
  String get supportUnavailable =>
      'The store isn’t available right now. You can try again later.';
  @override
  String get supportFailed => 'The purchase didn’t go through.';
  @override
  String get otherLanguage => 'Deutsch';
  @override
  String get privacy => 'Privacy';
  @override
  String get imprint => 'Imprint';
  @override
  String get sharedLinkUnreadable => 'The shared link couldn’t be read.';
  @override
  String get clipboardEmpty => 'There’s no link on the clipboard.';
  @override
  String get messageCopied => 'Message copied.';
  @override
  String get copyFailed => 'The message couldn’t be copied.';
  @override
  String get shareFailed => 'Sharing isn’t possible. Copy the message instead.';
  @override
  String get backToInput => 'Back to the music link';
  @override
  String get headline => 'Share music. Everyone hears it on their own service.';
  @override
  String get intro =>
      'Paste a song or album link. Songgate finds it on Spotify, Apple Music, YouTube Music and Deezer.';
  @override
  String get linkHint => 'Song or album link';
  @override
  String get paste => 'Paste';
  @override
  String get find => 'Find';
  @override
  String get searching => 'Searching all four services …';
  @override
  String get linkFrom => 'Link from ';
  @override
  String get shareDirectTitle => 'Share directly next time';
  @override
  String get shareDirectBody =>
      'Move Songgate to the front of the share menu and skip the pasting.';
  @override
  String get shareDirectButton => 'How to set it up';
  @override
  String get shareAndroid =>
      'Straight from your music app: open the share menu on a song and pick Songgate.';
  @override
  String get privacyNote =>
      'No account. Friends and groups stay on your device. Your link goes to our service, the matches come from Apple, YouTube, Spotify, Deezer and ListenBrainz.';
  @override
  String kindFrom(bool album, String? service) =>
      '${album ? 'Album' : 'Song'}${service == null ? '' : ' from $service'}';
  @override
  String get otherLink => 'Paste another link';
  @override
  String get hintEveryone =>
      'One link for everyone. Each person picks their own service, ideal for group chats.';
  @override
  String hintOne(String service, bool withName) =>
      'Direct link for $service${withName ? ', plus the link for everyone with your name' : ''}.';
  @override
  String get hintSeveral =>
      'One line per service, and the link for everyone for all the others.';
  @override
  String get share => 'Share';
  @override
  String get copy => 'Copy';
  @override
  String get searchOnly => 'Search only';
  @override
  String get source => 'Source';
  @override
  String get found => 'Found';
  @override
  String get madeBy => 'a tool by';

  @override
  String get shareMenuFallback =>
      'Open the share menu on a song in your music app and follow this guide.';
  @override
  String get back => 'Back';
  @override
  String get setupKicker => 'A QUICK ONE-TIME SETUP';
  @override
  String get welcomeKicker => 'LESS SEARCHING. MORE MUSIC.';
  @override
  String get setupTitle => 'Your next song,\n';
  @override
  String get setupTitleAccent => 'right at hand.';
  @override
  String get welcomeTitle => 'Your song.\n';
  @override
  String get welcomeTitleAccent => 'Their favourite player.';
  @override
  String get setupIntro =>
      'Add Songgate to your favourites in the iPhone share menu.';
  @override
  String get welcomeIntro =>
      'Share music on the service your friends use. Straight from your music app.';
  @override
  List<(String, String, String)> get setupSteps => const [
    ('01', 'Open “More”', 'Swipe all the way right in the row of apps.'),
    (
      '02',
      '“Edit” → plus next to Songgate',
      'That adds Songgate to your favourites.',
    ),
    (
      '03',
      'Drag Songgate to the top',
      'Using the handle on the right. Then tap “Done”.',
    ),
  ];
  @override
  String get tryAgain => 'Try again';
  @override
  String get setUpWithExample => 'Set up with a sample song';
  @override
  String get continueToApp => 'Continue to the app';
  @override
  String get setUpLater => 'Set up later';
  @override
  String get guideReopen =>
      'You can reopen this guide any time. You manage your favourites yourself in the iOS menu.';
  @override
  String get orderNote => 'You set the order yourself in the iOS menu.';
  @override
  List<String> get welcomePoints => const [
    'Get going without signing up',
    'Stay in your music app',
    'Move Songgate to the front once',
  ];
  @override
  String get setUpShareMenu => 'Set up the share menu';
  @override
  String get laterTryNow => 'Later · try it right away';

  @override
  String get toWhom => 'Who’s it for?';
  @override
  String get edit => 'Edit';
  @override
  String get everyone => 'Everyone';
  @override
  String get addNew => '+ New';
  @override
  String get saveAsGroup => 'Save as group';
  @override
  String groupOf(String names) => 'Group of $names';
  @override
  String get groupNameLabel => 'Name, e.g. Flatmates';
  @override
  String get friendsEmpty =>
      'Save who listens on which service. Then everyone gets the link for their own player.';
  @override
  String get cancel => 'Cancel';
  @override
  String get save => 'Save';
  @override
  String get addFriend => 'Add friend';
  @override
  String get name => 'Name';
  @override
  String get listensOn => 'Listens on';
  @override
  String get myInvite => 'My invite';
  @override
  String get inviteQrLabel => 'QR code of your invite';
  @override
  String get scanHint => 'Let them scan the code with their camera.';
  @override
  String get done => 'Done';
  @override
  String get friends => 'Friends';
  @override
  String get friendsIntro =>
      'So Songgate knows where your songs should go. Everything stays on this phone.';
  @override
  String get shareMyInvite => 'Share my invite';
  @override
  String shareInviteAs(String name, String service) =>
      'Share invite ($name · $service)';
  @override
  String get showInviteQr => 'Show invite as QR code';
  @override
  String get addFriendManually => 'Add a friend by hand';
  @override
  String get noFriends =>
      'No friends yet. Send your invite: whoever opens it can save you and send theirs back.';
  @override
  String get editFriend => 'Edit friend';
  @override
  String remove(String name) => 'Remove $name';
  @override
  String get groups => 'Groups';
  @override
  String get groupsHint =>
      'You create groups while sharing: pick several friends, then “Save as group”.';
  @override
  String get invite => 'Invite';
  @override
  String get inviteIncomplete =>
      'This invite is incomplete. Ask for a new link.';
  @override
  String friendListensOn(String name, String service) =>
      '$name listens on $service';
  @override
  String saveFriendHint(String name, String service) =>
      'Save $name and your songs will always reach $name straight in $service.';
  @override
  String saveName(String name) => 'Save $name';
  @override
  String get notNow => 'Not now';
  @override
  String inviteText(String service, String url) =>
      'I listen on $service. Save me in Songgate and your songs will always reach me in the right place:\n$url';
  @override
  String get allServices => 'All services';
  @override
  String get others => 'Others';
  @override
  String get sharedWith => 'Shared with';

  @override
  String get reportBug => 'Report a bug';
  @override
  String get feedbackThanks => 'Thanks for your feedback!';
  @override
  String get feedbackThanksReply => 'Thanks! We’ll get back to you by email.';
  @override
  String get bugPlaceholder => 'What happened? What did you expect?';
  @override
  String get ideaPlaceholder =>
      'What’s missing, what would you like, what do you enjoy?';
  @override
  String get removeScreenshot => 'Remove screenshot';
  @override
  String get markSpot => 'Mark the spot';
  @override
  String get whatIsSent => 'What gets sent along';
  @override
  String get contextPage => 'Page';
  @override
  String get contextDevice => 'Device';
  @override
  String get contextViewport => 'Window';
  @override
  String get contextErrors => 'Recent errors';
  @override
  String get emailLabel => 'Your email, if we may get back to you (optional)';
  @override
  String get send => 'Send';
  @override
  String get markHint => 'Drag a frame around the spot that’s wrong.';

  @override
  String get updateTitle => 'Update needed';
  @override
  String updateBody(String app) =>
      'This version of $app is too old. Update the app to keep sharing songs.';
  @override
  String get updateNow => 'Update now';
}
