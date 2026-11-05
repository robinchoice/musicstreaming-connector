<script lang="ts">
  import { isPodcast, type Kind, type Platform } from '@app/shared';
  import { applePodcasts, logos } from '#lib/logos.ts';
  let { platform, kind = 'song', size = 24 }: { platform: Platform; kind?: Kind; size?: number } = $props();
  const logo = $derived(platform === 'appleMusic' && isPodcast(kind) ? applePodcasts : logos[platform]);
</script>

<svg class="logo" width={size} height={size} viewBox="0 0 24 24" aria-hidden="true"><path fill={logo.color} d={logo.path} /></svg>

<style>
  .logo { display: block; flex-shrink: 0; }
</style>
