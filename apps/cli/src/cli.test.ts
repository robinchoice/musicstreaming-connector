import { afterAll, beforeAll, expect, test } from 'bun:test';
import { type Conversion, type ConversionInput, messages, type Song } from '@app/shared';
import { createApp } from '../../api/src/app';
import { ResolutionError } from '../../api/src/lib/resolver';
import { run } from './cli';
import { EXIT } from './command';

const song: Song = {
  source: { kind: 'song', platform: 'youtubeMusic', title: 'Savior', artist: 'Red Hot Chili Peppers', url: 'https://music.youtube.com/watch?v=UijW9hGpnzc', artworkUrl: null },
  sharePath: '/s/yt/UijW9hGpnzc',
  links: {
    youtubeMusic: { url: 'https://music.youtube.com/watch?v=UijW9hGpnzc', found: true },
    appleMusic: { url: 'https://music.apple.com/de/album/savior/945575406?i=945575419', found: true },
    spotify: { url: 'https://open.spotify.com/search/Savior', found: false },
    deezer: { url: 'https://www.deezer.com/track/725299', found: true },
  },
};
const album: Song = {
  source: { kind: 'album', platform: 'deezer', title: 'Random Access Memories', artist: 'Daft Punk', url: 'https://www.deezer.com/album/6575789', artworkUrl: null },
  sharePath: '/s/album/dz/6575789',
  links: {
    youtubeMusic: { url: 'https://music.youtube.com/browse/MPREb_K8qWMWVqXGi', found: true },
    appleMusic: { url: 'https://music.apple.com/de/album/617154241', found: true },
    spotify: { url: 'https://open.spotify.com/album/4m2880jivSbbyEGAKfITCa', found: true },
    deezer: { url: 'https://www.deezer.com/album/6575789', found: true },
  },
};
const conversion: Conversion = {
  target: 'spotify',
  source: { kind: 'song', title: 'Savior', artist: 'Red Hot Chili Peppers', url: song.source.url },
  sharePath: song.sharePath,
  candidates: [{ title: 'Savior', url: 'https://open.spotify.com/track/0O8RjwNco465s5o9Ix9IYj', artworkUrl: null, album: 'Californication' }],
};

// The CLI runs in-process against the real API on a free port, the music services are faked
const converted: ConversionInput[] = [];
const looked: { input: string; country: string }[] = [];
let server: ReturnType<typeof Bun.serve>;
let url = '';

beforeAll(() => {
  const app = createApp(
    async (input) => {
      converted.push(input);
      if (input.input.includes('unknown')) throw new ResolutionError('NO_MATCH', 'https://open.spotify.com/search/unknown');
      return conversion;
    },
    undefined,
    async (input) => {
      looked.push(input);
      return input.input.includes('/album/') ? album : song;
    },
  );
  server = Bun.serve({ port: 0, fetch: app.fetch });
  url = server.url.origin;
});
afterAll(() => server.stop(true));

const de = messages.de;

// Adds --url of the test API unless the call names one
async function cli(args: string[], { stdin = '', env = { LANG: 'de_DE.UTF-8' } } = {}) {
  const out: string[] = [];
  const err: string[] = [];
  const code = await run(args.length === 0 || args.includes('--url') ? args : [...args, '--url', url], {
    env,
    out: (text) => out.push(text),
    err: (text) => err.push(text),
    stdin: async () => stdin,
  });
  return { code, out: out.join('\n'), err: err.join('\n'), json: () => JSON.parse(out.join('\n')) };
}

test('convert shows the links on every service, as text and as JSON', async () => {
  const text = await cli(['convert', 'https://youtu.be/UijW9hGpnzc', '--country', 'at']);
  expect(text.code).toBe(EXIT.ok);
  expect(looked.at(-1)).toEqual({ input: 'https://youtu.be/UijW9hGpnzc', country: 'AT' });
  expect(text.out).toContain('Savior – Red Hot Chili Peppers');
  expect(text.out).toContain(`https://open.spotify.com/search/Savior  (${de.cliSearchOnly})`);
  expect(text.out).toContain(`${de.cliForEveryone}: ${url}/s/yt/UijW9hGpnzc`);

  const json = await cli(['convert', 'https://youtu.be/UijW9hGpnzc', '--json']);
  expect(json.code).toBe(EXIT.ok);
  expect(json.json()).toEqual({ ...song, shareUrl: `${url}/s/yt/UijW9hGpnzc` });
});

test('convert takes albums like songs', async () => {
  const json = await cli(['convert', 'https://www.deezer.com/de/album/6575789', '--json']);
  expect(json.code).toBe(EXIT.ok);
  expect(json.json()).toEqual({ ...album, shareUrl: `${url}/s/album/dz/6575789` });
  const text = await cli(['convert', 'https://www.deezer.com/de/album/6575789']);
  expect(text.out).toContain('Random Access Memories – Daft Punk');
  expect(text.out).toContain('https://open.spotify.com/album/4m2880jivSbbyEGAKfITCa');
});

test('convert --to asks the converter and reads the link from stdin', async () => {
  const result = await cli(['convert', '-', '--to', 'spotify', '--json'], { stdin: ' Hör mal: https://youtu.be/UijW9hGpnzc \n' });
  expect(result.code).toBe(EXIT.ok);
  expect(converted.at(-1)).toEqual({ input: 'Hör mal: https://youtu.be/UijW9hGpnzc', target: 'spotify', country: 'DE' });
  expect(result.json()).toMatchObject({ target: 'spotify', candidates: [{ url: conversion.candidates[0]!.url }], shareUrl: `${url}/s/yt/UijW9hGpnzc` });

  const text = await cli(['convert', 'https://youtu.be/UijW9hGpnzc', '--to', 'spotify']);
  expect(text.out).toContain('→ Spotify');
  expect(text.out).toContain(`Savior · Californication  ${conversion.candidates[0]!.url}`);
});

test('errors of the API end with exit 1, in JSON as { error }', async () => {
  const result = await cli(['convert', 'https://youtu.be/unknown', '--to', 'spotify', '--json']);
  expect(result.code).toBe(EXIT.error);
  expect(result.json()).toEqual({ error: expect.stringContaining('https://open.spotify.com/search/unknown') });

  const unreachable = await cli(['convert', 'song', '--url', 'http://127.0.0.1:1']);
  expect(unreachable.code).toBe(EXIT.error);
  expect(unreachable.err).toBe(de.cliUnreachable('http://127.0.0.1:1'));
});

test('wrong usage ends with exit 2 before asking the API', async () => {
  const before = converted.length + looked.length;
  for (const args of [['convert'], ['convert', '-'], ['convert', 'song', '--to', 'tidal'], ['convert', 'song', '--country', 'FR'], ['convert', 'a', 'b'], ['play'], ['--nope']]) {
    expect((await cli(args)).code).toBe(EXIT.usage);
  }
  expect(converted.length + looked.length).toBe(before);
  expect((await cli(['play', '--json'])).json()).toEqual({ error: de.cliUnknownCommand('play', 'songgate') });
});

test('help lists the commands in the language of LANG or --lang', async () => {
  const german = await cli([]);
  expect(german.code).toBe(EXIT.ok);
  expect(german.out).toContain(de.cliConvertHelp);
  const english = await cli(['--help'], { env: { LANG: 'en_US.UTF-8' } });
  expect(english.out).toContain(messages.en.cliConvertHelp);
  const json = await cli(['--help', '--json', '--lang', 'en']);
  expect(json.json()).toMatchObject({ commands: expect.arrayContaining([{ usage: 'convert <link>|-', text: messages.en.cliConvertHelp }]), exitCodes: EXIT });
});
