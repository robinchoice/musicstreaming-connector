<script lang="ts">
  import { onMount } from 'svelte';
  import { page } from '$app/state';
  import { inviteSlugs, platforms, type Platform } from '@app/shared';
  import { addFriend, inviteUrl, loadFriends, setMe, social } from '$lib/friends.svelte';
  import { toast, toastError } from '$lib/toast.svelte';
  import Avatar from './Avatar.svelte';
  import Logo from './Logo.svelte';

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

<div class="who">
  <Avatar friend={{ name, platform }} size={heading === 'h1' ? 64 : 44} />
  <div>
    <svelte:element this={heading} class="title">{name} hört auf {platforms[platform]}</svelte:element>
    <p>Speicher {name}, dann landen deine Songs bei {name} immer direkt in {platforms[platform]}.</p>
  </div>
</div>
<div class="actions">
  <a class="button primary" href="musiclink://app/friend?{new URLSearchParams({ name, service: inviteSlugs[platform] })}">In der Songgate-App speichern</a>
  <button class="button ghost" onclick={save} disabled={saved}>{saved ? `✓ ${name} ist gespeichert` : 'Hier im Browser speichern'}</button>
</div>
<div class="answer">
  <h3>Und du?</h3>
  <p>Schick {name} deinen Dienst zurück, dann klappt es in beide Richtungen.</p>
  <input bind:value={myName} maxlength="40" placeholder="Dein Name" autocomplete="given-name" />
  <div class="services">
    {#each (Object.keys(platforms) as Platform[]) as mine}
      <button onclick={() => answer(mine)}><Logo platform={mine} size={22} />{platforms[mine]}</button>
    {/each}
  </div>
</div>

<style>
  .who { display: flex; align-items: center; gap: 16px; text-align: left; }
  .title { font-size: 28px; margin: 0 0 4px; overflow-wrap: anywhere; }
  h2.title { font-size: 22px; }
  p { color: var(--muted); font-size: 14px; margin: 0; }
  .actions { display: flex; flex-wrap: wrap; gap: 8px; margin-top: 18px; }
  .actions .button { flex: 1; }
  .answer { margin-top: 24px; padding-top: 20px; border-top: 1px solid var(--border); text-align: left; }
  h3 { font-family: inherit; font-size: 14px; font-weight: 600; margin: 0 0 4px; }
  input { width: 100%; margin-top: 14px; border: 1px solid var(--border-strong); background: rgb(0 0 0 / .2); color: var(--text); border-radius: 14px; padding: 12px 14px; }
  .services { display: grid; grid-template-columns: 1fr 1fr; gap: 8px; margin-top: 10px; }
  .services button { display: flex; align-items: center; gap: 10px; border: 1px solid var(--border); border-radius: 14px; background: rgb(255 255 255 / .06); color: var(--text); font-weight: 550; font-size: 14px; padding: 12px; text-align: left; }
  .services button:hover { background: rgb(255 255 255 / .1); }
</style>
