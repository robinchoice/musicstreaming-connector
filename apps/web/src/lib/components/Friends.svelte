<script lang="ts">
  import { onMount } from 'svelte';
  import { platforms, type Platform } from '@app/shared';
  import { addFriend, addGroup, inviteUrl, loadFriends, removeFriend, setMe, social } from '$lib/friends.svelte';
  import { toast, toastError } from '$lib/toast.svelte';

  let { selected = $bindable([]), disabled = false }: { selected: string[]; disabled?: boolean } = $props();
  let panel = $state<'' | 'add' | 'group' | 'invite' | 'edit'>('');
  let name = $state('');
  let platform = $state<Platform>('spotify');
  onMount(loadFriends);

  const toggle = (friend: string) => selected = selected.includes(friend) ? selected.filter(other => other !== friend) : [...selected, friend];
  const groupOn = (members: string[]) => members.length === selected.length && members.every(member => selected.includes(member));
  const open = (next: typeof panel) => { panel = panel === next ? '' : next; name = next === 'invite' ? social.me?.name ?? '' : ''; platform = next === 'invite' ? social.me?.platform ?? 'spotify' : 'spotify'; };

  function submit(event: SubmitEvent) {
    event.preventDefault();
    const value = name.trim().slice(0, 40);
    if (!value) return;
    if (panel === 'add') { addFriend({ name: value, platform }); selected = [...selected.filter(other => other !== value), value]; }
    if (panel === 'group') addGroup(value, selected);
    if (panel === 'invite') { invite(value); return; }
    panel = '';
  }

  async function invite(value: string) {
    const me = { name: value, platform };
    setMe(me);
    const url = inviteUrl(location.origin, me);
    const text = `Ich höre auf ${platforms[platform]}. Speicher mich in MusicLink, dann bekomme ich deine Songs immer passend:`;
    try {
      if (typeof navigator.share === 'function') await navigator.share({ text, url });
      else { await navigator.clipboard.writeText(`${text}\n${url}`); toast('Einladung kopiert.'); }
      panel = '';
    } catch (e) { if (!(e instanceof DOMException && e.name === 'AbortError')) toastError('Teilen nicht möglich.'); }
  }
</script>

<div class="friends">
  <div class="head"><span>Für wen? <small>optional</small></span>
    <span class="links">{#if social.friends.length}<button type="button" onclick={() => open('edit')}>{panel === 'edit' ? 'Fertig' : 'Bearbeiten'}</button>{/if}<button type="button" onclick={() => open('invite')}>Meine Einladung</button></span>
  </div>
  <div class="row">
    {#each social.friends as friend (friend.name)}
      {#if panel === 'edit'}
        <button type="button" class="friend" onclick={() => { removeFriend(friend.name); selected = selected.filter(other => other !== friend.name); }} aria-label="{friend.name} entfernen"><span class="avatar">{friend.name[0]?.toUpperCase()}<span class="remove">×</span></span>{friend.name}</button>
      {:else}
        <button type="button" class="friend" class:on={selected.includes(friend.name)} aria-pressed={selected.includes(friend.name)} {disabled} onclick={() => toggle(friend.name)} title={platforms[friend.platform]}>
          <span class="avatar">{friend.name[0]?.toUpperCase()}<span class="dot {friend.platform}"></span></span>{friend.name}
        </button>
      {/if}
    {/each}
    <button type="button" class="friend add" {disabled} onclick={() => open('add')}><span class="avatar">+</span>Neu</button>
  </div>
  {#if social.groups.length || selected.length > 1}
    <div class="groups">
      {#each social.groups as group (group.name)}
        <button type="button" class="chip" class:on={groupOn(group.members)} {disabled} onclick={() => selected = groupOn(group.members) ? [] : group.members.filter(member => social.friends.some(friend => friend.name === member))}>{group.name}</button>
      {/each}
      {#if selected.length > 1}<button type="button" class="chip" onclick={() => open('group')}>+ Gruppe aus Auswahl</button>{/if}
    </div>
  {/if}
  {#if panel === 'add' || panel === 'group' || panel === 'invite'}
    <form class="panel" onsubmit={submit}>
      <p>{panel === 'add' ? 'Freund von Hand anlegen. Schneller geht es, wenn er dir seinen Einladungslink schickt.' : panel === 'group' ? `Gruppe aus ${selected.join(', ')}` : 'Dein Dienst und Name für deinen Einladungslink.'}</p>
      <input bind:value={name} maxlength="40" placeholder={panel === 'group' ? 'Name der Gruppe, z. B. WG' : panel === 'invite' ? 'Dein Name' : 'Name'} required />
      {#if panel !== 'group'}<select bind:value={platform}>{#each Object.keys(platforms) as Platform[] as key}<option value={key}>{platforms[key]}</option>{/each}</select>{/if}
      <button type="submit">{panel === 'invite' ? 'Einladung teilen ↗' : 'Speichern'}</button>
    </form>
  {/if}
</div>

<style>
  .friends { margin-top: 18px; padding-top: 16px; border-top: 1px solid var(--border); }
  .head { display: flex; justify-content: space-between; align-items: center; font-size: 13px; font-weight: 650; }
  .head small { color: var(--muted); font-weight: 400; }
  .links { display: flex; gap: 14px; }
  .links button { background: none; border: 0; padding: 0; color: var(--muted); font-size: 12px; font-weight: 500; text-decoration: underline; text-underline-offset: 3px; }
  .row { display: flex; gap: 12px; overflow-x: auto; padding: 12px 2px 4px; }
  .friend { display: flex; flex-direction: column; align-items: center; gap: 5px; width: 60px; flex-shrink: 0; background: none; border: 0; padding: 0; color: var(--text); font-size: 11.5px; }
  .avatar { position: relative; display: grid; place-items: center; width: 48px; height: 48px; border-radius: 50%; background: var(--raised); color: var(--accent); font-size: 17px; font-weight: 750; border: 2px solid transparent; }
  .friend.on .avatar { border-color: var(--accent); box-shadow: 0 0 0 3px color-mix(in srgb, var(--accent) 25%, transparent); }
  .add .avatar { border: 1.5px dashed var(--muted); color: var(--muted); }
  .dot, .remove { position: absolute; right: -3px; bottom: -3px; width: 18px; height: 18px; border-radius: 5px; border: 2px solid var(--surface); }
  .remove { display: grid; place-items: center; background: var(--error); color: var(--ink); font-size: 12px; border-radius: 50%; }
  .appleMusic { background: #FA2D48; } .youtubeMusic { background: #FF0033; } .spotify { background: #1DB954; } .deezer { background: #A238FF; }
  .groups { display: flex; gap: 6px; flex-wrap: wrap; margin-top: 8px; }
  .chip { border: 1px solid var(--border); background: var(--raised); color: var(--text); border-radius: 99px; padding: 6px 11px; font-size: 12px; }
  .chip.on { border-color: var(--accent); color: var(--accent); }
  .panel { display: flex; flex-wrap: wrap; gap: 8px; margin-top: 12px; align-items: center; }
  .panel p { width: 100%; margin: 0; font-size: 12px; color: var(--muted); }
  .panel input, .panel select { flex: 1; min-width: 140px; border: 1px solid var(--border); background: var(--bg); color: var(--text); border-radius: 8px; padding: 10px; }
  .panel button { border: 0; border-radius: 8px; padding: 10px 14px; background: var(--gradient); color: var(--ink); font-weight: 650; }
</style>
