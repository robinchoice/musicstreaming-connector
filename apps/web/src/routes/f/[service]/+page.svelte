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
  <header><a href="/" class="brand"><img class="brand-icon" src="/favicon.svg" alt="" width="38" height="38" /> Songgate</a><span class="badge">Ohne Anmeldung</span></header>
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
  header { display: flex; align-items: center; justify-content: space-between; padding: 22px 0; border-bottom: 1px solid var(--border); }
  .brand { display: flex; align-items: center; gap: 10px; font-size: 26px; text-decoration: none; color: var(--text); }
  .badge { font-size: 11px; border: 1px solid var(--border); border-radius: 99px; padding: 5px 10px; }
  main { flex: 1; padding: 30px 0; }
  .card { background: var(--surface); border: 1px solid var(--border); border-radius: var(--radius); padding: 28px 22px; text-align: center; }
  h1 { font-size: 30px; margin: 16px 0 6px; overflow-wrap: anywhere; }
  p { color: var(--muted); font-size: 13px; margin: 0; }
</style>
