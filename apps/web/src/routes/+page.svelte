<script lang="ts">
  import { onDestroy, onMount } from 'svelte';
  import Friends from '$lib/components/Friends.svelte';
  import Logo from '$lib/components/Logo.svelte';
  import PleasanceFooter from '$lib/components/PleasanceFooter.svelte';
  import { countries, friendsMessage, platforms, sourceOf, type Platform, type Song } from '@app/shared';
  import { api } from '$lib/api';
  import { social } from '$lib/friends.svelte';
  import { toast, toastError } from '$lib/toast.svelte';

  const order: Platform[] = ['spotify', 'appleMusic', 'youtubeMusic', 'deezer'];
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
  const friends = $derived(social.friends.filter(friend => chosen.includes(friend.name)));
  const message = $derived(song ? friendsMessage(song, friends, location.origin, social.me, order.filter(platform => services.includes(platform))) : '');
  const what = $derived(!services.length ? 'Ein Link für alle. Jede und jeder wählt den eigenen Dienst, ideal für Gruppenchats.'
    : services.length === 1 ? `Direktlink für ${platforms[services[0]!]}${social.me ? ', dazu der Link für alle mit deinem Namen' : ''}.`
    : 'Eine Zeile pro Dienst, für alle anderen der Link für alle.');

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
      error = e instanceof Error ? e.message : 'Die Anfrage ist fehlgeschlagen.';
    } finally {
      if (!current.signal.aborted) loading = false;
    }
  }

  async function paste() {
    try { input = (await navigator.clipboard.readText()).trim().slice(0, 4096); }
    catch { toastError('Einfügen nicht möglich. Füge den Link von Hand ein.'); return; }
    if (input) find();
  }

  function toggle(platform: Platform) {
    services = services.includes(platform) ? services.filter(other => other !== platform) : [...services, platform];
    // No service left means everyone again
    if (!services.length) chosen = [];
  }

  async function copy() {
    try { await navigator.clipboard.writeText(message); toast('Nachricht kopiert.'); }
    catch { toastError('Kopieren nicht möglich.'); }
  }

  async function share() {
    try { await navigator.share({ text: message }); }
    catch (e) { if (!(e instanceof DOMException && e.name === 'AbortError')) toastError('Teilen nicht möglich. Kopiere stattdessen die Nachricht.'); }
  }
</script>

{#if song?.source.artworkUrl}<div class="backdrop" aria-hidden="true" style:background-image="url({JSON.stringify(song.source.artworkUrl)})"></div>{/if}
<div class="shell">
  <header><a href="/" class="brand" onclick={reset}><img class="brand-icon" src="/favicon.svg" alt="" width="34" height="34" /> Songgate</a></header>
  <main>
    {#if !song}
      <section class="start">
        <h1>Teil Musik. Jeder hört sie in seinem Dienst.</h1>
        <p class="lede">Füge einen Song- oder Albumlink ein. Songgate findet ihn bei Spotify, Apple Music, YouTube Music und Deezer.</p>
        <form class="field" onsubmit={find}>
          <span class="src">{#if source}<Logo platform={source} size={24} />{:else}<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><path d="M10 14a4 4 0 0 0 5.7 0l3-3a4 4 0 0 0-5.7-5.7l-1 1" /><path d="M14 10a4 4 0 0 0-5.7 0l-3 3a4 4 0 0 0 5.7 5.7l1-1" /></svg>{/if}</span>
          <input id="song" name="song" aria-label="Song- oder Albumlink" bind:value={input} oninput={() => (error = '')} required maxlength="4096" placeholder="Link aus Spotify, Apple Music, YouTube Music oder Deezer" autocomplete="off" spellcheck="false" disabled={loading} />
          {#if input.trim() || !canPaste}<button class="button primary" type="submit" disabled={loading || !input.trim()}>Finden</button>
          {:else}<button class="button ghost" type="button" onclick={paste}>Einfügen</button>{/if}
        </form>
        <div class="detected" aria-live="polite">
          {#if loading}<span class="loading"><span class="spinner"></span>Suche bei allen vier Diensten …</span>
          {:else if error}<span class="error" role="alert"><strong>Das hat noch nicht geklappt.</strong> {error}</span>
          {:else if source}Link aus <b>{platforms[source]}</b>{/if}
        </div>
        <div class="people"><Friends bind:selected={chosen} bind:services disabled={loading} /></div>
        <p class="note">Ohne Konto. Freunde und Gruppen bleiben auf deinem Gerät. Dein Link geht an unseren Dienst, die Treffer liefern Apple, YouTube, Spotify, Deezer und ListenBrainz.</p>
      </section>
    {:else}
      <section class="record">
        {#if song.source.artworkUrl}<img class="cover" src={song.source.artworkUrl} alt="" referrerpolicy="no-referrer" />{:else}<span class="cover placeholder" aria-hidden="true">♪</span>{/if}
        <div>
          <div class="meta">{song.source.kind === 'album' ? 'Album' : 'Song'} aus {platforms[song.source.platform]}</div>
          <h1>{song.source.title}</h1>
          <p class="artist">{song.source.artist}</p>
          <button class="newlink" type="button" onclick={() => { reset(); input = ''; }}>Anderen Link einfügen</button>
          <Friends bind:selected={chosen} bind:services />
          <div class="tiles" role="group" aria-label="Dienste in der Nachricht">
            {#each order as platform (platform)}
              {@const link = song.links[platform]}
              {@const names = friends.filter(friend => friend.platform === platform).map(friend => friend.name)}
              <button type="button" class="tile" class:missing={!link.found} aria-pressed={services.includes(platform)} onclick={() => toggle(platform)}>
                <Logo {platform} size={32} />
                <span><strong>{platforms[platform]}</strong><small>{!link.found ? 'Nur Suche' : names.length ? names.join(', ') : platform === song.source.platform ? 'Quelle' : 'Gefunden'}</small></span>
                <span class="check" aria-hidden="true">{services.includes(platform) ? '✓' : ''}</span>
              </button>
            {/each}
          </div>
          <div class="out" aria-live="polite">
            <p class="what">{what}</p>
            <pre>{message}</pre>
            <div class="actions">
              {#if canShare}<button class="button primary" type="button" onclick={share}>Teilen</button>{/if}
              <button class="button {canShare ? 'ghost' : 'primary'}" type="button" onclick={copy}>Kopieren</button>
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
  header { padding: 22px 0; }
  .brand { display: inline-flex; align-items: center; gap: 10px; font-size: 24px; text-decoration: none; color: var(--text); }
  .brand-icon { width: 34px; height: 34px; }
  main { flex: 1; padding: 48px 0 64px; }

  .start { max-width: 700px; }
  .start h1 { font-size: clamp(40px, 7vw, 64px); margin: 0 0 14px; max-width: 13ch; }
  .lede { color: var(--muted); margin: 0 0 34px; font-size: 17px; }
  .field { display: flex; align-items: center; gap: 12px; padding: 8px 8px 8px 18px; border-radius: 22px; background: rgb(255 255 255 / .05); border: 1px solid var(--border-strong); }
  .field:focus-within { border-color: color-mix(in srgb, var(--accent) 60%, transparent); }
  .src { width: 26px; height: 26px; display: grid; place-items: center; color: var(--muted); flex-shrink: 0; }
  #song { flex: 1; min-width: 0; border: 0; background: none; outline: none; color: var(--text); font-size: 17px; padding: 14px 0; }
  #song::placeholder { color: #6E6C76; }
  .detected { margin: 10px 0 0 18px; font-size: 14px; color: var(--muted); min-height: 22px; }
  .detected b { color: var(--text); font-weight: 600; }
  .loading { display: inline-flex; align-items: center; gap: 10px; }
  .spinner { width: 18px; height: 18px; border-radius: 50%; background: conic-gradient(from 0deg, transparent 0 25%, #80CD84, #57C6BB); mask: radial-gradient(circle, transparent 6px, #000 7px); animation: spin .9s linear infinite; }
  @keyframes spin { to { transform: rotate(1turn); } }
  .error { display: block; padding-left: 12px; border-left: 3px solid var(--error); color: var(--muted); }
  .error strong { color: var(--text); font-weight: 600; }
  .people { margin-top: 30px; padding-top: 22px; border-top: 1px solid var(--border); }
  .note { margin-top: 32px; color: var(--muted); font-size: 13px; }

  .record { display: grid; grid-template-columns: 340px minmax(0, 1fr); gap: 44px; align-items: start; animation: rise .45s ease-out; }
  @keyframes rise { from { opacity: 0; transform: translateY(10px); } }
  .record > div { min-width: 0; }
  .cover { width: 340px; height: 340px; border-radius: 16px; object-fit: cover; box-shadow: 0 40px 80px -30px rgb(0 0 0 / .9); position: sticky; top: 24px; }
  .placeholder { display: grid; place-items: center; background: var(--raised); font-size: 72px; color: var(--muted); }
  .meta { color: var(--muted); font-size: 14px; }
  .record h1 { font-size: clamp(40px, 5.6vw, 64px); margin: 6px 0 4px; overflow-wrap: anywhere; }
  .artist { font-size: 18px; margin: 0 0 18px; color: rgb(242 240 234 / .8); }
  .newlink { border: 0; background: none; color: var(--muted); font-size: 13px; text-decoration: underline; text-underline-offset: 3px; padding: 0; margin-bottom: 22px; }

  .tiles { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; }
  .tile { position: relative; display: flex; align-items: center; gap: 14px; padding: 16px 18px; border-radius: 18px; background: rgb(255 255 255 / .06); border: 1px solid var(--border); color: var(--text); text-align: left; min-width: 0; }
  .tile:hover { background: rgb(255 255 255 / .1); }
  .tile > span:not(.check) { min-width: 0; }
  .tile strong { display: block; font-weight: 650; padding-right: 18px; }
  .tile small { display: block; color: var(--muted); font-size: 12.5px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .tile[aria-pressed="true"] { background: linear-gradient(rgb(36 35 42 / .92), rgb(36 35 42 / .92)) padding-box, var(--gradient) border-box; border-color: transparent; }
  .tile.missing { opacity: .6; }
  .check { position: absolute; top: 10px; right: 12px; width: 20px; height: 20px; border-radius: 50%; border: 1.5px solid var(--border-strong); display: grid; place-items: center; font-size: 12px; color: var(--ink); }
  .tile[aria-pressed="true"] .check { background: var(--raised); color: var(--text); border-color: var(--accent); }

  .out { margin-top: 18px; padding: 16px 18px; border-radius: 18px; background: rgb(0 0 0 / .25); border: 1px solid var(--border); }
  .what { font-size: 13px; color: var(--muted); margin: 0 0 8px; }
  pre { margin: 0 0 14px; font: inherit; font-size: 14px; line-height: 1.6; white-space: pre-wrap; overflow-wrap: anywhere; }
  .actions { display: flex; gap: 8px; flex-wrap: wrap; }

  @media(max-width: 860px) {
    .shell { padding: 0 18px; }
    main { padding: 24px 0 40px; }
    .lede { font-size: 16px; margin-bottom: 26px; }
    #song { font-size: 16px; }
    .record { grid-template-columns: minmax(0, 1fr); gap: 18px; }
    .cover { position: static; width: 100%; height: auto; aspect-ratio: 1; max-width: 220px; }
    .record h1 { font-size: 36px; }
    .tile { padding: 14px; gap: 10px; }
    .actions .button { flex: 1; }
  }
</style>
