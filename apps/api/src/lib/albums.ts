import type { Conversion, Platform } from '@app/shared';
import { YTNodes } from 'youtubei.js';
import { z } from 'zod';
import { appleCatalog, appleUrl, codeFailure, https, normalize, providerCall, recording, spotifyMeta, spotifyMetas, youtube, type MusicLink, type Session } from './providers';
import { ResolutionError } from './resolver';

type Candidates = Conversion['candidates'];
export type Album = { title: string; artist: string; url: string; artworkUrl: string | null; upc?: string; firstTrack?: string };
type YouTubeAlbum = { id: string; title: string; artists: string[]; artworkUrl: string | null };
export type YouTubeAlbums = {
  search: (query: string, signal: AbortSignal) => Promise<YouTubeAlbum[]>;
  album: (id: string, signal: AbortSignal) => Promise<Album>;
};

export const youtubeAlbums: YouTubeAlbums = {
  async search(query, signal) {
    const results = await (await youtube(signal)).music.search(query, { type: 'album' });
    return (results.albums?.contents ?? []).flatMap(item => item.id && item.title ? [{
      id: item.id, title: item.title, artists: item.artists?.map(artist => artist.name) ?? (item.author ? [item.author.name] : []),
      artworkUrl: item.thumbnails[0]?.url ?? null,
    }] : []);
  },
  async album(id, signal) {
    const client = await youtube(signal);
    // A shared album link names the album's playlist, whose tracks name the album page
    const browseId = id.startsWith('MPREb_') ? id
      : (await client.music.getPlaylist(id)).items.filterType(YTNodes.MusicResponsiveListItem)[0]?.album?.id;
    if (!browseId) throw new ResolutionError('SOURCE_UNAVAILABLE');
    const album = await client.music.getAlbum(browseId);
    const header = album.header?.is(YTNodes.MusicResponsiveHeader)
      ? { title: album.header.title.toString(), artist: album.header.strapline_text_one.toString(), artworkUrl: album.header.thumbnail?.contents[0]?.url }
      : album.header?.is(YTNodes.MusicDetailHeader)
        ? { title: album.header.title.toString(), artist: album.header.author?.name ?? '', artworkUrl: album.header.thumbnails[0]?.url }
        : { title: '', artist: '' };
    return {
      title: header.title, artist: header.artist, url: album.url ?? `https://music.youtube.com/browse/${browseId}`,
      artworkUrl: https(header.artworkUrl), ...(album.contents[0]?.title ? { firstTrack: album.contents[0].title } : {}),
    };
  },
};

const appleCollection = z.object({
  wrapperType: z.literal('collection'), collectionId: z.number(), collectionName: z.string(), artistName: z.string(),
  collectionViewUrl: z.string().url(), artworkUrl100: z.string().optional(),
});
const appleTrack = z.object({ kind: z.literal('song'), trackName: z.string() });
const appleAlbum = z.object({ attributes: z.object({
  name: z.string(), artistName: z.string(), url: z.string(), upc: z.string().optional(),
  artwork: z.object({ url: z.string() }).optional(), playParams: z.unknown().optional(),
}) });
const deezerAlbum = z.object({
  id: z.number(), title: z.string(), upc: z.string().optional(), artist: z.object({ name: z.string() }),
  cover_medium: z.string().optional(), cover_xl: z.string().optional(), available: z.boolean().optional(),
  tracks: z.object({ data: z.array(z.object({ title: z.string() })) }).optional(),
});
const listenBrainz = z.array(z.object({ spotify_track_ids: z.array(z.string()).default([]) }));
const upcCode = (value?: string) => value && /^\d{12,14}$/.test(value) ? { upc: value } : {};
// The iTunes API names singles and EPs "Title - Single", the other services don't
const appleName = (name: string) => name.replace(/ - (?:Single|EP)$/, '');
const deezerCandidate = (album: z.infer<typeof deezerAlbum>) => ({ title: album.title, url: `https://www.deezer.com/album/${album.id}`, artworkUrl: https(album.cover_medium) });
function appleCandidate(link: string, title: string, artworkUrl: string | null) {
  const url = appleUrl(link, false);
  return url ? [{ title: appleName(title), url, artworkUrl }] : [];
}

export function loadAlbum(link: MusicLink, current: Session, youtubeMusic: YouTubeAlbums): Promise<Album> {
  const { get, signal } = current;
  return providerCall(link.platform, signal, async () => {
    let album: Album;
    if (link.platform === 'youtubeMusic') {
      album = await youtubeMusic.album(link.id, signal);
    } else if (link.platform === 'appleMusic') {
      const [body, upc] = await Promise.all([
        get('https://itunes.apple.com/lookup', { id: link.id, country: link.country, entity: 'song' }),
        appleCatalog(`${link.country.toLowerCase()}/albums/${link.id}`, {}, appleAlbum, current).then(albums => albums[0]?.attributes.upc, () => { codeFailure('UPC', 'appleMusic', signal); return undefined; }),
      ]);
      const results = z.object({ results: z.array(z.unknown()) }).parse(body).results;
      const collection = results.map(item => appleCollection.safeParse(item).data).find(item => String(item?.collectionId) === link.id);
      if (!collection) throw new ResolutionError('SOURCE_UNAVAILABLE');
      const firstTrack = results.values().map(item => appleTrack.safeParse(item).data).find(Boolean)?.trackName;
      album = {
        ...upcCode(upc), title: appleName(collection.collectionName), artist: collection.artistName, url: `https://music.apple.com/${link.country.toLowerCase()}/album/${link.id}`,
        artworkUrl: https(collection.artworkUrl100?.replace('/100x100bb.', '/600x600bb.')), ...(firstTrack ? { firstTrack } : {}),
      };
    } else if (link.platform === 'spotify') {
      const html = await current.spotifyPage(`album/${link.id}`);
      const heading = spotifyMeta(html, 'og:title')?.match(/^Listen to (.+) - (?:Album|Single|EP|Compilation) by (.+) \| Spotify$/);
      if (!heading) throw new ResolutionError('SOURCE_UNAVAILABLE');
      album = { title: heading[1]!, artist: heading[2]!, url: `https://open.spotify.com/album/${link.id}`, artworkUrl: https(spotifyMeta(html, 'og:image')) };
    } else {
      // Deezer reports unknown albums as an error object with status 200
      const body = await get(`https://api.deezer.com/album/${link.id}`, {});
      if (z.object({ error: z.unknown() }).safeParse(body).data?.error) throw new ResolutionError('SOURCE_UNAVAILABLE');
      const found = deezerAlbum.parse(body);
      const firstTrack = found.tracks?.data[0]?.title;
      album = { ...upcCode(found.upc), title: found.title, artist: found.artist.name, url: `https://www.deezer.com/album/${found.id}`, artworkUrl: https(found.cover_xl), ...(firstTrack ? { firstTrack } : {}) };
    }
    album.title = album.title.trim();
    album.artist = album.artist.trim();
    if (!album.title || !album.artist) throw new ResolutionError('SOURCE_UNAVAILABLE');
    return album;
  });
}

// The UPC names the release, so a hit needs no text comparison
async function upcCandidates(target: Platform, upc: string, country: string, current: Session): Promise<Candidates> {
  try {
    if (target === 'appleMusic') {
      return (await appleCatalog(`${country.toLowerCase()}/albums`, { 'filter[upc]': upc }, appleAlbum, current))
        .filter(album => album.attributes.playParams !== undefined)
        .flatMap(({ attributes: album }) => appleCandidate(album.url, album.name, https(album.artwork?.url.replace('{w}x{h}', '100x100'))));
    }
    if (target === 'deezer') {
      // Deezer answers an unknown UPC with an error object, which does not parse as an album
      const album = deezerAlbum.safeParse(await current.get(`https://api.deezer.com/album/upc:${upc}`, {}));
      return album.success && album.data.available !== false ? [deezerCandidate(album.data)] : [];
    }
  } catch {
    codeFailure('UPC', target, current.signal);
  }
  return [];
}

// Without a trailing edition such as "(Remastered)", which the services name differently
const withoutEdition = (title: string) => title.replace(/(?:\s*[\[(][^\])]*[\])])+\s*$/, '');

// Same title and artist first, then the same title without edition
function albumScore(source: Album) {
  const base = (title: string) => normalize(withoutEdition(title));
  const original = recording(source.title, [source.artist]);
  return (title: string, artists?: string[]) => {
    const candidate = recording(title, artists ?? [source.artist]);
    if (candidate.artists !== original.artists) return 0;
    return candidate.title === original.title ? 2 : base(title) && base(title) === base(source.title) ? 1 : 0;
  };
}

// ListenBrainz knows Spotify tracks, not albums: the album's first track leads to its Spotify page, which names its album
async function spotifyAlbums(source: Album, current: Session, score: ReturnType<typeof albumScore>) {
  if (!source.firstTrack) return [];
  const entries = listenBrainz.parse(await current.get('https://labs.api.listenbrainz.org/spotify-id-from-metadata/json', {
    artist_name: source.artist, track_name: source.firstTrack, release_name: '',
  }));
  const ids = [...new Set(entries.flatMap(entry => entry.spotify_track_ids))].filter(id => /^[A-Za-z0-9]{22}$/.test(id)).slice(0, 3);
  const pages = await Promise.all(ids.map(id => current.spotifyPage(`track/${id}`).catch((error: unknown) => {
    if (error instanceof ResolutionError && error.code === 'SOURCE_UNAVAILABLE') return '';
    throw error;
  })));
  return pages.flatMap(html => {
    const url = spotifyMeta(html, 'music:album');
    // "Artists · Album · Song · Year"
    const parts = spotifyMeta(html, 'og:description')?.split(' · ') ?? [];
    const title = parts.slice(1, -2).join(' · ');
    if (!url || !/^https:\/\/open\.spotify\.com\/album\/[A-Za-z0-9]{22}$/.test(url) || !title) return [];
    const rank = score(title);
    return rank ? [{ rank, candidate: { title, url, artworkUrl: https(spotifyMeta(html, 'og:image')) } }] : [];
  });
}

export function findAlbums(target: Platform, source: Album, country: string, current: Session, youtubeMusic: YouTubeAlbums): Promise<Candidates> {
  const { get, signal } = current;
  return providerCall(target, signal, async () => {
    const exact = source.upc ? await upcCandidates(target, source.upc, country, current) : [];
    if (exact.length) return exact.slice(0, 8);
    const score = albumScore(source);
    const query = `${source.artist} ${withoutEdition(source.title) || source.title}`;
    let ranked: { rank: number; candidate: Candidates[number] }[];
    if (target === 'appleMusic') {
      ranked = z.object({ results: z.array(z.unknown()) }).parse(await get('https://itunes.apple.com/search', { term: query, entity: 'album', country, limit: '25' })).results.flatMap(item => {
        const album = appleCollection.safeParse(item);
        const rank = album.success ? score(appleName(album.data.collectionName), [album.data.artistName]) : 0;
        return album.success && rank ? appleCandidate(album.data.collectionViewUrl, album.data.collectionName, https(album.data.artworkUrl100)).map(candidate => ({ rank, candidate })) : [];
      });
    } else if (target === 'youtubeMusic') {
      ranked = (await youtubeMusic.search(query, signal)).flatMap(album => {
        const rank = /^MPREb_[A-Za-z0-9_-]+$/.test(album.id) ? score(album.title, album.artists) : 0;
        return rank ? [{ rank, candidate: { title: album.title, url: `https://music.youtube.com/browse/${album.id}`, artworkUrl: https(album.artworkUrl) } }] : [];
      });
    } else if (target === 'deezer') {
      ranked = z.object({ data: z.array(z.unknown()) }).parse(await get('https://api.deezer.com/search/album', { q: query, limit: '25' })).data.flatMap(item => {
        const album = deezerAlbum.safeParse(item);
        const rank = album.success && album.data.available !== false ? score(album.data.title, [album.data.artist.name]) : 0;
        return album.success && rank ? [{ rank, candidate: deezerCandidate(album.data) }] : [];
      });
    } else {
      ranked = await spotifyAlbums(source, current, score);
    }
    const candidates = ranked.toSorted((a, b) => b.rank - a.rank).map(({ candidate }) => candidate);
    return [...new Map(candidates.map(candidate => [candidate.url, candidate])).values()].slice(0, 8);
  });
}
