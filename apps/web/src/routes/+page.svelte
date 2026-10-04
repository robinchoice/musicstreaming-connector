<script lang="ts">
  import { onDestroy, onMount } from 'svelte';
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
  <header><a href="/" class="brand"><span class="brand-icon" aria-hidden="true">↗</span> MusicLink</a><span class="header-note">Gute Musik kennt keine Plattform.</span><span class="badge">OHNE ANMELDUNG</span></header>
  <main>
    <section class="intro">
      <div class="eyebrow"><span></span> EIN SONG. MEHR VERBINDUNG.</div>
      <h1>Dein Musikgeschmack.<br /><span>Ihr Lieblingsplayer.</span></h1>
      <p>YouTube Music oder Apple Music?<br class="desktop" /> Schick ihnen einfach den passenden Link.</p>
    </section>

    <section class="converter" aria-label="Musiklink umwandeln">
      <div class="route"><span>♪ Musik teilen</span><span class="arrow" aria-hidden="true">⟶</span><span>{platforms[target]}</span></div>
      <form onsubmit={convert}>
        <label for="song">Welchen Song möchtest du teilen?</label>
        <div class="input-row"><input id="song" name="song" bind:value={input} oninput={sourceChanged} required maxlength="4096" placeholder="YouTube-Music- oder Apple-Music-Link" autocomplete="off" spellcheck="false" disabled={loading} /><button class="primary" type="submit" disabled={loading || !input.trim()}>{loading ? 'Suche läuft …' : 'Link umwandeln'} <span aria-hidden="true">↗</span></button></div>
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
            <div class="candidate selected">{@render track(selected, conversion.target)}</div>
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

    <section class="steps" aria-label="So funktioniert’s"><div><span>01</span><h2>Song mitbringen</h2><p>Den Link in deiner Musik-App über „Teilen“ kopieren.</p></div><div><span>02</span><h2>Aufnahme finden</h2><p>Wir suchen den passenden Song und zeigen dir die Treffer.</p></div><div><span>03</span><h2>Freude weitergeben</h2><p>Passenden Link kopieren und mit deinen Menschen teilen.</p></div></section>
    <aside><span aria-hidden="true">↔</span><p><strong>Dein Song bleibt dein Song.</strong> Live-Versionen und Remixe werden beim Titelabgleich berücksichtigt. Gibt es keinen passenden Treffer, sagen wir dir das.</p></aside>
  </main>
  <footer><span>MusicLink <span class="muted">/ Musik verbindet.</span></span><p>Ohne Konto. Ohne gespeicherte Song-Historie. Der Link geht an unseren Dienst; Apple und YouTube liefern Song-Metadaten; bei Spotify zusätzlich ListenBrainz.</p></footer>
</div>

<style>
  .shell { max-width: 1120px; margin: auto; padding: 0 40px; }
  header { display:flex; align-items:center; justify-content:space-between; padding:30px 0; border-bottom:1px solid var(--border); gap:20px; }
  .brand { display:flex; align-items:center; gap:10px; font-size:22px; font-weight:760; text-decoration:none; letter-spacing:-.7px; }
  .brand-icon { width:35px; height:35px; display:grid; place-items:center; background:#253828; color:#d5f8a5; border-radius:10px; font-size:26px; }
  .header-note { color:var(--muted); font-size:13px; }
  .badge { font-size:10px; letter-spacing:1px; border:1px solid var(--border); border-radius:99px; padding:7px 10px; }
  main { max-width:800px; margin:auto; }
  .intro { text-align:center; padding:66px 0 34px; }
  .eyebrow { font-size:10px; letter-spacing:1.8px; font-weight:700; color:#65765b; }
  .eyebrow span { display:inline-block; width:6px; height:6px; background:#7aab4c; border-radius:50%; margin-right:8px; }
  h1 { font-size:clamp(32px,4.5vw,52px); letter-spacing:-2px; line-height:1.13; margin:20px 0; font-weight:730; }
  h1 span { color:#74816a; }
  .intro p { color:var(--muted); font-size:16px; line-height:1.7; }
  .converter { background:white; border:1px solid var(--border); padding:30px; border-radius:20px; box-shadow:0 10px 45px #27312407; }
  .route { display:flex; align-items:center; gap:20px; padding-bottom:25px; margin-bottom:25px; border-bottom:1px solid #edf0e9; font-size:14px; font-weight:650; }
  .route > span { display:flex; gap:8px; align-items:center; }
  .settings { display:flex; flex-wrap:wrap; gap:16px; margin-top:16px; font-size:12px; }
  .settings label { display:flex; gap:8px; align-items:center; }
  select { max-width:100%; border:1px solid var(--border); border-radius:8px; padding:8px; background:#fbfcf9; }
  .route .arrow { color:#9aa193; font-size:25px; font-weight:400; }
  form > label { display:block; font-size:14px; font-weight:650; margin-bottom:12px; }
  .input-row { display:flex; gap:10px; }
  #song { min-width:0; flex:1; border:1px solid #d6dcd0; border-radius:9px; padding:14px; background:#fbfcf9; font-size:14px; }
  button { border:0; border-radius:9px; padding:14px 18px; font-size:13px; font-weight:650; }
  .primary { background:#d3efa5; color:#24381e; }
  .primary:hover:not(:disabled) { background:#c4e892; }
  .primary span { margin-left:12px; }
  .secondary { background:#eff1e9; color:#24381e; }
  .hint { font-size:11px; color:var(--muted); margin:12px 0 0; }
  .steps { display:grid; grid-template-columns:repeat(3,1fr); gap:34px; padding:36px 12px; }
  .steps span { color:#87947c; font-size:11px; font-weight:650; }
  .steps h2 { font-size:14px; font-weight:650; margin:10px 0 6px; }
  .steps p { color:var(--muted); font-size:12px; margin:0; line-height:1.7; }
  aside { display:flex; gap:18px; align-items:center; background:#eaede3; border-radius:12px; padding:18px 22px; margin-bottom:50px; }
  aside > span { color:#70805e; font-size:28px; }
  aside p { color:#697460; font-size:12px; margin:0; line-height:1.7; }
  aside strong { color:#425039; }
  footer { border-top:1px solid var(--border); padding:22px 0; display:flex; justify-content:space-between; gap:40px; font-size:11px; }
  footer > span { white-space:nowrap; padding-top:2px; }
  footer p { margin:0; color:#7b8276; max-width:430px; line-height:1.7; }
  .muted { color:#8a9184; }
  .status { padding:34px 10px 8px; text-align:center; font-size:14px; }
  .status p { font-size:12px; color:var(--muted); }
  .spinner { display:block; width:24px; height:24px; border:2px solid #e0e5d8; border-top-color:#72944e; border-radius:50%; animation:spin 1s linear infinite; margin:0 auto 14px; }
  @keyframes spin { to { transform:rotate(360deg); } }
  @media (prefers-reduced-motion:reduce) { .spinner { animation:none; } }
  .error { padding:18px; background:#fff3ef; color:#9d4232; border-radius:10px; margin-top:25px; font-size:13px; }
  .error p { margin:6px 0 0; }
  .results { margin-top:28px; border-top:1px solid var(--border); padding-top:24px; }
  .source h2 { font-size:20px; margin:8px 0 2px; }
  .source p { color:var(--muted); margin:0 0 24px; font-size:14px; }
  .legend { font-size:12px; font-weight:650; margin:0 0 10px; }
  .candidate { display:flex; align-items:center; gap:12px; border:1px solid var(--border); border-radius:10px; padding:12px; margin-bottom:8px; }
  .candidate.selected { border-color:#9ab977; background:#f6faef; }
  .candidate.other { width:100%; background:white; color:inherit; font:inherit; text-align:left; cursor:pointer; }
  .candidate.other:hover { background:#f6faef; }
  details { margin-top:4px; }
  summary { font-size:12px; font-weight:650; color:var(--muted); cursor:pointer; padding:6px 0 10px; }
  .candidate img, .artwork { width:46px; height:46px; object-fit:cover; border-radius:6px; }
  .artwork { display:grid; place-items:center; background:#e7eddd; font-size:26px; }
  .track { display:flex; flex:1; flex-direction:column; font-size:14px; }
  .track small { color:var(--muted); font-size:11px; }
  .actions { display:flex; gap:10px; align-items:center; flex-wrap:wrap; margin-top:20px; }
  .actions a { font-size:12px; margin-left:auto; }
  @media(max-width:650px) { .shell { padding:0 20px; } header { padding:20px 0; } .header-note { display:none; } .badge { font-size:8px; } .intro { padding:42px 0 25px; } h1 { letter-spacing:-1.2px; } .intro p { font-size:14px; } .desktop { display:none; } .converter { padding:20px; } .input-row { flex-direction:column; } .route { gap:12px; font-size:12px; } .steps { gap:18px; padding:28px 0; } .steps h2 { font-size:12px; } .steps p { font-size:11px; } aside { padding:15px; margin-bottom:32px; } footer { flex-direction:column; gap:12px; } }
</style>
