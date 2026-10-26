<script lang="ts">
  import type { Platform } from '@app/shared';
  import { logos } from '$lib/logos';
  let { platform, size = 24 }: { platform: Platform; size?: number } = $props();
</script>

<svg class="logo" width={size} height={size} viewBox="0 0 24 24" aria-hidden="true"><path fill={logos[platform].color} d={logos[platform].path} /></svg>

<style>
  .logo { display: block; flex-shrink: 0; }
</style>
