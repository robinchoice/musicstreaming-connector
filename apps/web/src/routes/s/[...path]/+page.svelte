<script lang="ts">
  import Avatar from '$lib/components/Avatar.svelte';
  import Connect from '$lib/components/Connect.svelte';
  import Logo from '$lib/components/Logo.svelte';
  import PleasanceFooter from '$lib/components/PleasanceFooter.svelte';
  import { onMount } from 'svelte';
  import { platforms, serviceOrder, type Platform } from '@app/shared';
  import { t } from '$lib/i18n';
  let { data } = $props();
  const song = $derived(data.song);
  const from = $derived(data.from);
  // The service a visitor opened last comes first next time, kept on the device only
  const KEY = 'musiclink-service';
  let mine = $state<Platform | null>(null);
  const order = $derived(serviceOrder.toSorted((a, b) => Number(b === mine) - Number(a === mine)));
  onMount(() => {
    const saved = localStorage.getItem(KEY);
    if (saved && saved in platforms) mine = saved as Platform;
  });
  function remember(platform: Platform) {
    try { localStorage.setItem(KEY, platform); } catch {}
  }
</script>

<svelte:head><title>{song.source.title} · {song.source.artist} · Songgate</title></svelte:head>

{#if song.source.artworkUrl}<div class="backdrop" aria-hidden="true" style:background-image="url({JSON.stringify(song.source.artworkUrl)})"></div>{/if}
<div class="shell">
  <header><a href="/" class="brand"><img class="brand-icon" src="/favicon.svg" alt="" width="34" height="34" /> Songgate</a></header>
  <main>
    <section class="record">
      {#if song.source.artworkUrl}<img class="cover" src={song.source.artworkUrl} alt="" referrerpolicy="no-referrer" />{:else}<span class="cover placeholder" aria-hidden="true">♪</span>{/if}
      <div>
        {#if from}<div class="from"><Avatar friend={from} size={30} /><span><b>{from.name}</b> {t().sentYou(song.source.kind)}</span></div>
        {:else}<div class="from">{t().forYou(song.source.kind)}</div>{/if}
        <h1>{song.source.title}</h1>
        <p class="artist">{song.source.artist}</p>
        <h2>{t().whereListen}</h2>
        <div class="tiles">
          {#each order as platform (platform)}
            {@const link = song.links[platform]}
            <a class="open" class:missing={!link.found} class:mine={platform === mine} href={link.url} rel="noreferrer" onclick={() => remember(platform)}>
              <Logo {platform} size={platform === mine ? 38 : 32} />
              <strong>{platforms[platform]}</strong>
              <small>{!link.found ? t().search : platform === mine ? t().lastUsed : t().open}</small>
            </a>
          {/each}
        </div>
        {#if from}<section class="back"><Connect name={from.name} platform={from.platform} heading="h2" /></section>{/if}
        <section class="promo">
          <img src="/favicon.svg" alt="" width="44" height="44" />
          <div>
            <strong>{t().shareYourself}</strong>
            <p>{t().shareYourselfHint}</p>
          </div>
          <a class="button primary" href="/">{t().openSonggate}</a>
        </section>
      </div>
    </section>
  </main>
  <PleasanceFooter />
</div>

<style>
  .backdrop { position: fixed; inset: -10%; background: center / cover; filter: blur(90px) saturate(1.3); opacity: .26; pointer-events: none; }
  .shell { position: relative; max-width: 1040px; min-height: 100dvh; margin: auto; padding: 0 32px; display: flex; flex-direction: column; }
  header { padding: 22px 0; }
  .brand { display: inline-flex; align-items: center; gap: 10px; font-size: 24px; text-decoration: none; color: var(--text); }
  .brand-icon { width: 34px; height: 34px; }
  main { flex: 1; padding: 48px 0 64px; }
  .record { display: grid; grid-template-columns: 340px minmax(0, 1fr); gap: 44px; align-items: start; }
  .record > div { min-width: 0; }
  .cover { width: 340px; height: 340px; border-radius: 16px; object-fit: cover; box-shadow: 0 40px 80px -30px rgb(0 0 0 / .9); position: sticky; top: 24px; }
  .placeholder { display: grid; place-items: center; background: var(--raised); font-size: 72px; color: var(--muted); }
  .from { display: flex; align-items: center; gap: 10px; color: var(--muted); font-size: 14px; margin-bottom: 10px; }
  .from b { color: var(--text); font-weight: 600; }
  h1 { font-size: clamp(40px, 5.6vw, 64px); margin: 0 0 4px; overflow-wrap: anywhere; }
  .artist { font-size: 18px; margin: 0 0 26px; color: rgb(242 240 234 / .8); }
  h2 { font-size: 14px; color: var(--muted); margin: 0 0 10px; }
  .tiles { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; }
  .open { display: flex; align-items: center; gap: 14px; padding: 16px 18px; border-radius: 18px; background: rgb(255 255 255 / .06); border: 1px solid var(--border); color: var(--text); text-decoration: none; min-width: 0; }
  .open:hover { background: rgb(255 255 255 / .1); }
  .open strong { flex: 1; font-weight: 650; min-width: 0; }
  .open small { color: var(--muted); font-size: 12.5px; }
  .open.missing { opacity: .6; }
  .open.mine { grid-column: 1 / -1; padding: 20px; background: linear-gradient(rgb(40 39 46 / .92), rgb(40 39 46 / .92)) padding-box, var(--gradient) border-box; border: 1px solid transparent; }
  .back { margin-top: 22px; padding: 18px; border-radius: 18px; border: 1px dashed var(--border-strong); background: rgb(0 0 0 / .2); }
  .promo { display: flex; align-items: center; gap: 16px; margin-top: 22px; padding: 18px 20px; border-radius: 18px; background: linear-gradient(rgb(40 39 46 / .92), rgb(40 39 46 / .92)) padding-box, var(--gradient) border-box; border: 1px solid transparent; }
  .promo img { flex: none; }
  .promo div { flex: 1; min-width: 0; }
  .promo strong { display: block; font-size: 18px; font-weight: 650; }
  .promo p { margin: 4px 0 0; color: var(--muted); font-size: 14px; }
  @media(max-width: 860px) {
    .shell { padding: 0 18px; }
    main { padding: 24px 0 40px; }
    .record { grid-template-columns: minmax(0, 1fr); gap: 18px; }
    .cover { position: static; width: 100%; height: auto; aspect-ratio: 1; max-width: 220px; }
    h1 { font-size: 36px; }
    .open { padding: 14px; gap: 10px; }
    .open small { display: none; }
    .open.mine small { display: inline; }
    .promo { flex-wrap: wrap; }
    .promo .button { flex: 1 0 100%; }
  }
</style>
