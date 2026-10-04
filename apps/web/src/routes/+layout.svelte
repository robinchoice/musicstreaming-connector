<script lang="ts">
  import Toasts from '$lib/components/Toasts.svelte';
  let { children } = $props();
</script>

<svelte:head><title>MusicLink · Musik verbindet</title><meta name="description" content="Teile Songs zwischen YouTube Music und Apple Music. Ohne Anmeldung." /></svelte:head>
{@render children()}
<Toasts />

<style>
  :global(:root) { color-scheme: light; --bg: #f5f5f0; --surface: #fff; --border: #dddfd6; --text: #202920; --muted: #697165; --error: #a93232; --radius: 12px; }
  :global(*) { box-sizing: border-box; }
  :global(body) { margin: 0; background: var(--bg); color: var(--text); font-family: Inter, ui-sans-serif, system-ui, sans-serif; line-height: 1.5; }
  :global(button), :global(input) { font: inherit; }
  :global(button), :global(a), :global(input) { -webkit-tap-highlight-color: transparent; }
  :global(button) { cursor: pointer; }
  :global(button:disabled) { cursor: default; opacity: .5; }
  :global(a) { color: inherit; }
  :global(:focus-visible) { outline: 3px solid #639638; outline-offset: 4px; }
</style>
