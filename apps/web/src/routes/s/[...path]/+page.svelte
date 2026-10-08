<script lang="ts">
  import PleasanceFooter from '$lib/components/PleasanceFooter.svelte';
  import { platforms, type Platform } from '@app/shared';
  let { data } = $props();
  const song = $derived(data.song);
  const order = Object.keys(platforms) as Platform[];
  const found = $derived(order.filter(platform => song.links[platform].found).map(platform => platforms[platform]));
</script>

<svelte:head>
  <title>{song.source.title} · {song.source.artist} · MusicLink</title>
  <meta property="og:type" content="music.song" />
  <meta property="og:site_name" content="MusicLink" />
  <meta property="og:title" content="{song.source.title} · {song.source.artist}" />
  <meta property="og:description" content="Anhören auf {found.join(', ')}" />
  <meta property="og:url" content="{data.origin}{song.sharePath}" />
  {#if song.source.artworkUrl}<meta property="og:image" content={song.source.artworkUrl} />{/if}
  <meta name="twitter:card" content="summary" />
</svelte:head>

<div class="shell">
  <header><a href="/" class="brand"><img class="brand-icon" src="/favicon.svg" alt="" width="38" height="38" /> MusicLink</a><span class="badge">Ohne Anmeldung</span></header>
  <main>
    <section class="card">
      <div class="song">
        {#if song.source.artworkUrl}<img class="cover" src={song.source.artworkUrl} alt="" referrerpolicy="no-referrer" />{:else}<span class="cover placeholder" aria-hidden="true">♪</span>{/if}
        <div><div class="eyebrow">JEMAND HAT DIR EINEN SONG GESCHICKT</div><h1>{song.source.title}</h1><p>{song.source.artist}</p></div>
      </div>
      <h2>Wo hörst du Musik?</h2>
      {#each order as platform}
        {@const link = song.links[platform]}
        <a class="service" class:missing={!link.found} href={link.url} rel="noreferrer">
          <span class="dot {platform}" aria-hidden="true"></span>
          <span class="name">{platforms[platform]}{#if !link.found}<small>Kein sicherer Treffer · auf {platforms[platform]} suchen</small>{/if}</span>
          <span class="go">{link.found ? 'Öffnen ↗' : 'Suchen ↗'}</span>
        </a>
      {/each}
    </section>
    <p class="more">Selbst einen Song teilen? <a href="/">MusicLink öffnen</a></p>
  </main>
  <PleasanceFooter />
</div>

<style>
  .shell { max-width: 720px; min-height: 100dvh; margin: auto; padding: 0 28px; display: flex; flex-direction: column; }
  header { display: flex; align-items: center; justify-content: space-between; padding: 22px 0; border-bottom: 1px solid var(--border); }
  .brand { display: flex; align-items: center; gap: 10px; font-size: 26px; text-decoration: none; color: var(--text); }
  .badge { font-size: 11px; border: 1px solid var(--border); border-radius: 99px; padding: 5px 10px; }
  main { flex: 1; padding: 30px 0; }
  .card { background: var(--surface); border: 1px solid var(--border); border-radius: var(--radius); padding: 26px; }
  .song { display: flex; align-items: flex-end; gap: 20px; margin-bottom: 26px; }
  .cover { width: 150px; height: 150px; border-radius: 10px; object-fit: cover; flex-shrink: 0; }
  .placeholder { display: grid; place-items: center; background: var(--raised); font-size: 48px; }
  .eyebrow { font-size: 11px; letter-spacing: 1.4px; font-weight: 650; color: var(--accent); }
  h1 { font-size: clamp(30px, 6vw, 44px); margin: 8px 0 4px; overflow-wrap: anywhere; }
  .song p { color: var(--muted); margin: 0; }
  h2 { font-family: inherit; font-size: 13px; font-weight: 650; letter-spacing: 0; color: var(--muted); margin: 0 0 6px; }
  .service { display: flex; align-items: center; gap: 13px; border: 1px solid var(--border); border-radius: 10px; padding: 14px; margin-top: 8px; background: #1B1A20; color: var(--text); text-decoration: none; font-size: 15px; }
  .service:hover { background: var(--raised); }
  .service.missing { opacity: .6; }
  .name { display: flex; flex-direction: column; }
  .name small { font-size: 11px; color: var(--muted); }
  .go { margin-left: auto; font-size: 12px; color: var(--muted); }
  .dot { width: 26px; height: 26px; border-radius: 7px; flex-shrink: 0; }
  .appleMusic { background: #FA2D48; } .youtubeMusic { background: #FF0033; } .spotify { background: #1DB954; } .deezer { background: #A238FF; }
  .more { color: var(--muted); font-size: 13px; margin-top: 18px; }
  @media(max-width: 650px) {
    .shell { padding: 0 18px; } .card { padding: 18px; }
    .song { flex-direction: column; align-items: flex-start; } .cover { width: 100%; height: auto; aspect-ratio: 1; }
  }
</style>
