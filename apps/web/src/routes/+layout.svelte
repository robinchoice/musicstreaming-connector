<script lang="ts">
  import { APP_BAND, bandColor, bandGradient, GLOW } from '@app/shared';
  import Toasts from '$lib/components/Toasts.svelte';
  let { children } = $props();
</script>

<svelte:head><title>MusicLink · Musik verbindet</title><meta name="description" content="Teile Songs zwischen YouTube Music, Apple Music, Spotify und Deezer. Ohne Anmeldung." /></svelte:head>
<div style:--gradient={bandGradient(APP_BAND, GLOW)} style:--accent={bandColor((APP_BAND.from + APP_BAND.to) / 2, GLOW)}>
  {@render children()}
  <Toasts />
</div>

<style>
  @font-face {
    font-family: 'Bricolage Grotesque';
    font-weight: 200 800;
    font-stretch: 75% 100%;
    font-display: swap;
    src: url('/fonts/bricolage-grotesque-latin.woff2') format('woff2');
  }
  @font-face {
    font-family: 'Bricolage Grotesque';
    font-weight: 200 800;
    font-stretch: 75% 100%;
    font-display: swap;
    src: url('/fonts/bricolage-grotesque-latin-ext.woff2') format('woff2');
    unicode-range: U+0100-02BA, U+02BD-02C5, U+02C7-02CC, U+02CE-02D7, U+02DD-02FF, U+0304, U+0308, U+0329, U+1D00-1DBF, U+1E00-1E9F, U+2020, U+20A0-20AB, U+20AD-20C0, U+2113, U+2C60-2C7F, U+A720-A7FF;
  }
  :global(:root) {
    color-scheme: dark;
    --bg: #0E0D12;
    --surface: #16151B;
    --raised: #201F25;
    --border: rgb(255 255 255 / 0.07);
    --text: #F2F0EA;
    --muted: #9A98A3;
    --error: #FFB4AB;
    --ink: #17171A;
    --radius: 12px;
    --font-display: 'Bricolage Grotesque', system-ui, sans-serif;
    --spectrum: linear-gradient(90deg, #F2545B, #FB8C45, #F2C14E, #6CCF8E, #46BFE0, #8E92F8, #C39BF2);
  }
  :global(*) { box-sizing: border-box; }
  :global(body) { margin: 0; background: var(--bg); color: var(--text); font-family: Inter, ui-sans-serif, system-ui, sans-serif; line-height: 1.55; }
  :global(h1), :global(h2), :global(.brand), :global(.step-number) { font-family: var(--font-display); font-weight: 780; font-stretch: 80%; font-variation-settings: 'wdth' 80, 'wght' 780; letter-spacing: -0.035em; line-height: 1.03; }
  :global(button), :global(input), :global(select) { font: inherit; }
  :global(button), :global(a), :global(input), :global(select) { -webkit-tap-highlight-color: transparent; }
  :global(button) { cursor: pointer; }
  :global(button:disabled) { cursor: default; opacity: .5; }
  :global(a) { color: var(--accent); }
  :global(:focus-visible) { outline: 3px solid var(--accent); outline-offset: 4px; }
</style>
