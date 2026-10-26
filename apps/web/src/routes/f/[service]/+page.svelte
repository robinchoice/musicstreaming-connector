<script lang="ts">
  import { page } from '$app/state';
  import Connect from '$lib/components/Connect.svelte';
  import PleasanceFooter from '$lib/components/PleasanceFooter.svelte';
  import { platformForSlug } from '$lib/friends.svelte';
  import { platforms } from '@app/shared';

  const platform = platformForSlug(page.params.service ?? '');
  const name = (page.url.searchParams.get('name') ?? '').trim().slice(0, 40);
</script>

<svelte:head>
  <title>{platform && name ? `${name} hört auf ${platforms[platform]}` : 'Einladung'} · Songgate</title>
</svelte:head>

<div class="shell">
  <header><a href="/" class="brand"><img class="brand-icon" src="/favicon.svg" alt="" width="34" height="34" /> Songgate</a></header>
  <main>
    {#if !platform || !name}
      <section class="card"><h1>Diese Einladung ist unvollständig.</h1><p>Bitte um einen neuen Einladungslink.</p></section>
    {:else}
      <section class="card"><Connect {name} {platform} /></section>
    {/if}
  </main>
  <PleasanceFooter />
</div>

<style>
  .shell { max-width: 560px; min-height: 100dvh; margin: auto; padding: 0 22px; display: flex; flex-direction: column; }
  header { padding: 22px 0; }
  .brand { display: inline-flex; align-items: center; gap: 10px; font-size: 24px; text-decoration: none; color: var(--text); }
  main { flex: 1; padding: 30px 0; }
  .card { background: rgb(255 255 255 / .04); border: 1px solid var(--border); border-radius: 22px; padding: 26px 22px; }
  h1 { font-size: 30px; margin: 16px 0 6px; overflow-wrap: anywhere; }
  p { color: var(--muted); font-size: 13px; margin: 0; }
</style>
