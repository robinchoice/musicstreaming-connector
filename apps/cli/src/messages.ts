// Texts of the CLI in German and English. Web and API speak German only, so
// they live here and not in @app/shared (AGENTS.md, „Abweichungen vom Standard“).
const de = {
  cliIntro: (app: string) => `${app} auf der Befehlszeile`,
  cliUsage: (cmd: string) => `Aufruf: ${cmd} <Befehl> [Optionen]`,
  cliCommands: 'Befehle',
  cliOptions: 'Optionen',
  cliJsonHelp: 'Ausgabe als JSON, für Agenten und Skripte',
  cliUrlHelp: (url: string) => `Adresse der App, Standard ${url}`,
  cliLangHelp: 'Sprache, sonst aus LANG',
  cliHelpHelp: 'Diese Hilfe',
  cliExitCodes: 'Exit-Codes: 0 erledigt, 1 Fehler, 2 falscher Aufruf',
  cliConvertHelp: 'Links zum Song in allen Diensten, „-“ liest den Link von stdin',
  cliConvertToHelp: 'Treffer in einem Dienst',
  cliCountryHelp: 'Land des Katalogs, Standard DE',
  cliSearchOnly: 'nur Suche',
  cliForEveryone: 'Für alle',
  cliMissingLink: (cmd: string) => `Welcher Link? Aufruf: ${cmd} convert <link>`,
  cliUnknownCommand: (name: string, cmd: string) => `Unbekannter Befehl „${name}“. Alle Befehle: ${cmd} --help`,
  cliBadOptions: (detail: string, cmd: string) => `Falscher Aufruf: ${detail}. Hilfe: ${cmd} --help`,
  cliUnreachable: (url: string) => `${url} ist nicht erreichbar.`,
  cliBadAnswer: 'Unerwartete Antwort der API.',
};

export type Messages = typeof de;

const en: Messages = {
  cliIntro: (app) => `${app} on the command line`,
  cliUsage: (cmd) => `Usage: ${cmd} <command> [options]`,
  cliCommands: 'Commands',
  cliOptions: 'Options',
  cliJsonHelp: 'Output as JSON, for agents and scripts',
  cliUrlHelp: (url) => `Address of the app, default ${url}`,
  cliLangHelp: 'Language, else from LANG',
  cliHelpHelp: 'This help',
  cliExitCodes: 'Exit codes: 0 done, 1 error, 2 wrong usage',
  cliConvertHelp: 'Links to the song on every service, "-" reads the link from stdin',
  cliConvertToHelp: 'Matches on one service',
  cliCountryHelp: 'Country of the catalogue, default DE',
  cliSearchOnly: 'search only',
  cliForEveryone: 'For everyone',
  cliMissingLink: (cmd) => `Which link? Usage: ${cmd} convert <link>`,
  cliUnknownCommand: (name, cmd) => `Unknown command "${name}". All commands: ${cmd} --help`,
  cliBadOptions: (detail, cmd) => `Wrong usage: ${detail}. Help: ${cmd} --help`,
  cliUnreachable: (url) => `${url} cannot be reached.`,
  cliBadAnswer: 'Unexpected answer from the API.',
};

export const messages = { de, en };
export type Locale = keyof typeof messages;

// The first language of a tag like de_DE.UTF-8 or en, German otherwise
export const pickLocale = (value: string | undefined): Locale => (value?.slice(0, 2).toLowerCase() === 'en' ? 'en' : 'de');
