<script lang="ts">
  import type { Snippet } from 'svelte';
  import PleasanceFooter from './PleasanceFooter.svelte';

  let { title, children }: { title: string; children: Snippet } = $props();
</script>

<svelte:head><title>{title} · MusicLink</title></svelte:head>

<div class="shell">
  <header><a href="/" class="brand"><img class="brand-icon" src="/favicon.svg" alt="" width="42" height="42" /> MusicLink</a></header>
  <main>
    <h1>{title}</h1>
    {@render children()}
  </main>
  <PleasanceFooter />
</div>

<style>
  .shell { max-width: 1120px; min-height: 100dvh; margin: auto; padding: 0 40px; display: flex; flex-direction: column; }
  header { padding: 24px 0; border-bottom: 1px solid var(--border); }
  .brand { display: inline-flex; align-items: center; gap: 11px; font-size: 28px; text-decoration: none; color: var(--text); }
  .brand-icon { width: 42px; height: 42px; }
  main { width: 100%; max-width: 720px; margin: 0 auto; flex: 1; padding: 48px 0 64px; font-size: 15px; }
  h1 { font-size: 44px; margin: 0 0 28px; }
  main :global(h2) { font-size: 22px; margin: 36px 0 10px; }
  main :global(p), main :global(li) { color: var(--muted); line-height: 1.7; }
  main :global(strong) { color: var(--text); font-weight: 600; }
  @media(max-width: 650px) {
    .shell { padding: 0 22px; } header { padding: 20px 0; } .brand { font-size: 26px; } .brand-icon { width: 38px; height: 38px; }
    main { padding: 32px 0 48px; font-size: 14px; } h1 { font-size: 34px; }
  }
</style>
