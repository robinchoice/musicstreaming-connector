<script lang="ts">
  import { onMount } from 'svelte';
  import { page } from '$app/state';
  import { inviteSlugs, platforms, type Platform } from '@app/shared';
  import { addFriend, inviteUrl, loadFriends, setMe, social } from '$lib/friends.svelte';
  import { toast, toastError } from '$lib/toast.svelte';

  // Someone who sent an invite or a song: save them, then send your own service back
  let { name, platform, heading = 'h1' }: { name: string; platform: Platform; heading?: 'h1' | 'h2' } = $props();
  let saved = $state(false);
  let myName = $state('');
  onMount(() => {
    loadFriends();
    saved = social.friends.some(friend => friend.name === name && friend.platform === platform);
    myName = social.me?.name ?? '';
  });

  function save() {
    addFriend({ name, platform });
    saved = true;
  }

  async function answer(mine: Platform) {
    if (!myName.trim()) { toastError('Gib zuerst deinen Namen ein.'); return; }
    const me = { name: myName.trim().slice(0, 40), platform: mine };
    setMe(me);
    const url = inviteUrl(page.url.origin, me);
    const text = `Ich höre auf ${platforms[mine]}. Speicher mich in Songgate, dann bekomme ich deine Songs immer passend:`;
    try {
      if (typeof navigator.share === 'function') await navigator.share({ text, url });
      else { await navigator.clipboard.writeText(`${text}\n${url}`); toast('Einladung kopiert. Schick sie an ' + name + '.'); }
    } catch (e) { if (!(e instanceof DOMException && e.name === 'AbortError')) toastError('Teilen nicht möglich.'); }
  }
</script>

<span class="avatar" aria-hidden="true">{name[0]?.toUpperCase()}<span class="dot {platform}"></span></span>
<svelte:element this={heading} class="title">{name} hört auf {platforms[platform]}</svelte:element>
<p>Speicher {name}, dann landen deine Songs bei {name} immer direkt in {platforms[platform]}.</p>
<div class="actions">
  <a class="button primary" href="musiclink://app/friend?{new URLSearchParams({ name, service: inviteSlugs[platform] })}">In der Songgate-App speichern</a>
  <button class="secondary" onclick={save} disabled={saved}>{saved ? `✓ ${name} ist gespeichert` : 'Hier im Browser speichern'}</button>
</div>
<div class="answer">
  <h3>Und du?</h3>
  <p>Schick {name} deinen Dienst zurück, dann klappt es in beide Richtungen.</p>
  <input bind:value={myName} maxlength="40" placeholder="Dein Name" autocomplete="given-name" />
  <div class="services">
    {#each (Object.keys(platforms) as Platform[]) as mine}
      <button onclick={() => answer(mine)}><span class="dot {mine}"></span>{platforms[mine]}</button>
    {/each}
  </div>
</div>

<style>
  .avatar { position: relative; display: inline-grid; place-items: center; width: 76px; height: 76px; border-radius: 50%; background: var(--raised); color: var(--accent); font-size: 28px; font-weight: 750; }
  .avatar .dot { position: absolute; right: -2px; bottom: -2px; width: 24px; height: 24px; border: 3px solid var(--surface); }
  .title { font-size: 30px; margin: 16px 0 6px; overflow-wrap: anywhere; }
  p { color: var(--muted); font-size: 13px; margin: 0; }
  .actions { display: grid; gap: 10px; margin-top: 20px; }
  .button, button { border: 1px solid transparent; border-radius: 10px; padding: 14px; font-size: 14px; font-weight: 650; text-decoration: none; }
  .primary { background: var(--gradient); color: var(--ink); }
  .secondary { background: var(--raised); color: var(--text); border-color: var(--border); }
  .answer { margin-top: 28px; padding-top: 22px; border-top: 1px solid var(--border); }
  h3 { font-family: inherit; font-size: 12px; letter-spacing: 1.2px; text-transform: uppercase; color: var(--accent); margin: 0 0 6px; }
  input { width: 100%; margin-top: 14px; border: 1px solid var(--border); background: var(--bg); color: var(--text); border-radius: 8px; padding: 12px; }
  .services { display: grid; grid-template-columns: 1fr 1fr; gap: 8px; margin-top: 10px; }
  .services button { display: flex; align-items: center; gap: 8px; background: #1B1A20; color: var(--text); border-color: var(--border); font-weight: 500; font-size: 13px; padding: 11px; }
  .dot { display: inline-block; width: 18px; height: 18px; border-radius: 5px; }
  .appleMusic { background: #FA2D48; } .youtubeMusic { background: #FF0033; } .spotify { background: #1DB954; } .deezer { background: #A238FF; }
</style>
