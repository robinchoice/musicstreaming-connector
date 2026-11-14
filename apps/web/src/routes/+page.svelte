<script lang="ts">
  import Logo from '#lib/components/Logo.svelte';
  import PleasanceFooter from '#lib/components/PleasanceFooter.svelte';
  import { APP_STORE_URL, PLAY_STORE_URL, serviceOrder } from '@app/shared';
  import { page } from '$app/state';
  import { t } from '#lib/i18n.ts';

  let { data } = $props();
  const locale = $derived(page.data.locale);
</script>

{#snippet appStore()}<a class="badge" href={APP_STORE_URL} rel="noreferrer"><img src="/badges/app-store-{locale}.svg" alt={t().appStore} height="54" /></a>{/snippet}
{#snippet googlePlay()}<a class="badge" href={PLAY_STORE_URL} rel="noreferrer"><img src="/badges/google-play-{locale}.png" alt={t().googlePlay} height="54" /></a>{/snippet}

<div class="shell">
  <header><a href="/" class="brand"><img class="brand-icon" src="/favicon.svg" alt="" width="30" height="30" /> Songgate</a></header>
  <main>
    <img class="icon" src="/favicon.svg" alt="" width="76" height="76" />
    <h1>{t().headline}</h1>
    <p class="lede">{t().lede}</p>
    <div class="services" aria-hidden="true">{#each serviceOrder.filter(platform => platform !== 'amazonMusic') as platform (platform)}<Logo {platform} size={26} />{/each}</div>
    <nav class="badges" aria-label={t().getApp}>
      {#if data.device !== 'android'}{@render appStore()}{/if}
      {#if data.device !== 'ios'}{@render googlePlay()}{/if}
    </nav>
    <a class="web" href="/app">{t().openInBrowser} →</a>
    {#if data.device}<p class="other">{t().otherPhone(data.device)} <a href={data.device === 'ios' ? PLAY_STORE_URL : APP_STORE_URL} rel="noreferrer">{data.device === 'ios' ? 'Google Play' : 'App Store'}</a></p>{/if}
  </main>
  <PleasanceFooter />
</div>

<style>
  .shell { max-width: 1040px; min-height: 100dvh; margin: auto; padding: 0 32px; display: flex; flex-direction: column; }
  header { padding: 20px 0; }
  .brand { display: inline-flex; align-items: center; gap: 9px; font-size: 22px; text-decoration: none; color: var(--text); }
  main { flex: 1; display: flex; flex-direction: column; align-items: center; justify-content: center; text-align: center; padding: 8px 0 32px; }
  .icon { width: 76px; height: 76px; border-radius: 18px; box-shadow: 0 18px 50px -18px rgb(100 204 158 / .4); margin-bottom: 22px; }
  h1 { font-size: clamp(36px, 6vw, 60px); margin: 0 0 14px; max-width: 20ch; }
  .lede { color: var(--muted); font-size: 17px; max-width: 36ch; margin: 0 0 20px; }
  .services { display: flex; gap: 14px; margin-bottom: 30px; }
  .badges { display: flex; flex-wrap: wrap; justify-content: center; gap: 12px; margin-bottom: 18px; }
  .badge { display: block; line-height: 0; border-radius: 10px; transition: transform .15s; }
  .badge:hover { transform: translateY(-1px); }
  .badge img { height: 54px; width: auto; }
  .web { color: var(--muted); font-size: 15px; text-decoration: none; border-bottom: 1px solid var(--border-strong); padding-bottom: 1px; }
  .web:hover { color: var(--text); }
  .other { margin: 12px 0 0; font-size: 13px; color: var(--muted); }
  .other a { color: var(--text); }

  @media(max-width: 650px) {
    .shell { padding: 0 18px; }
    header { padding: 14px 0; }
    .icon { width: 60px; height: 60px; margin-bottom: 16px; }
    h1 { font-size: 36px; }
    .lede { font-size: 16px; margin-bottom: 18px; }
    .services { margin-bottom: 24px; }
  }
  /* Short phone screens behind browser bars: everything stays on one screen */
  @media(max-height: 720px) {
    .icon { display: none; }
    main { padding-bottom: 16px; }
  }
</style>
