<script lang="ts">
  import type { Friend } from '@app/shared';
  import Logo from './Logo.svelte';
  let { friend, size = 28 }: { friend: Friend; size?: number } = $props();
  // A steady colour per name, so a friend looks the same everywhere
  const hue = $derived([...friend.name].reduce((sum, char) => (sum * 31 + char.charCodeAt(0)) % 360, 7));
</script>

<span class="avatar" aria-hidden="true" style:--h={hue} style:width="{size}px" style:height="{size}px" style:font-size="{Math.round(size * 0.4)}px">
  {friend.name[0]?.toUpperCase()}<span class="badge"><Logo platform={friend.platform} size={Math.round(size * 0.38)} /></span>
</span>

<style>
  .avatar { position: relative; display: inline-grid; place-items: center; flex-shrink: 0; border-radius: 50%; background: hsl(var(--h) 35% 30%); color: hsl(var(--h) 60% 88%); font-weight: 700; line-height: 1; }
  .badge { position: absolute; right: -3px; bottom: -3px; display: grid; place-items: center; padding: 2px; border-radius: 50%; background: var(--bg); }
</style>
