import type { Conversion, Platform, PodcastApp } from '@app/shared';
import { YTNodes } from 'youtubei.js';
import { z } from 'zod';
import { https, normalize, pageMeta, providerCall, youtube, type MusicLink, type Session } from './providers';
import { ResolutionError } from './resolver';
import { spotifyApi } from './spotify';

// Shows and episodes. There is no ISRC for podcasts: a show is found by its name, an episode by
// its show, its title and, where both services know it, its release date.

type Candidates = Conversion['candidates'];
// title and artist as the share page shows them: show and publisher, or episode and show
export type Podcast = {
  title: string; artist: string; show: string; url: string; artworkUrl: string | null;
  released?: number; durationSeconds?: number; appleId?: string; feedUrl?: string;
};
type YouTubeShow = { id: string; title: string; publisher: string; artworkUrl: string | null };
type YouTubeEpisode = { id: string; title: string; show: string; artworkUrl: string | null };
export type YouTubePodcasts = {
  // null for a video that is no podcast episode, which makes it a song
  episode: (videoId: string, signal: AbortSignal) => Promise<Podcast | null>;
  show: (playlistId: string, signal: AbortSignal) => Promise<Podcast>;
  shows: (query: string, signal: AbortSignal) => Promise<YouTubeShow[]>;
  episodes: (query: string, signal: AbortSignal) => Promise<YouTubeEpisode[]>;
};

const runs = z.object({ runs: z.array(z.object({ text: z.string() })) });
// The video in YouTube Music's queue, which names its type, show and length
const queueItem = z.object({
  title: runs, shortBylineText: runs, lengthText: runs.optional(),
  thumbnail: z.object({ thumbnails: z.array(z.object({ url: z.string() })) }).optional(),
  navigationEndpoint: z.object({ watchEndpoint: z.object({ watchEndpointMusicSupportedConfigs: z.object({
    watchEndpointMusicConfig: z.object({ musicVideoType: z.string().optional() }),
  }) }) }),
});
function queueVideo(node: unknown, videoId: string): unknown {
  if (!node || typeof node !== 'object') return undefined;
  const item: unknown = 'playlistPanelVideoRenderer' in node ? node.playlistPanelVideoRenderer : undefined;
  if (item && typeof item === 'object' && 'videoId' in item && item.videoId === videoId) return item;
  for (const value of Object.values(node)) {
    const found = queueVideo(value, videoId);
    if (found) return found;
  }
  return undefined;
}
// "1:02:03"
const clock = (text?: string) => text && /^\d+(?::\d{1,2}){1,2}$/.test(text) ? text.split(':').reduce((total, part) => total * 60 + Number(part), 0) : undefined;
const showResponse = z.object({ microformat: z.object({ microformatDataRenderer: z.object({
  title: z.string(), description: z.string().default(''), urlCanonical: z.string().optional(),
  thumbnail: z.object({ thumbnails: z.array(z.object({ url: z.string() })) }).optional(),
}) }) });
const flex = (item: { flex_columns: { title: { toString(): string } }[] }, column: number) => item.flex_columns[column]?.title.toString() ?? '';

export const youtubePodcasts: YouTubePodcasts = {
  // The queue (/next), not the player: YouTube gives server addresses the player without video details
  async episode(videoId, signal) {
    const client = await youtube(signal);
    const video = queueItem.safeParse(queueVideo((await client.actions.execute('/next', { videoId, client: 'YTMUSIC' })).data, videoId)).data;
    if (video?.navigationEndpoint.watchEndpoint.watchEndpointMusicSupportedConfigs.watchEndpointMusicConfig.musicVideoType !== 'MUSIC_VIDEO_TYPE_PODCAST_EPISODE') return null;
    const show = video.shortBylineText.runs.map(run => run.text).join('');
    const duration = clock(video.lengthText?.runs[0]?.text);
    return {
      title: video.title.runs.map(run => run.text).join(''), artist: show, show, url: `https://music.youtube.com/watch?v=${videoId}`,
      artworkUrl: https(video.thumbnail?.thumbnails.at(-1)?.url), ...(duration ? { durationSeconds: duration } : {}),
    };
  },
  async show(playlistId, signal) {
    const client = await youtube(signal);
    // YouTube answers a playlist that is no podcast with 400
    const response = await client.actions.execute('/browse', { browseId: `MPSP${playlistId}`, client: 'YTMUSIC' }).catch(() => { throw new ResolutionError('UNSUPPORTED_LINK'); });
    const show = showResponse.parse(response.data).microformat.microformatDataRenderer;
    const publisher = show.description.match(/^Podcast\s*•\s*(.*)$/);
    if (!publisher) throw new ResolutionError('UNSUPPORTED_LINK');
    return { title: show.title, artist: publisher[1]!, show: show.title, url: `https://music.youtube.com/playlist?list=${playlistId}`, artworkUrl: https(show.thumbnail?.thumbnails[0]?.url) };
  },
  async shows(query, signal) {
    const results = await (await (await youtube(signal)).music.search(query, { type: 'all' })).applyFilter('Podcasts');
    return results.contents?.flatMap(shelf => shelf.is(YTNodes.MusicShelf) ? shelf.contents.filterType(YTNodes.MusicResponsiveListItem) : []).flatMap(item =>
      item.id?.startsWith('MPSP') ? [{ id: item.id.slice(4), title: flex(item, 0), publisher: flex(item, 1), artworkUrl: item.thumbnail?.contents[0]?.url ?? null }] : []) ?? [];
  },
  async episodes(query, signal) {
    const results = await (await (await youtube(signal)).music.search(query, { type: 'all' })).applyFilter('Episodes');
    // The second column reads "18h ago • Show"
    return results.contents?.flatMap(shelf => shelf.is(YTNodes.MusicShelf) ? shelf.contents.filterType(YTNodes.MusicResponsiveListItem) : []).flatMap(item =>
      item.id ? [{ id: item.id, title: flex(item, 0), show: flex(item, 1).split(' • ').at(-1) ?? '', artworkUrl: item.thumbnail?.contents[0]?.url ?? null }] : []) ?? [];
  },
};

const appleShow = z.object({
  kind: z.literal('podcast'), collectionId: z.number(), collectionName: z.string(), artistName: z.string().default(''),
  feedUrl: z.string().optional(), artworkUrl600: z.string().optional(), artworkUrl100: z.string().optional(),
});
const appleEpisode = z.object({
  wrapperType: z.literal('podcastEpisode'), trackId: z.number(), trackName: z.string(), collectionId: z.number(), collectionName: z.string(),
  releaseDate: z.string().optional(), trackTimeMillis: z.number().optional(), feedUrl: z.string().optional(), artworkUrl600: z.string().optional(),
});
const deezerShow = z.object({ id: z.number(), title: z.string(), available: z.boolean().optional(), picture_medium: z.string().optional(), picture_xl: z.string().optional() });
const deezerEpisode = z.object({
  id: z.number(), title: z.string(), release_date: z.string().optional(), duration: z.number().optional(), available: z.boolean().optional(),
  picture_medium: z.string().optional(), picture_xl: z.string().optional(), podcast: z.object({ id: z.number(), title: z.string() }).optional(),
});
const spotifyShows = z.object({ shows: z.object({ items: z.array(z.object({
  id: z.string(), name: z.string(), publisher: z.string().default(''), images: z.array(z.object({ url: z.string() })).default([]),
}).nullable()) }) });
const spotifyEpisodes = z.object({ items: z.array(z.object({
  id: z.string(), name: z.string(), release_date: z.string().optional(), images: z.array(z.object({ url: z.string() })).default([]),
}).nullable()) });
const results = (body: unknown) => z.object({ results: z.array(z.unknown()) }).parse(body).results;
const parsed = <T extends z.ZodType>(schema: T, items: unknown[]): z.infer<T>[] => items.flatMap(item => {
  const result = schema.safeParse(item);
  return result.success ? [result.data] : [];
});
// "2026-11-04 10:51:32" from Deezer is UTC like the others
const time = (value?: string) => (value ? Date.parse(/^\d{4}-\d{2}-\d{2} /.test(value) ? `${value.replace(' ', 'T')}Z` : value) : NaN) || undefined;
const feed = (value?: string) => value && /^https?:\/\//.test(value) ? value : undefined;
const appleArtwork = (show: { artworkUrl600?: string | undefined; artworkUrl100?: string | undefined }) => https(show.artworkUrl600 ?? show.artworkUrl100?.replace('/100x100bb.', '/600x600bb.'));
const appleShowUrl = (country: string, id: number | string) => `https://podcasts.apple.com/${country.toLowerCase()}/podcast/id${id}`;
const appleEpisodeUrl = (country: string, show: number | string, episode: number | string) => `${appleShowUrl(country, show)}?i=${episode}`;

// Subscribing in other podcast apps: Overcast, Pocket Casts and Castro know shows by their Apple ID,
// AntennaPod and every other app by the RSS feed
export function podcastApps(appleId?: string, feedUrl?: string): PodcastApp[] {
  return [
    ...(appleId ? [{ name: 'Overcast', url: `https://overcast.fm/itunes${appleId}` }, { name: 'Pocket Casts', url: `https://pca.st/itunes/${appleId}` }, { name: 'Castro', url: `https://castro.fm/itunes/${appleId}` }] : []),
    ...(feedUrl ? [{ name: 'AntennaPod', url: `https://antennapod.org/deeplink/subscribe?${new URLSearchParams({ url: feedUrl })}` }, { name: 'RSS', url: feedUrl }] : []),
  ];
}

// Apple's episode page needs the episode's slug and redirects to it; the iTunes API only lists the newest 200 episodes
async function appleEpisodePage(link: MusicLink, { fetcher, signal }: Session): Promise<Podcast> {
  let url = new URL(appleEpisodeUrl(link.country, link.show ?? '', link.id));
  for (let hop = 0; hop < 3; hop++) {
    const response = await fetcher(url, { signal, redirect: 'manual', headers: { 'user-agent': 'Mozilla/5.0 (compatible; Songgate/0.3)' } });
    const location = response.headers.get('location');
    if (response.status >= 300 && response.status < 400 && location) {
      url = new URL(location, url);
      if (url.hostname !== 'podcasts.apple.com' || url.protocol !== 'https:') throw new ResolutionError('SOURCE_UNAVAILABLE');
      continue;
    }
    if (response.status === 404) throw new ResolutionError('SOURCE_UNAVAILABLE');
    if (!response.ok) throw new ResolutionError('NETWORK');
    const html = await response.text();
    // "Podcast-Folge · The Daily · 4. November · 35 Min."
    const show = pageMeta(html, 'og:description')?.split(' · ')[1];
    const released = time(html.match(/"datePublished":"([^"]+)"/)?.[1]);
    return {
      title: pageMeta(html, 'og:title') ?? '', artist: show ?? '', show: show ?? '', url: appleEpisodeUrl(link.country, link.show ?? '', link.id),
      artworkUrl: https(pageMeta(html, 'og:image')), ...(released ? { released } : {}), appleId: link.show ?? '',
    };
  }
  throw new ResolutionError('SOURCE_UNAVAILABLE');
}

export function loadPodcast(link: MusicLink, current: Session, youtubeMusic: YouTubePodcasts): Promise<Podcast> {
  const { get, signal } = current;
  return providerCall(link.platform, signal, async () => {
    let podcast: Podcast;
    if (link.platform === 'appleMusic' && link.kind === 'podcast') {
      const show = parsed(appleShow, results(await get('https://itunes.apple.com/lookup', { id: link.id, country: link.country, entity: 'podcast' }))).find(item => String(item.collectionId) === link.id);
      if (!show) throw new ResolutionError('SOURCE_UNAVAILABLE');
      const feedUrl = feed(show.feedUrl);
      podcast = { title: show.collectionName, artist: show.artistName, show: show.collectionName, url: appleShowUrl(link.country, link.id), artworkUrl: appleArtwork(show), appleId: link.id, ...(feedUrl ? { feedUrl } : {}) };
    } else if (link.platform === 'appleMusic') {
      const items = results(await get('https://itunes.apple.com/lookup', { id: link.show ?? '', country: link.country, entity: 'podcastEpisode', limit: '200' }));
      const episode = parsed(appleEpisode, items).find(item => String(item.trackId) === link.id);
      const feedUrl = feed(episode?.feedUrl ?? parsed(appleShow, items)[0]?.feedUrl);
      if (episode) {
        const released = time(episode.releaseDate);
        podcast = {
          title: episode.trackName, artist: episode.collectionName, show: episode.collectionName, url: appleEpisodeUrl(link.country, link.show ?? '', link.id), artworkUrl: https(episode.artworkUrl600),
          ...(released ? { released } : {}), ...(episode.trackTimeMillis ? { durationSeconds: Math.round(episode.trackTimeMillis / 1000) } : {}), appleId: link.show ?? '', ...(feedUrl ? { feedUrl } : {}),
        };
      } else {
        podcast = { ...await appleEpisodePage(link, current), ...(feedUrl ? { feedUrl } : {}) };
      }
    } else if (link.platform === 'spotify' && link.kind === 'podcast') {
      const html = await current.spotifyPage(`show/${link.id}`);
      // "Podcast · Publisher · Description"
      const publisher = pageMeta(html, 'og:description')?.split(' · ')[1] ?? '';
      podcast = { title: pageMeta(html, 'og:title') ?? '', artist: publisher, show: pageMeta(html, 'og:title') ?? '', url: `https://open.spotify.com/show/${link.id}`, artworkUrl: https(pageMeta(html, 'og:image')) };
    } else if (link.platform === 'spotify') {
      const html = await current.spotifyPage(`episode/${link.id}`);
      // "Show · Episode"
      const show = pageMeta(html, 'og:description')?.replace(/ · [^·]*$/, '') ?? '';
      const released = time(pageMeta(html, 'music:release_date'));
      const duration = Number(pageMeta(html, 'music:duration'));
      podcast = {
        title: pageMeta(html, 'og:title') ?? '', artist: show, show, url: `https://open.spotify.com/episode/${link.id}`, artworkUrl: https(pageMeta(html, 'og:image')),
        ...(released ? { released } : {}), ...(duration > 0 ? { durationSeconds: duration } : {}),
      };
    } else if (link.platform === 'deezer') {
      // Deezer reports unknown shows and episodes as an error object with status 200
      const body = await get(`https://api.deezer.com/${link.kind === 'podcast' ? 'podcast' : 'episode'}/${link.id}`, {});
      if (z.object({ error: z.unknown() }).safeParse(body).data?.error) throw new ResolutionError('SOURCE_UNAVAILABLE');
      if (link.kind === 'podcast') {
        const show = deezerShow.parse(body);
        // Deezer names no publisher
        podcast = { title: show.title, artist: '', show: show.title, url: `https://www.deezer.com/show/${show.id}`, artworkUrl: https(show.picture_xl) };
      } else {
        const episode = deezerEpisode.parse(body);
        const released = time(episode.release_date);
        podcast = {
          title: episode.title, artist: episode.podcast?.title ?? '', show: episode.podcast?.title ?? '', url: `https://www.deezer.com/episode/${episode.id}`, artworkUrl: https(episode.picture_xl),
          ...(released ? { released } : {}), ...(episode.duration ? { durationSeconds: episode.duration } : {}),
        };
      }
    } else if (link.platform === 'youtubeMusic' && link.kind === 'podcast') {
      podcast = await youtubeMusic.show(link.id, signal);
    } else if (link.platform === 'youtubeMusic') {
      const episode = await youtubeMusic.episode(link.id, signal);
      if (!episode) throw new ResolutionError('SOURCE_UNAVAILABLE');
      podcast = episode;
    } else {
      throw new ResolutionError('UNSUPPORTED_LINK');
    }
    podcast.title = podcast.title.trim();
    podcast.artist = podcast.artist.trim();
    podcast.show = podcast.show.trim();
    if (!podcast.title || !podcast.show) throw new ResolutionError('SOURCE_UNAVAILABLE');
    return podcast;
  });
}

// "The Daily Podcast" and "Daily" are the same show, "The Daily T" is another
const showKey = (name: string) => normalize(name).replace(/^the /, '').replace(/ (?:podcast|der podcast|the podcast)$/, '');
// Services name the same show "Lage der Nation" and "Lage der Nation - der Politik-Podcast aus Berlin",
// or "Baywatch Berlin" and "Alle Folgen | Baywatch Berlin": 2 for the same name, 1 when one name's
// first part is a part of the other
const parts = (name: string) => name.split(/\s+[-–—|]\s+|:\s+/).map(showKey).filter(part => part.length >= 4);
export function showScore(a: string, b: string) {
  if (showKey(a) && showKey(a) === showKey(b)) return 2;
  const [first, second] = [parts(a), parts(b)];
  return (first[0] && second.includes(first[0])) || (second[0] && first.includes(second[0])) ? 1 : 0;
}
const byScore = <T>(items: T[], score: (item: T) => number) => items.map(item => ({ item, rank: score(item) })).filter(({ rank }) => rank > 0).toSorted((a, b) => b.rank - a.rank).map(({ item }) => item);

// 2 for the same title, 1 when one title contains the other ("#12 Title", "Title | Show");
// a release date more than three days apart rules a candidate out, reruns get new dates
export function episodeScore(source: Podcast) {
  const title = normalize(source.title);
  return (candidate: string, released?: number) => {
    if (source.released && released && Math.abs(source.released - released) > 3 * 86_400_000) return 0;
    const other = normalize(candidate);
    if (!other || !title) return 0;
    if (other === title) return 2;
    const [shorter, longer] = other.length < title.length ? [other, title] : [title, other];
    return shorter.length >= 12 && longer.includes(shorter) ? 1 : 0;
  };
}

// What the Apple lookups learn on the way, for the other podcast apps
export type AppleShow = { appleId?: string; feedUrl?: string };

async function appleShows(source: Podcast, country: string, current: Session, found: AppleShow) {
  const shows = byScore(parsed(appleShow, results(await current.get('https://itunes.apple.com/search', { term: source.show, entity: 'podcast', country, limit: '25' }))),
    show => showScore(show.collectionName, source.show));
  const first = shows[0];
  if (first) Object.assign(found, { appleId: String(first.collectionId) }, feed(first.feedUrl) ? { feedUrl: feed(first.feedUrl) } : {});
  return shows;
}

async function findShows(target: Platform, source: Podcast, country: string, current: Session, youtubeMusic: YouTubePodcasts, found: AppleShow): Promise<(Candidates[number] & { id: string })[]> {
  if (target === 'appleMusic') {
    return (await appleShows(source, country, current, found)).map(show => ({ id: String(show.collectionId), title: show.collectionName, url: appleShowUrl(country, show.collectionId), artworkUrl: appleArtwork(show) }));
  }
  if (target === 'deezer') {
    const items = z.object({ data: z.array(z.unknown()) }).parse(await current.get('https://api.deezer.com/search/podcast', { q: source.show, limit: '25' })).data;
    return byScore(parsed(deezerShow, items), show => show.available === false ? 0 : showScore(show.title, source.show))
      .map(show => ({ id: String(show.id), title: show.title, url: `https://www.deezer.com/show/${show.id}`, artworkUrl: https(show.picture_medium) }));
  }
  if (target === 'spotify') {
    const body = await spotifyApi('search', { q: source.show, type: 'show', market: country, limit: '20' }, current);
    if (body === null) return [];
    const shows = spotifyShows.parse(body).shows.items.flatMap(show => show && /^[A-Za-z0-9]{22}$/.test(show.id) ? [show] : []);
    return byScore(shows, show => showScore(show.name, source.show))
      .map(show => ({ id: show.id, title: show.name, url: `https://open.spotify.com/show/${show.id}`, artworkUrl: https(show.images[0]?.url) }));
  }
  if (target === 'youtubeMusic') {
    return byScore(await youtubeMusic.shows(source.show, current.signal), show => /^[A-Za-z0-9_-]{10,60}$/.test(show.id) ? showScore(show.title, source.show) : 0)
      .map(show => ({ id: show.id, title: show.title, url: `https://music.youtube.com/playlist?list=${show.id}`, artworkUrl: https(show.artworkUrl) }));
  }
  return [];
}

async function findEpisodes(target: Platform, source: Podcast, country: string, current: Session, youtubeMusic: YouTubePodcasts, found: AppleShow) {
  const score = episodeScore(source);
  let ranked: { rank: number; candidate: Candidates[number] }[] = [];
  if (target === 'youtubeMusic') {
    // YouTube searches episodes directly, its results name their show but no date
    ranked = (await youtubeMusic.episodes(`${source.show} ${source.title}`, current.signal)).flatMap(episode => {
      const rank = /^[A-Za-z0-9_-]{11}$/.test(episode.id) && showScore(episode.show, source.show) ? score(episode.title) : 0;
      return rank ? [{ rank, candidate: { title: episode.title, url: `https://music.youtube.com/watch?v=${episode.id}`, artworkUrl: https(episode.artworkUrl) } }] : [];
    });
  } else if (target === 'appleMusic') {
    const shows = await appleShows(source, country, current, found);
    const ids = new Set(shows.map(show => show.collectionId));
    // The search finds older episodes too, the show's list the newest 200 when the search misses
    const search = parsed(appleEpisode, results(await current.get('https://itunes.apple.com/search', { term: `${source.show} ${source.title}`, entity: 'podcastEpisode', country, limit: '25' })));
    let episodes = search.filter(episode => ids.has(episode.collectionId));
    if (!episodes.some(episode => score(episode.trackName, time(episode.releaseDate))) && shows[0]) {
      episodes = parsed(appleEpisode, results(await current.get('https://itunes.apple.com/lookup', { id: String(shows[0].collectionId), country, entity: 'podcastEpisode', limit: '200' })));
    }
    ranked = episodes.flatMap(episode => {
      const rank = score(episode.trackName, time(episode.releaseDate));
      return rank ? [{ rank, candidate: { title: episode.trackName, url: appleEpisodeUrl(country, episode.collectionId, episode.trackId), artworkUrl: https(episode.artworkUrl600) } }] : [];
    });
  } else if (target === 'deezer') {
    const show = (await findShows(target, source, country, current, youtubeMusic, found))[0];
    if (show) {
      const page = async (index: number) => {
        const body = z.object({ data: z.array(z.unknown()), total: z.number().optional() }).parse(await current.get(`https://api.deezer.com/podcast/${show.id}/episodes`, { limit: '100', index: String(index) }));
        return { episodes: parsed(deezerEpisode, body.data), total: body.total ?? 0 };
      };
      let { episodes, total } = await page(0);
      // The list starts with the newest episode. An older one is looked for once more, where the show's pace puts it.
      const [newest, oldest] = [time(episodes[0]?.release_date), time(episodes.at(-1)?.release_date)];
      if (source.released && newest && oldest && newest > oldest && source.released < oldest - 3 * 86_400_000 && total > episodes.length) {
        const index = Math.round((newest - source.released) / ((newest - oldest) / (episodes.length - 1))) - 50;
        episodes = (await page(Math.max(episodes.length, Math.min(index, total - 100)))).episodes;
      }
      ranked = episodes.flatMap(episode => {
        const rank = episode.available === false ? 0 : score(episode.title, time(episode.release_date));
        return rank ? [{ rank, candidate: { title: episode.title, url: `https://www.deezer.com/episode/${episode.id}`, artworkUrl: https(episode.picture_medium) } }] : [];
      });
    }
  } else if (target === 'spotify') {
    const show = (await findShows(target, source, country, current, youtubeMusic, found))[0];
    const body = show ? await spotifyApi(`shows/${show.id}/episodes`, { market: country, limit: '50' }, current) : null;
    if (body !== null) {
      ranked = spotifyEpisodes.parse(body).items.flatMap(episode => {
        const rank = episode && /^[A-Za-z0-9]{22}$/.test(episode.id) ? score(episode.name, time(episode.release_date)) : 0;
        return episode && rank ? [{ rank, candidate: { title: episode.name, url: `https://open.spotify.com/episode/${episode.id}`, artworkUrl: https(episode.images[0]?.url) } }] : [];
      });
    }
  }
  return ranked.toSorted((a, b) => b.rank - a.rank).map(({ candidate }) => candidate);
}

export function findPodcasts(kind: 'podcast' | 'episode', target: Platform, source: Podcast, country: string, current: Session, youtubeMusic: YouTubePodcasts, found: AppleShow): Promise<Candidates> {
  return providerCall(target, current.signal, async () => {
    const candidates = kind === 'podcast'
      ? (await findShows(target, source, country, current, youtubeMusic, found)).map(({ id: _, ...candidate }) => candidate)
      : await findEpisodes(target, source, country, current, youtubeMusic, found);
    return [...new Map(candidates.map(candidate => [candidate.url, candidate])).values()].slice(0, 8);
  });
}
