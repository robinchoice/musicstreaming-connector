import { isPodcast, platformSchema, type Conversion, type ConversionInput, type Platform, type PodcastApp, type Song } from '@app/shared';
import { z } from 'zod';
import { findAlbums, loadAlbum, youtubeAlbums, type YouTubeAlbums } from './albums';
import { findPodcasts, loadPodcast, podcastApps, youtubePodcasts, type AppleShow, type Podcast, type YouTubePodcasts } from './podcasts';
import { appleCatalog, appleUrl, codeFailure, https, providerCall, recording, session, pageMeta, youtube, type MusicLink, type Session } from './providers';
import { ResolutionError, searchUrl, spotifyCandidates, youtubeVideoId, YOUTUBE_HOSTS, type Fetch } from './resolver';
import { tidalCatalog, tidalPageMeta, tidalSearch, tidalTracks } from './tidal';

const appleTrack = z.object({
  wrapperType: z.literal('track'), kind: z.literal('song'), trackId: z.number(),
  trackName: z.string(), artistName: z.string(), trackViewUrl: z.string().url(),
  collectionName: z.string().optional(), trackTimeMillis: z.number().optional(),
  artworkUrl100: z.string().optional(), isStreamable: z.boolean().optional(),
});
const deezerTrack = z.object({
  id: z.number(), title: z.string(), duration: z.number().optional(), readable: z.boolean().optional(),
  isrc: z.string().optional(), artist: z.object({ name: z.string() }), album: z.object({ title: z.string().optional(), cover_medium: z.string().optional(), cover_xl: z.string().optional() }).optional(),
});
// The Apple Music API, unlike the iTunes API, knows each song's ISRC (needs the MusicKit key)
const appleSong = z.object({ id: z.string(), attributes: z.object({
  name: z.string(), url: z.string(), albumName: z.string().optional(), durationInMillis: z.number().optional(),
  isrc: z.string().optional(), artwork: z.object({ url: z.string() }).optional(), playParams: z.unknown().optional(),
}) });
const isrcCode = (value?: string) => value && /^[A-Z]{2}[A-Z0-9]{3}\d{7}$/.test(value) ? { isrc: value } : {};
type Track = { title: string; artist: string; url: string; durationSeconds?: number; artworkUrl: string | null; isrc?: string };
type YouTubeSong = { id: string; title: string; artists: string[]; album?: string; durationSeconds?: number; artworkUrl: string | null };
export type MusicSearch = (query: string, signal: AbortSignal) => Promise<YouTubeSong[]>;

// A song or an album: Apple albums without ?i=, Spotify, Deezer and TIDAL /album/, YouTube Music album playlists and pages.
// A podcast or an episode: Apple Podcasts, Spotify and Deezer /show/ and /episode/, YouTube Music podcast playlists and pages.
export function musicSource(input: string): MusicLink {
  const links = new Map<string, MusicLink>();
  for (const link of input.match(/https?:\/\/[^\s<>]+/gi) ?? []) {
    let url: URL;
    try { url = new URL(link.replace(/[.,!)\]]+$/, '')); } catch { throw new ResolutionError('INVALID_LINK'); }
    if (url.hostname === 'music.apple.com') {
      const parts = url.pathname.split('/').filter(Boolean);
      const song = parts[1] === 'album' ? url.searchParams.get('i') : parts[1] === 'song' ? parts.at(-1) : null;
      const album = parts[1] === 'album' && !url.searchParams.has('i') ? parts.at(-1) : null;
      const id = song ?? album;
      if (url.username || url.password || !/^[a-z]{2}$/i.test(parts[0] ?? '') || !id || !/^\d{1,12}$/.test(id)) throw new ResolutionError('INVALID_LINK');
      links.set(`apple:${id}`, { kind: song ? 'song' : 'album', platform: 'appleMusic', id, country: parts[0]!.toUpperCase() });
    } else if (['podcasts.apple.com', 'itunes.apple.com'].includes(url.hostname)) {
      // podcasts.apple.com/de/podcast/the-daily/id1200361736, an episode adds ?i=1000799791974; the storefront may be missing
      const parts = url.pathname.split('/').filter(Boolean);
      const country = /^[a-z]{2}$/i.test(parts[0] ?? '') ? parts.shift()!.toUpperCase() : 'US';
      const show = parts.at(-1)?.match(/^id(\d{1,12})$/)?.[1];
      const episode = url.searchParams.get('i');
      if (url.username || url.password || parts[0] !== 'podcast' || !show || (episode !== null && !/^\d{1,15}$/.test(episode))) throw new ResolutionError('INVALID_LINK');
      links.set(`apple:${episode ?? show}`, episode ? { kind: 'episode', platform: 'appleMusic', id: episode, country, show } : { kind: 'podcast', platform: 'appleMusic', id: show, country });
    } else if (YOUTUBE_HOSTS.includes(url.hostname)) {
      if (url.username || url.password) throw new ResolutionError('INVALID_LINK');
      const album = url.pathname === '/playlist' ? url.searchParams.get('list') : url.pathname.startsWith('/browse/') ? url.pathname.slice(8) : null;
      if (album === null) {
        // A video may still turn out to be a podcast episode, see lookup
        const id = youtubeVideoId(url);
        links.set(`youtube:${id}`, { kind: 'song', platform: 'youtubeMusic', id, country: '' });
      } else if (/^(?:MPSP)?PL[A-Za-z0-9_-]{10,60}$/.test(album)) {
        // Podcasts are playlists; whether this one is a podcast, only YouTube Music knows
        const id = album.replace(/^MPSP/, '');
        links.set(`youtube:${id}`, { kind: 'podcast', platform: 'youtubeMusic', id, country: '' });
      } else {
        if (!/^(?:OLAK5uy_|MPREb_)[A-Za-z0-9_-]{8,40}$/.test(album)) throw new ResolutionError('INVALID_LINK');
        links.set(`youtube:${album}`, { kind: 'album', platform: 'youtubeMusic', id: album, country: '' });
      }
    } else if (url.hostname === 'open.spotify.com' || ['www.deezer.com', 'deezer.com'].includes(url.hostname)) {
      const spotify = url.hostname === 'open.spotify.com';
      const parts = url.pathname.split('/').filter(Boolean);
      const kind = ({ track: 'song', album: 'album', show: 'podcast', episode: 'episode' } as const)[parts.at(-2) ?? ''] ?? null;
      const id = kind ? parts.at(-1) : null;
      if (url.username || url.password || !kind || !id || !(spotify ? /^[A-Za-z0-9]{22}$/ : /^\d{1,12}$/).test(id)) throw new ResolutionError('INVALID_LINK');
      links.set(`${spotify ? 'spotify' : 'deezer'}:${kind}:${id}`, { kind, platform: spotify ? 'spotify' : 'deezer', id, country: '' });
    } else if (['tidal.com', 'www.tidal.com', 'listen.tidal.com'].includes(url.hostname)) {
      // tidal.com/track/1, tidal.com/browse/album/2, listen.tidal.com/album/2/track/1, share links end in /u
      const parts = url.pathname.split('/').filter(Boolean);
      const track = parts.lastIndexOf('track');
      const at = track >= 0 ? track : parts.lastIndexOf('album');
      const kind = parts[at] === 'track' ? 'song' : 'album';
      const id = at >= 0 ? parts[at + 1] : undefined;
      if (url.username || url.password || !id || !/^\d{1,12}$/.test(id)) throw new ResolutionError('INVALID_LINK');
      links.set(`tidal:${kind}:${id}`, { kind, platform: 'tidal', id, country: '' });
    }
  }
  if (links.size > 1) throw new ResolutionError('INVALID_LINK');
  if (!links.size) throw new ResolutionError(input.match(/https?:\/\//i) ? 'UNSUPPORTED_LINK' : 'INVALID_LINK');
  return [...links.values()][0]!;
}

export const searchYouTube: MusicSearch = async (query, signal) => {
  const results = await (await youtube(signal)).music.search(query, { type: 'song' });
  return (results.songs?.contents ?? []).flatMap(item =>
    item.id && item.title && item.artists ? [{
      id: item.id, title: item.title, artists: item.artists.map(artist => artist.name),
      ...(item.album ? { album: item.album.name } : {}), ...(item.duration ? { durationSeconds: item.duration.seconds } : {}),
      artworkUrl: item.thumbnails?.[0]?.url ?? null,
    }] : []);
};

// Share links carry only the source song or album, so the share page needs no storage
export function sharePath(source: MusicLink) {
  const apple = source.show ? `${source.show}/${source.id}` : source.id;
  const path = { youtubeMusic: `/yt/${source.id}`, appleMusic: `/am/${source.country.toLowerCase()}/${apple}`, spotify: `/sp/${source.id}`, deezer: `/dz/${source.id}`, tidal: `/td/${source.id}` }[source.platform];
  return source.kind === 'song' ? `/s${path}` : `/s/${source.kind}${path}`;
}

// spotify.link is a Branch short link for spotify.app.link, whose page names the track or album it opens
async function expandShortLink(input: string, { request, signal }: Session) {
  const short = input.match(/https?:\/\/spotify\.link\/([A-Za-z0-9]{6,20})(?![A-Za-z0-9])/);
  if (!short) return input;
  const page = await providerCall('spotify', signal, async () => (await request(`https://spotify.app.link/${short[1]}`, {})).text());
  const target = page.match(/https:\/\/open\.spotify\.com\/(?:intl-[a-z-]+\/)?(?:track|album|show|episode)\/[A-Za-z0-9]{22}/)?.[0];
  if (!target) throw new ResolutionError('INVALID_LINK');
  return input.replace(short[0], target);
}

function appleCandidate(link: string, title: string, album: string | undefined, millis: number | undefined, artworkUrl: string | null) {
  const url = appleUrl(link, true);
  return url ? [{ title, url, ...(album === undefined ? {} : { album }), ...(millis ? { durationSeconds: Math.round(millis / 1000) } : {}), artworkUrl }] : [];
}
const tidalCandidate = (track: ReturnType<typeof tidalTracks>[number]) => ({ title: track.title, url: track.url, ...(track.album === undefined ? {} : { album: track.album }), ...(track.durationSeconds === undefined ? {} : { durationSeconds: track.durationSeconds }), artworkUrl: null });
const deezerCandidate = (track: z.infer<typeof deezerTrack>) => ({ title: track.title, url: `https://www.deezer.com/track/${track.id}`, ...(track.album?.title === undefined ? {} : { album: track.album.title }), ...(track.duration === undefined ? {} : { durationSeconds: track.duration }), artworkUrl: https(track.album?.cover_medium) });

// The ISRC names the recording, so a hit needs no text comparison
async function isrcCandidates(target: Platform, isrc: string, country: string, current: Session): Promise<Conversion['candidates']> {
  try {
    if (target === 'appleMusic') {
      // The oldest song ID is usually the original album, compilations come later
      return (await appleCatalog(`${country.toLowerCase()}/songs`, { 'filter[isrc]': isrc }, appleSong, current))
        .filter(song => song.attributes.playParams !== undefined).toSorted((a, b) => Number(a.id) - Number(b.id))
        .flatMap(({ attributes: song }) => appleCandidate(song.url, song.name, song.albumName, song.durationInMillis, https(song.artwork?.url.replace('{w}x{h}', '100x100'))));
    }
    if (target === 'deezer') {
      // Deezer answers an unknown ISRC with an error object, which does not parse as a track
      const track = deezerTrack.safeParse(await current.get(`https://api.deezer.com/track/isrc:${isrc}`, {}));
      return track.success && track.data.readable !== false ? [deezerCandidate(track.data)] : [];
    }
    if (target === 'tidal') {
      const found = await tidalCatalog('tracks', [['filter[isrc]', isrc], ['countryCode', country], ['include', 'albums']], current);
      return found ? tidalTracks(found).map(tidalCandidate) : [];
    }
  } catch {
    codeFailure('ISRC', target, current.signal);
  }
  return [];
}

const appleTracks = (body: unknown) => z.object({ results: z.array(z.unknown()) }).parse(body).results.flatMap(item => {
  const parsed = appleTrack.safeParse(item);
  return parsed.success ? [parsed.data] : [];
});

function loadSource(parsed: MusicLink, current: Session): Promise<Track> {
  const { get, signal } = current;
  return providerCall(parsed.platform, signal, async () => {
    let source: Track;
    if (parsed.platform === 'youtubeMusic') {
      const metadata = z.object({ title: z.string().min(1), author_name: z.string().min(1), thumbnail_url: z.string().optional() }).parse(await get('https://www.youtube.com/oembed', { url: `https://www.youtube.com/watch?v=${parsed.id}`, format: 'json' }));
      source = { title: metadata.title, artist: metadata.author_name.replace(/ - Topic$/, ''), url: `https://music.youtube.com/watch?v=${parsed.id}`, artworkUrl: https(metadata.thumbnail_url) };
    } else if (parsed.platform === 'appleMusic') {
      const [body, isrc] = await Promise.all([
        get('https://itunes.apple.com/lookup', { id: parsed.id, country: parsed.country, entity: 'song' }),
        appleCatalog(`${parsed.country.toLowerCase()}/songs/${parsed.id}`, {}, appleSong, current).then(songs => songs[0]?.attributes.isrc, () => { codeFailure('ISRC', 'appleMusic', signal); return undefined; }),
      ]);
      const track = appleTracks(body).find(track => String(track.trackId) === parsed.id);
      if (!track) throw new ResolutionError('SOURCE_UNAVAILABLE');
      source = { ...isrcCode(isrc), title: track.trackName, artist: track.artistName, url: `https://music.apple.com/${parsed.country.toLowerCase()}/song/${parsed.id}`, ...(track.trackTimeMillis ? { durationSeconds: track.trackTimeMillis / 1000 } : {}), artworkUrl: https(track.artworkUrl100?.replace('/100x100bb.', '/600x600bb.')) };
    } else if (parsed.platform === 'spotify') {
      const html = await current.spotifyPage(`track/${parsed.id}`);
      const duration = Number(pageMeta(html, 'music:duration'));
      source = { title: pageMeta(html, 'og:title') ?? '', artist: pageMeta(html, 'music:musician_description') ?? '', url: `https://open.spotify.com/track/${parsed.id}`, ...(duration > 0 ? { durationSeconds: duration } : {}), artworkUrl: https(pageMeta(html, 'og:image')) };
    } else if (parsed.platform === 'tidal') {
      // The page names the song without a key, the API adds its ISRC and duration
      const [html, found] = await Promise.all([
        current.tidalPage(`track/${parsed.id}`),
        tidalCatalog(`tracks/${parsed.id}`, [['countryCode', 'DE']], current).then(doc => doc && tidalTracks(doc)[0], () => { codeFailure('ISRC', 'tidal', signal); return undefined; }),
      ]);
      const meta = tidalPageMeta(pageMeta(html, 'og:title'), pageMeta(html, 'og:description'));
      if (!meta) throw new ResolutionError('SOURCE_UNAVAILABLE');
      source = { ...isrcCode(found?.isrc), ...meta, url: `https://tidal.com/track/${parsed.id}`, ...(found?.durationSeconds ? { durationSeconds: found.durationSeconds } : {}), artworkUrl: https(pageMeta(html, 'og:image')) };
    } else {
      // Deezer reports unknown tracks as an error object with status 200
      const body = await get(`https://api.deezer.com/track/${parsed.id}`, {});
      if (z.object({ error: z.unknown() }).safeParse(body).data?.error) throw new ResolutionError('SOURCE_UNAVAILABLE');
      const track = deezerTrack.parse(body);
      source = { ...isrcCode(track.isrc), title: track.title, artist: track.artist.name, url: `https://www.deezer.com/track/${track.id}`, ...(track.duration === undefined ? {} : { durationSeconds: track.duration }), artworkUrl: https(track.album?.cover_xl) };
    }
    source.title = source.title.trim();
    source.artist = source.artist.trim();
    if (!source.title || !source.artist) throw new ResolutionError('SOURCE_UNAVAILABLE');
    return source;
  });
}

function findCandidates(target: Platform, source: Track, country: string, current: Session, search: MusicSearch): Promise<Conversion['candidates']> {
  const { get, signal } = current;
  return providerCall(target, signal, async () => {
    const exact = source.isrc ? await isrcCandidates(target, source.isrc, country, current) : [];
    if (exact.length) return exact.slice(0, 8);
    const original = recording(source.title, [source.artist]);
    const matches = (title: string, artists: string[], duration?: number) => {
      const candidate = recording(title, artists);
      return candidate.title === original.title && candidate.artists === original.artists &&
        (source.durationSeconds === undefined || duration === undefined || Math.abs(source.durationSeconds - duration) <= 5);
    };
    const query = `${source.artist} ${source.title.replace(/[\[(]feat(?:uring)?\.?\s+[^\])]+[\])]/gi, '').trim()}`;
    let candidates: Conversion['candidates'];
    if (target === 'appleMusic') {
      candidates = appleTracks(await get('https://itunes.apple.com/search', { term: `${source.artist} ${original.title}`, entity: 'song', country, limit: '25' }))
        .filter(track => track.isStreamable === true && matches(track.trackName, [track.artistName], track.trackTimeMillis ? track.trackTimeMillis / 1000 : undefined))
        .flatMap(track => appleCandidate(track.trackViewUrl, track.trackName, track.collectionName, track.trackTimeMillis, https(track.artworkUrl100)));
    } else if (target === 'youtubeMusic') {
      candidates = (await search(query, signal))
        .filter(track => /^[A-Za-z0-9_-]{11}$/.test(track.id) && matches(track.title, track.artists, track.durationSeconds))
        .map(track => ({ title: track.title, url: `https://music.youtube.com/watch?v=${track.id}`, ...(track.album === undefined ? {} : { album: track.album }), ...(track.durationSeconds === undefined ? {} : { durationSeconds: track.durationSeconds }), artworkUrl: https(track.artworkUrl) }));
    } else if (target === 'deezer') {
      candidates = z.object({ data: z.array(z.unknown()) }).parse(await get('https://api.deezer.com/search', { q: query, limit: '25' })).data.flatMap(item => {
        const track = deezerTrack.safeParse(item);
        return !track.success || track.data.readable === false || !matches(track.data.title, [track.data.artist.name], track.data.duration) ? [] : [deezerCandidate(track.data)];
      });
    } else if (target === 'tidal') {
      const found = await tidalSearch('tracks', query, country, current);
      candidates = found ? tidalTracks(found).filter(track => matches(track.title, track.artists, track.durationSeconds)).map(tidalCandidate) : [];
    } else if (target === 'spotify') {
      candidates = await spotifyCandidates(source, get);
    } else {
      candidates = [];
    }
    return [...new Map(candidates.map(candidate => [candidate.url, candidate])).values()].slice(0, 8);
  });
}

type Lookup = {
  link: MusicLink;
  source: { title: string; artist: string; url: string; artworkUrl: string | null };
  find: (target: Platform, country: string) => Promise<Conversion['candidates']>;
  apps?: () => PodcastApp[];
};
type YouTube = { search: MusicSearch; albums: YouTubeAlbums; podcasts: YouTubePodcasts };

function podcastLookup(link: MusicLink, source: Podcast, current: Session, podcasts: YouTubePodcasts): Lookup {
  const kind = link.kind === 'podcast' ? 'podcast' : 'episode';
  // An Apple source names its show; otherwise the Apple match fills this in for the other podcast apps
  const found: AppleShow = { ...(source.appleId ? { appleId: source.appleId } : {}), ...(source.feedUrl ? { feedUrl: source.feedUrl } : {}) };
  return { link, source, find: (target, country) => findPodcasts(kind, target, source, country, current, podcasts, found), apps: () => podcastApps(found.appleId, found.feedUrl) };
}

// Source and matcher of a song, an album, a show or an episode, so resolve and resolveAll treat them alike
async function lookup(parsed: MusicLink, current: Session, { search, albums, podcasts }: YouTube): Promise<Lookup> {
  if (isPodcast(parsed.kind)) return podcastLookup(parsed, await loadPodcast(parsed, current, podcasts), current, podcasts);
  if (parsed.kind === 'album') {
    const source = await loadAlbum(parsed, current, albums);
    return { link: parsed, source, find: (target, country) => findAlbums(target, source, country, current, albums) };
  }
  const song = loadSource(parsed, current);
  if (parsed.platform === 'youtubeMusic') {
    // A YouTube video may be a podcast episode, which only YouTube Music's player tells. A failed check leaves a song.
    song.catch(() => {});
    const episode = await providerCall('youtubeMusic', current.signal, () => podcasts.episode(parsed.id, current.signal)).catch(() => null);
    if (episode) return podcastLookup({ ...parsed, kind: 'episode' }, episode, current, podcasts);
  }
  const source = await song;
  return { link: parsed, source, find: (target, country) => findCandidates(target, source, country, current, search) };
}

async function withSession<T>(input: string, requestSignal: AbortSignal | undefined, fetcher: Fetch, run: (parsed: MusicLink, current: Session) => Promise<T>): Promise<T> {
  const current = session(requestSignal, fetcher);
  try {
    return await run(musicSource(await expandShortLink(input, current)), current);
  } catch (error) {
    if (error instanceof ResolutionError) throw error;
    throw new ResolutionError('NETWORK');
  } finally { current.controller.abort(); }
}

export async function resolve(input: ConversionInput, requestSignal?: AbortSignal, fetcher: Fetch = fetch, search: MusicSearch = searchYouTube, albums: YouTubeAlbums = youtubeAlbums, podcasts: YouTubePodcasts = youtubePodcasts): Promise<Conversion> {
  return withSession(input.input, requestSignal, fetcher, async (parsed, current) => {
    if (parsed.platform === input.target) throw new ResolutionError('UNSUPPORTED_LINK');
    const { link, source, find } = await lookup(parsed, current, { search, albums, podcasts });
    const candidates = await find(input.target, input.country);
    if (!candidates.length) throw new ResolutionError('NO_MATCH', searchUrl(input.target, source, input.country, link.kind));
    return { source: { kind: link.kind, title: source.title, artist: source.artist, url: source.url }, target: input.target, candidates, sharePath: sharePath(link) };
  });
}

// The best match on every service at once, for the share page and for friends. A service
// that finds nothing or fails gets a search link, so one slow service never blocks the rest.
export async function resolveAll(input: { input: string; country: string }, requestSignal?: AbortSignal, fetcher: Fetch = fetch, search: MusicSearch = searchYouTube, albums: YouTubeAlbums = youtubeAlbums, podcasts: YouTubePodcasts = youtubePodcasts): Promise<Song> {
  return withSession(input.input, requestSignal, fetcher, async (parsed, current) => {
    const { link, source, find, apps } = await lookup(parsed, current, { search, albums, podcasts });
    const targets = platformSchema.options;
    const bests = await Promise.all(targets.map(target => target === parsed.platform ? undefined
      : find(target, input.country).then(candidates => candidates[0], () => undefined)));
    const links = Object.fromEntries(targets.map((target, i) => [target, target === parsed.platform ? { url: source.url, found: true }
      : bests[i] ? { url: bests[i].url, found: true } : { url: searchUrl(target, source, input.country, link.kind), found: false }])) as Song['links'];
    // YouTube thumbnails of songs and episodes are letterboxed video frames, a square cover from another service looks better
    const artworkUrl = link.platform === 'youtubeMusic' && (link.kind === 'song' || link.kind === 'episode') ? bests.find(best => best?.artworkUrl)?.artworkUrl?.replace('/100x100bb.', '/600x600bb.') ?? source.artworkUrl : source.artworkUrl;
    return { source: { kind: link.kind, platform: link.platform, title: source.title, artist: source.artist, url: source.url, artworkUrl }, sharePath: sharePath(link), links, ...(apps ? { apps: apps() } : {}) };
  });
}
