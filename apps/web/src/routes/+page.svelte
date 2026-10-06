<script lang="ts">
  import { onDestroy, onMount } from 'svelte';
  import PleasanceFooter from '$lib/components/PleasanceFooter.svelte';
  import { countries, platforms, targetsFor, type Conversion, type Platform } from '@app/shared';
  import { api, ApiError } from '$lib/api';
  import { toastError } from '$lib/toast.svelte';

  let input = $state('');
  let target = $state<Platform>('appleMusic');
  let country = 'DE';
  let savedTarget: Platform = 'appleMusic';
  const duration = (seconds?: number) => seconds === undefined ? '' : `${Math.floor(seconds / 60)}:${String(Math.round(seconds) % 60).padStart(2, '0')}`;
  function reset() { request?.abort(); loading = false; conversion = null; selection = ''; copied = false; error = ''; searchUrl = ''; }
  function save() { reset(); savedTarget = target; try { localStorage.setItem('musiclink-preferences', JSON.stringify({ target: savedTarget })); } catch {} }
  function sourceChanged(event: Event) {
    input = (event.currentTarget as HTMLInputElement).value;
    reset();
    const targets = targetsFor(input);
    target = targets.includes(savedTarget) ? savedTarget : targets[0]!;
  }
  let loading = $state(false);
  let conversion = $state<Conversion | null>(null);
  let selection = $state('');
  let error = $state('');
  let searchUrl = $state('');
  let copied = $state(false);
  let canShare = $state(false);
  let request: AbortController | undefined;
  onMount(() => {
    canShare = typeof navigator.share === 'function';
    try {
      const saved = JSON.parse(localStorage.getItem('musiclink-preferences') ?? '{}');
      if (['appleMusic', 'youtubeMusic', 'spotify'].includes(saved.target)) target = savedTarget = saved.target;
    } catch {}
    const region = navigator.language.split('-')[1]?.toUpperCase();
    if (countries.some(code => code === region)) country = region!;
  });
  onDestroy(() => request?.abort());

  async function convert(event: SubmitEvent) {
    event.preventDefault();
    request?.abort();
    const current = new AbortController();
    request = current;
    loading = true;
    error = '';
    conversion = null;
    selection = '';
    copied = false;
    searchUrl = '';
    try {
      const result = await api.post<Conversion>('/convert', { input, target, country }, current.signal);
      if (current.signal.aborted) return;
      conversion = result;
      selection = result.candidates[0]!.url;
    } catch (e) {
      if (current.signal.aborted) return;
      error = e instanceof Error ? e.message : 'Die Anfrage ist fehlgeschlagen.';
      searchUrl = e instanceof ApiError ? e.searchUrl ?? '' : '';
    } finally {
      if (!current.signal.aborted) loading = false;
    }
  }

  async function copy(url: string) {
    try { await navigator.clipboard.writeText(url); copied = true; }
    catch { toastError('Kopieren nicht möglich. Öffne den Musiklink und kopiere ihn dort.'); }
  }

  async function share(url: string) {
    try { await navigator.share({ url }); }
    catch (e) { if (!(e instanceof DOMException && e.name === 'AbortError')) toastError('Teilen nicht möglich. Kopiere stattdessen den Link.'); }
  }
</script>

{#snippet track(candidate: Conversion['candidates'][number], target: Platform)}
  {#if candidate.artworkUrl}<img src={candidate.artworkUrl} alt="" referrerpolicy="no-referrer" />{:else}<span class="artwork" aria-hidden="true">♪</span>{/if}
  <span class="track"><strong>{candidate.title}</strong><small>{candidate.album ?? platforms[target]} {duration(candidate.durationSeconds)}</small></span>
{/snippet}

<div class="shell">
  <header><a href="/" class="brand"><img class="brand-icon" src="/favicon.svg" alt="" width="42" height="42" /> MusicLink</a><span class="header-note">Gute Musik kennt keine Plattform.</span><span class="badge">Ohne Anmeldung</span></header>
  <main>
    <section class="intro">
      <div class="eyebrow">EIN SONG. MEHR VERBINDUNG.</div>
      <h1>Dein Musikgeschmack.<br /><span>Ihr Lieblingsplayer.</span></h1>
      <p>Teile Songs aus YouTube Music oder Apple Music.<br /> Als Link für den Lieblingsplayer deiner Menschen.</p>
    </section>

    <section class="converter" aria-label="Musiklink umwandeln">
      <div class="route"><span>♪ Musik teilen</span><span class="arrow" aria-hidden="true">⟶</span><span>{platforms[target]}</span></div>
      <form onsubmit={convert}>
        <label for="song">Welchen Song möchtest du teilen?</label>
        <div class="input-row"><input id="song" name="song" bind:value={input} oninput={sourceChanged} required maxlength="4096" placeholder="YouTube-Music- oder Apple-Music-Link" autocomplete="off" spellcheck="false" disabled={loading} /><button class={conversion || searchUrl ? 'secondary' : 'primary'} type="submit" disabled={loading || !input.trim()}>{loading ? 'Suche läuft …' : 'Link umwandeln'} <span aria-hidden="true">↗</span></button></div>
        <div class="settings"><label>Zieldienst <select bind:value={target} onchange={save} disabled={loading}>{#each targetsFor(input) as key}<option value={key}>{platforms[key]}</option>{/each}</select></label></div>
        <p class="hint">Ein einzelner Song reicht. Tracking-Parameter entfernen wir für dich.</p>
      </form>

      <div aria-live="polite" aria-busy={loading}>
        {#if loading}<div class="status"><span class="spinner"></span><strong>Wir suchen deine Aufnahme auf {platforms[target]}.</strong><p>Das dauert manchmal einen kleinen Moment.</p></div>
        {:else if error}<div class="error" role="alert"><strong>Das hat noch nicht geklappt.</strong><p>{error}</p></div>
          {#if searchUrl}<p class="hint">Teile stattdessen eine Suche nach dem Song.</p><div class="actions"><button class="primary" onclick={() => copy(searchUrl)}>{copied ? 'Suchlink kopiert ✓' : 'Suchlink kopieren'}</button>{#if canShare}<button class="secondary" onclick={() => share(searchUrl)}>Weiterteilen ↗</button>{/if}<a href={searchUrl} target="_blank" rel="noreferrer">Auf {platforms[target]} suchen ↗</a></div>{/if}
        {:else if conversion}
          {@const selected = conversion.candidates.find(candidate => candidate.url === selection)!}
          <div class="results">
            <div class="source"><span class="eyebrow">DEIN SONG</span><h2>{conversion.source.title}</h2><p>{conversion.source.artist}</p></div>
            <p class="legend">Dein Vorschlag auf {platforms[conversion.target]}</p>
            <div class="candidate selected">{@render track(selected, conversion.target)}<span class="checkmark" aria-label="Ausgewählt">✓</span></div>
            {#if conversion.candidates.length > 1}
              <details><summary>Andere Fassungen ({conversion.candidates.length - 1})</summary>
                {#each conversion.candidates.filter(candidate => candidate.url !== selection) as candidate}
                  <button type="button" class="candidate other" onclick={() => { selection = candidate.url; copied = false; }}>{@render track(candidate, conversion.target)}</button>
                {/each}
              </details>
            {/if}
            <p class="hint">Prüfe die gewünschte Aufnahme vor dem Teilen.</p>
            <div class="actions"><button class="primary" onclick={() => copy(selection)}>{copied ? 'Link kopiert ✓' : 'Link kopieren'}</button>{#if canShare}<button class="secondary" onclick={() => share(selection)}>Weiterteilen ↗</button>{/if}<a href={selection} target="_blank" rel="noreferrer">Auf {platforms[conversion.target]} prüfen ↗</a></div>
          </div>
        {/if}
      </div>
    </section>

    <section class="steps" aria-label="So funktioniert’s"><div><span class="step-number">01</span><h2>Song mitbringen</h2><p>Den Link in deiner Musik-App über „Teilen“ kopieren.</p></div><div><span class="step-number">02</span><h2>Aufnahme finden</h2><p>Wir suchen den passenden Song und zeigen dir die Treffer.</p></div><div><span class="step-number">03</span><h2>Freude weitergeben</h2><p>Passenden Link kopieren und mit deinen Menschen teilen.</p></div></section>
    <p class="privacy"><strong>Ohne Konto. Ohne gespeicherte Song-Historie.</strong><br />Dein Link geht an unseren Dienst. Apple und YouTube liefern Song-Metadaten; bei Spotify zusätzlich ListenBrainz.</p>
  </main>
  <PleasanceFooter />
</div>

<style>
  .shell { max-width: 1120px; min-height: 100dvh; margin: auto; padding: 0 40px; display: flex; flex-direction: column; }
  header { display: flex; align-items: center; justify-content: space-between; padding: 24px 0; border-bottom: 1px solid var(--border); gap: 20px; }
  .brand { display: flex; align-items: center; gap: 11px; font-size: 28px; text-decoration: none; color: var(--text); }
  .brand-icon { width: 42px; height: 42px; }
  .header-note { color: var(--muted); font-size: 12px; }
  .badge { font-size: 11px; border: 1px solid var(--border); border-radius: 99px; padding: 5px 10px; white-space: nowrap; }
  main { width: 100%; max-width: 850px; margin: 0 auto; flex: 1; }
  .intro { padding: 52px 0 25px; }
  .eyebrow { font-size: 11px; letter-spacing: 1.4px; font-weight: 650; color: var(--accent); }
  h1 { font-size: clamp(40px, 5.8vw, 65px); margin: 14px 0 18px; }
  h1 span { color: var(--accent); }
  .intro p { color: var(--muted); font-size: 15px; line-height: 1.65; }
  .converter { background: var(--surface); border: 1px solid var(--border); padding: 30px; border-radius: 12px; }
  .route { display: flex; align-items: center; gap: 14px; padding-bottom: 18px; margin-bottom: 21px; border-bottom: 1px solid var(--border); font-size: 13px; font-weight: 600; }
  .route .arrow { color: var(--muted); font-size: 20px; font-weight: 400; }
  .settings { display: flex; flex-wrap: wrap; gap: 16px; margin-top: 13px; font-size: 12px; }
  .settings label { display: flex; gap: 12px; align-items: center; }
  select { max-width: 100%; border: 1px solid var(--border); color: var(--text); border-radius: 8px; padding: 8px; background: var(--bg); }
  form > label { display: block; font-size: 13px; font-weight: 650; margin-bottom: 9px; }
  .input-row { display: flex; gap: 10px; }
  #song { min-width: 0; flex: 1; border: 1px solid var(--border); color: var(--text); border-radius: 8px; padding: 14px 12px; background: var(--bg); font-size: 13px; }
  #song::placeholder { color: var(--muted); }
  button { border: 1px solid transparent; border-radius: 8px; padding: 14px 18px; font-size: 13px; font-weight: 650; }
  .primary { background: var(--gradient); color: var(--ink); }
  .primary:hover:not(:disabled) { filter: brightness(1.04); }
  .primary:disabled { background: var(--raised); color: var(--muted); opacity: 1; }
  .input-row button span { margin-left: 10px; }
  .secondary { background: var(--raised); color: var(--text); border-color: var(--border); }
  .hint { font-size: 11px; color: var(--muted); margin: 12px 0 0; }
  .steps { display: grid; grid-template-columns: repeat(3, 1fr); gap: 28px; margin: 30px 0; }
  .step-number { color: var(--accent); font-size: 28px; display: block; margin-bottom: 12px; }
  .steps h2 { font-size: 20px; margin: 0 0 7px; }
  .steps p { color: var(--muted); font-size: 12px; margin: 0; line-height: 1.65; }
  .privacy { margin: 26px 0; color: var(--muted); font-size: 11px; line-height: 1.65; }
  .privacy strong { color: var(--text); font-weight: 550; }
  .status { padding: 30px 10px 8px; text-align: center; font-size: 14px; }
  .status p { font-size: 12px; color: var(--muted); }
  .spinner { display: block; width: 24px; height: 24px; border: 2px solid var(--border); border-top-color: var(--accent); border-radius: 50%; animation: spin 1s linear infinite; margin: 0 auto 14px; }
  @keyframes spin { to { transform: rotate(360deg); } }
  @media (prefers-reduced-motion: reduce) { .spinner { animation: none; } }
  .error { padding: 5px 15px; border-left: 3px solid var(--error); margin-top: 25px; font-size: 13px; }
  .error p { color: var(--muted); margin: 6px 0 0; }
  .results { margin-top: 24px; border-top: 1px solid var(--border); padding-top: 22px; }
  .source h2 { font-size: 32px; margin: 8px 0 4px; overflow-wrap: anywhere; }
  .source p { color: var(--muted); margin: 0 0 18px; font-size: 14px; }
  .legend { font-size: 12px; color: var(--muted); margin: 0 0 8px; }
  .candidate { display: flex; align-items: center; gap: 13px; border: 1px solid var(--border); border-radius: 10px; padding: 12px; margin-bottom: 8px; background: #1B1A20; }
  .candidate.selected { border-color: color-mix(in srgb, var(--accent) 50%, transparent); }
  .checkmark { color: var(--accent); font-size: 16px; }
  .candidate.other { width: 100%; color: inherit; font: inherit; text-align: left; cursor: pointer; }
  .candidate.other:hover { background: var(--raised); }
  details { margin-top: 8px; }
  summary { font-size: 12px; color: var(--muted); cursor: pointer; padding: 6px 0 10px; }
  .candidate img, .artwork { width: 50px; height: 50px; flex-shrink: 0; object-fit: cover; border-radius: 6px; }
  .artwork { display: grid; place-items: center; background: #302E36; color: var(--text); font-size: 26px; }
  .track { display: flex; flex: 1; min-width: 0; flex-direction: column; font-size: 14px; overflow-wrap: anywhere; }
  .track small { color: var(--muted); font-size: 11px; }
  .actions { display: flex; gap: 10px; align-items: center; flex-wrap: wrap; margin-top: 20px; }
  .actions a { font-size: 12px; margin-left: auto; text-underline-offset: 3px; }
  @media(max-width: 650px) {
    .shell { padding: 0 22px; } header { padding: 20px 0; } .brand { font-size: 26px; } .brand-icon { width: 38px; height: 38px; } .header-note { display: none; } .badge { font-size: 9px; }
    .intro { padding: 34px 0 20px; } h1 { font-size: clamp(34px, 9.8vw, 42px); } .intro p { font-size: 13px; }
    .converter { padding: 20px; } .input-row { flex-direction: column; } .route { gap: 12px; font-size: 12px; }
    .steps { gap: 16px; margin: 27px 0; } .steps h2 { font-size: 17px; } .steps p { font-size: 11px; } .step-number { font-size: 25px; }
    .source h2 { font-size: 27px; } .actions .primary { flex: 1; } .actions a { width: 100%; margin: 6px 0 0; }
  }
</style>
