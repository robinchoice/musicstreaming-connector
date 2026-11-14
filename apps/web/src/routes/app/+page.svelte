<script lang="ts">
  import { onDestroy, onMount } from 'svelte';
  import Friends from '#lib/components/Friends.svelte';
  import Logo from '#lib/components/Logo.svelte';
  import PleasanceFooter from '#lib/components/PleasanceFooter.svelte';
  import { countries, friendsMessage, serviceName, serviceOrder, servicesFor, sourceOf, type Platform, type Song } from '@app/shared';
  import { page } from '$app/state';
  import { api } from '#lib/api.ts';
  import { social } from '#lib/friends.svelte.ts';
  import { t } from '#lib/i18n.ts';
  import { toast, toastError } from '#lib/toast.svelte.ts';

  let input = $state('');
  let country = 'DE';
  let loading = $state(false);
  let song = $state<Song | null>(null);
  let error = $state('');
  let canShare = $state(false);
  let canPaste = $state(false);
  // Friends fill the services, the tiles can be tapped on their own
  let chosen = $state<string[]>([]);
  let services = $state<Platform[]>([]);
  let request: AbortController | undefined;
  const source = $derived(sourceOf(input));
  // Apple Podcasts links come from Apple's podcast hosts
  const sourceKind = $derived(/(?:podcasts|itunes)\.apple\.com\//.test(input) ? 'podcast' : 'song');
  const friends = $derived(social.friends.filter(friend => chosen.includes(friend.name)));
  const message = $derived(song ? friendsMessage(song, friends, location.origin, social.me, serviceOrder.filter(platform => services.includes(platform)), page.data.locale) : '');

  onMount(() => {
    canShare = typeof navigator.share === 'function';
    canPaste = typeof navigator.clipboard?.readText === 'function';
    const region = navigator.language.split('-')[1]?.toUpperCase();
    if (countries.some(code => code === region)) country = region!;
    // Bookmarklets and shortcuts open /?q=<link> to convert right away
    const shared = new URL(location.href).searchParams.get('q')?.trim();
    if (shared) {
      input = shared.slice(0, 4096);
      find();
    }
  });
  onDestroy(() => request?.abort());

  function reset() { request?.abort(); loading = false; song = null; error = ''; }

  async function find(event?: SubmitEvent) {
    event?.preventDefault();
    if (!input.trim()) return;
    request?.abort();
    const current = new AbortController();
    request = current;
    loading = true;
    error = '';
    try {
      const result = await api.get<Song>(`/song?${new URLSearchParams({ input, country })}`, current.signal);
      if (current.signal.aborted) return;
      song = result;
      scrollTo({ top: 0 });
    } catch (e) {
      if (current.signal.aborted) return;
      error = e instanceof Error ? e.message : t().requestFailed;
    } finally {
      if (!current.signal.aborted) loading = false;
    }
  }

  async function paste() {
    try { input = (await navigator.clipboard.readText()).trim().slice(0, 4096); }
    catch { toastError(t().pasteFailed); return; }
    if (input) find();
  }

  function toggle(platform: Platform) {
    services = services.includes(platform) ? services.filter(other => other !== platform) : [...services, platform];
    // No service left means everyone again
    if (!services.length) chosen = [];
  }

  async function copy() {
    try { await navigator.clipboard.writeText(message); toast(t().copied); }
    catch { toastError(t().copyFailed); }
  }

  async function share() {
    try { await navigator.share({ text: message }); }
    catch (e) { if (!(e instanceof DOMException && e.name === 'AbortError')) toastError(t().shareFailedCopy); }
  }
</script>

{#if song?.source.artworkUrl}<div class="backdrop" aria-hidden="true" style:background-image="url({JSON.stringify(song.source.artworkUrl)})"></div>{/if}
<div class="shell">
  <header><a href="/" class="brand"><img class="brand-icon" src="/favicon.svg" alt="" width="30" height="30" /> Songgate</a></header>
  <main>
    {#if !song}
      <section class="start">
        <form class="field" onsubmit={find}>
          <span class="src">{#if source}<Logo platform={source} kind={sourceKind} size={24} />{:else}<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><path d="M10 14a4 4 0 0 0 5.7 0l3-3a4 4 0 0 0-5.7-5.7l-1 1" /><path d="M14 10a4 4 0 0 0-5.7 0l-3 3a4 4 0 0 0 5.7 5.7l1-1" /></svg>{/if}</span>
          <input id="song" name="song" aria-label={t().linkLabel} bind:value={input} oninput={() => (error = '')} required maxlength="4096" placeholder={t().linkPlaceholder} autocomplete="off" spellcheck="false" disabled={loading} />
          {#if input.trim() || !canPaste}<button class="button primary" type="submit" disabled={loading || !input.trim()}>{t().find}</button>
          {:else}<button class="button ghost" type="button" onclick={paste}>{t().paste}</button>{/if}
        </form>
        <div class="detected" aria-live="polite">
          {#if loading}<span class="loading"><span class="spinner"></span>{t().searching}</span>
          {:else if error}<span class="error" role="alert"><strong>{t().notYet}</strong> {error}</span>
          {:else if source}{t().linkFrom} <b>{serviceName(source, sourceKind)}</b>{/if}
        </div>
      </section>
    {:else}
      <section class="record">
        <div class="head">
          {#if song.source.artworkUrl}<img class="cover" src={song.source.artworkUrl} alt="" referrerpolicy="no-referrer" />{:else}<span class="cover placeholder" aria-hidden="true">♪</span>{/if}
          <div class="titles">
            <h1>{song.source.title}</h1>
            <p class="meta">{[song.source.artist, t().kindFrom(song.source.kind, serviceName(song.source.platform, song.source.kind))].filter(Boolean).join(' · ')}</p>
          </div>
          <button class="newlink" type="button" aria-label={t().otherLink} title={t().otherLink} onclick={() => { reset(); input = ''; }}>×</button>
        </div>
        <div>
          <Friends bind:selected={chosen} bind:services />
          <div class="tiles" role="group" aria-label={t().servicesInMessage}>
            {#each servicesFor(song.source.kind) as platform (platform)}
              {@const link = song.links[platform]}
              {@const names = friends.filter(friend => friend.platform === platform).map(friend => friend.name)}
              <button type="button" class="tile" class:missing={!link.found} aria-pressed={services.includes(platform)} onclick={() => toggle(platform)}>
                <Logo {platform} kind={song.source.kind} size={32} />
                <span><strong>{serviceName(platform, song.source.kind)}</strong><small>{!link.found ? t().searchOnly : names.length ? names.join(', ') : platform === song.source.platform ? t().sourceService : t().found}</small></span>
                <span class="check" aria-hidden="true">{services.includes(platform) ? '✓' : ''}</span>
              </button>
            {/each}
          </div>
          {#if song.apps?.length}
            <p class="apps">{t().otherApps}: {#each song.apps as app, i (app.name)}{i ? ', ' : ''}<a href={app.url} rel="noreferrer" target="_blank">{app.name}</a>{/each}</p>
          {/if}
          <div class="out" aria-live="polite">
            <pre>{message}</pre>
            <div class="actions">
              {#if canShare}<button class="button primary" type="button" onclick={share}>{t().share}</button>{/if}
              <button class="button {canShare ? 'ghost' : 'primary'}" type="button" onclick={copy}>{t().copy}</button>
            </div>
          </div>
        </div>
      </section>
    {/if}
  </main>
  <PleasanceFooter />
</div>

<style>
  .backdrop { position: fixed; inset: -10%; background: center / cover; filter: blur(90px) saturate(1.3); opacity: .26; pointer-events: none; animation: fade .8s ease-out; }
  @keyframes fade { from { opacity: 0; } }
  .shell { position: relative; max-width: 1040px; min-height: 100dvh; margin: auto; padding: 0 32px; display: flex; flex-direction: column; }
  header { padding: 20px 0; }
  .brand { display: inline-flex; align-items: center; gap: 9px; font-size: 22px; text-decoration: none; color: var(--text); }
  main { flex: 1; display: flex; flex-direction: column; width: 100%; max-width: 640px; margin: 0 auto; padding: 8px 0 40px; }

  /* Only the field, a bit above the middle */
  .start { flex: 1; display: flex; flex-direction: column; justify-content: center; padding-bottom: 12vh; }
  .field { display: flex; align-items: center; gap: 12px; padding: 7px 7px 7px 18px; border-radius: 22px; background: rgb(255 255 255 / .05); border: 1px solid var(--border-strong); }
  .field:focus-within { border-color: color-mix(in srgb, var(--accent) 60%, transparent); }
  .src { width: 26px; height: 26px; display: grid; place-items: center; color: var(--muted); flex-shrink: 0; }
  #song { flex: 1; min-width: 0; border: 0; background: none; outline: none; color: var(--text); font-size: 17px; padding: 13px 0; }
  #song::placeholder { color: #6E6C76; }
  .detected { margin: 10px 0 0 18px; font-size: 14px; color: var(--muted); min-height: 22px; }
  .detected b { color: var(--text); font-weight: 600; }
  .loading { display: inline-flex; align-items: center; gap: 10px; }
  .spinner { width: 18px; height: 18px; border-radius: 50%; background: conic-gradient(from 0deg, transparent 0 25%, #80CD84, #57C6BB); mask: radial-gradient(circle, transparent 6px, #000 7px); animation: spin .9s linear infinite; }
  @keyframes spin { to { transform: rotate(1turn); } }
  .error { display: block; padding-left: 12px; border-left: 3px solid var(--error); color: var(--muted); }
  .error strong { color: var(--text); font-weight: 600; }

  .record { display: flex; flex-direction: column; gap: 18px; animation: rise .45s ease-out; }
  @keyframes rise { from { opacity: 0; transform: translateY(10px); } }
  .head { display: flex; align-items: center; gap: 16px; }
  .cover { width: 96px; height: 96px; border-radius: 12px; object-fit: cover; flex-shrink: 0; box-shadow: 0 24px 50px -24px rgb(0 0 0 / .9); }
  .placeholder { display: grid; place-items: center; background: var(--raised); font-size: 36px; color: var(--muted); }
  .titles { min-width: 0; flex: 1; }
  .record h1 { font-size: clamp(28px, 4.4vw, 40px); margin: 0 0 4px; overflow-wrap: anywhere; }
  .meta { color: var(--muted); font-size: 14px; margin: 0; }
  .newlink { align-self: flex-start; flex-shrink: 0; width: 34px; height: 34px; border-radius: 50%; border: 0; background: rgb(255 255 255 / .08); color: var(--muted); font-size: 20px; line-height: 1; }
  .newlink:hover { background: rgb(255 255 255 / .14); color: var(--text); }

  .tiles { display: grid; grid-template-columns: 1fr 1fr; gap: 8px; }
  .tile { position: relative; display: flex; align-items: center; gap: 12px; padding: 12px 14px; border-radius: 16px; background: rgb(255 255 255 / .06); border: 1px solid var(--border); color: var(--text); text-align: left; min-width: 0; }
  .tile:hover { background: rgb(255 255 255 / .1); }
  .tile > span:not(.check) { min-width: 0; }
  .tile strong { display: block; font-weight: 650; padding-right: 18px; }
  .tile small { display: block; color: var(--muted); font-size: 12.5px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .tile[aria-pressed="true"] { background: linear-gradient(rgb(36 35 42 / .92), rgb(36 35 42 / .92)) padding-box, var(--gradient) border-box; border-color: transparent; }
  .tile.missing { opacity: .6; }
  .apps { margin: 12px 0 0; color: var(--muted); font-size: 14px; }
  .apps a { color: var(--text); }
  .check { position: absolute; top: 10px; right: 12px; width: 20px; height: 20px; border-radius: 50%; border: 1.5px solid var(--border-strong); display: grid; place-items: center; font-size: 12px; color: var(--ink); }
  .tile[aria-pressed="true"] .check { background: var(--raised); color: var(--text); border-color: var(--accent); }

  .out { margin-top: 14px; padding: 14px 16px; border-radius: 16px; background: rgb(0 0 0 / .25); border: 1px solid var(--border); }
  pre { margin: 0 0 14px; font: inherit; font-size: 14px; line-height: 1.55; white-space: pre-wrap; overflow-wrap: anywhere; }
  .actions { display: flex; gap: 8px; }
  .actions .button { flex: 1; }

  @media(max-width: 650px) {
    .shell { padding: 0 18px; }
    header { padding: 14px 0; }
    main { padding-bottom: 28px; }
    #song { font-size: 16px; }
    .cover { width: 68px; height: 68px; border-radius: 10px; }
    .record h1 { font-size: 26px; }
    .record { gap: 14px; }
    .tile { padding: 10px 12px; gap: 10px; }
    .tile :global(.logo) { width: 24px; height: 24px; }
    .tile strong { font-size: 15px; }
    pre { font-size: 13px; }
  }
</style>
