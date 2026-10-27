<script lang="ts">
  import { onMount } from 'svelte';
  import { renderSVG } from 'uqr';
  import { platforms, type Platform } from '@app/shared';
  import { addFriend, addGroup, inviteUrl, loadFriends, removeFriend, setMe, social } from '$lib/friends.svelte';
  import { t } from '$lib/i18n';
  import { toast, toastError } from '$lib/toast.svelte';
  import Avatar from './Avatar.svelte';

  // Picking friends or a group also picks their services, the page can change those on its own
  let { selected = $bindable([]), services = $bindable([]), disabled = false }: { selected: string[]; services: Platform[]; disabled?: boolean } = $props();
  let panel = $state<'' | 'add' | 'group' | 'invite' | 'edit'>('');
  let name = $state('');
  let platform = $state<Platform>('spotify');
  onMount(loadFriends);
  // Face to face the invite is scanned instead of sent
  const qr = $derived(panel === 'invite' && name.trim() ? renderSVG(inviteUrl(location.origin, { name: name.trim().slice(0, 40), platform }), { border: 2 }) : '');

  function pick(names: string[]) {
    selected = names;
    services = [...new Set(social.friends.filter(friend => names.includes(friend.name)).map(friend => friend.platform))];
  }
  const toggle = (friend: string) => pick(selected.includes(friend) ? selected.filter(other => other !== friend) : [...selected, friend]);
  const groupOn = (members: string[]) => members.length === selected.length && members.every(member => selected.includes(member));
  const anyGroup = $derived(social.groups.some(group => groupOn(group.members)));
  const open = (next: typeof panel) => { panel = panel === next ? '' : next; name = next === 'invite' ? social.me?.name ?? '' : ''; platform = next === 'invite' ? social.me?.platform ?? 'spotify' : 'spotify'; };

  function submit(event: SubmitEvent) {
    event.preventDefault();
    const value = name.trim().slice(0, 40);
    if (!value) return;
    if (panel === 'add') { addFriend({ name: value, platform }); pick([...selected.filter(other => other !== value), value]); }
    if (panel === 'group') addGroup(value, selected);
    if (panel === 'invite') { invite(value); return; }
    panel = '';
  }

  async function invite(value: string) {
    const me = { name: value, platform };
    setMe(me);
    const url = inviteUrl(location.origin, me);
    const text = t().inviteText(platforms[platform]);
    try {
      if (typeof navigator.share === 'function') await navigator.share({ text, url });
      else { await navigator.clipboard.writeText(`${text}\n${url}`); toast(t().inviteCopied); }
      panel = '';
    } catch (e) { if (!(e instanceof DOMException && e.name === 'AbortError')) toastError(t().shareFailed); }
  }
</script>

<div class="friends">
  <div class="head"><span>{t().toWhom} <small>{social.friends.length ? t().toWhomHint : t().toWhomHintEmpty}</small></span>
    <span class="links">{#if social.friends.length}<button type="button" onclick={() => open('edit')}>{panel === 'edit' ? t().done : t().edit}</button>{/if}<button type="button" onclick={() => open('invite')}>{t().myInvite}</button></span>
  </div>
  <div class="row" role="group" aria-label={t().toWhom}>
    {#if panel === 'edit'}
      {#each social.friends as friend (friend.name)}
        <button type="button" class="pick" onclick={() => { removeFriend(friend.name); pick(selected.filter(other => other !== friend.name)); }} aria-label={t().remove(friend.name)}><Avatar {friend} />{friend.name}<span class="remove" aria-hidden="true">×</span></button>
      {/each}
    {:else}
      <button type="button" class="pick text" aria-pressed={!services.length} {disabled} onclick={() => { selected = []; services = []; }}>{t().everyone}</button>
      {#each social.groups as group (group.name)}
        <button type="button" class="pick" aria-pressed={groupOn(group.members)} {disabled} onclick={() => pick(groupOn(group.members) ? [] : group.members.filter(member => social.friends.some(friend => friend.name === member)))}><span class="count" aria-hidden="true">{group.members.length}</span>{group.name}</button>
      {/each}
      {#each social.friends as friend (friend.name)}
        <button type="button" class="pick" aria-pressed={selected.includes(friend.name) && !anyGroup} {disabled} onclick={() => toggle(friend.name)} title={platforms[friend.platform]}><Avatar {friend} />{friend.name}</button>
      {/each}
      <button type="button" class="pick text add" {disabled} onclick={() => open('add')}>{t().addNew}</button>
      {#if selected.length > 1 && !anyGroup}<button type="button" class="pick text add" onclick={() => open('group')}>{t().saveAsGroup}</button>{/if}
    {/if}
  </div>
  {#if !social.friends.length && !panel}<p class="empty">{t().friendsEmpty}</p>{/if}
  {#if panel === 'add' || panel === 'group' || panel === 'invite'}
    <form class="panel" onsubmit={submit}>
      <p>{panel === 'add' ? t().addFriendHint : panel === 'group' ? t().groupOf(selected.join(', ')) : t().inviteHint}</p>
      <input bind:value={name} maxlength="40" placeholder={panel === 'group' ? t().groupName : panel === 'invite' ? t().yourName : t().name} required />
      {#if panel !== 'group'}<select bind:value={platform}>{#each (Object.keys(platforms) as Platform[]) as key}<option value={key}>{platforms[key]}</option>{/each}</select>{/if}
      <button type="submit" class="button primary">{panel === 'invite' ? t().shareInvite : t().save}</button>
      {#if qr}<figure class="qr"><span role="img" aria-label={t().inviteQr}>{@html qr}</span><figcaption>{t().scanHint}</figcaption></figure>{/if}
    </form>
  {/if}
</div>

<style>
  .friends { margin-bottom: 14px; }
  .head { display: flex; justify-content: space-between; align-items: baseline; gap: 12px; font-size: 14px; font-weight: 600; margin-bottom: 10px; }
  .head small { color: var(--muted); font-weight: 400; font-size: 13px; }
  .links { display: flex; gap: 14px; flex-shrink: 0; }
  .links button { background: none; border: 0; padding: 0; color: var(--muted); font-size: 13px; font-weight: 500; text-decoration: underline; text-underline-offset: 3px; }
  .empty { margin: 10px 0 0; font-size: 13px; color: var(--muted); }
  .row { display: flex; flex-wrap: wrap; gap: 8px; }
  .pick { display: inline-flex; align-items: center; gap: 8px; padding: 5px 14px 5px 5px; border-radius: 999px; border: 1px solid var(--border-strong); background: rgb(255 255 255 / .03); color: var(--text); font-size: 14px; font-weight: 550; }
  .pick:hover:not(:disabled) { background: var(--raised); }
  .pick.text { padding: 9px 14px; }
  .pick.add { border-style: dashed; color: var(--muted); }
  .pick[aria-pressed="true"] { background: linear-gradient(var(--raised), var(--raised)) padding-box, var(--gradient) border-box; border: 1px solid transparent; }
  .count { display: inline-grid; place-items: center; width: 28px; height: 28px; border-radius: 50%; background: var(--raised); font-size: 12px; }
  .remove { display: grid; place-items: center; width: 18px; height: 18px; border-radius: 50%; background: var(--error); color: var(--ink); font-size: 12px; }
  .panel { display: flex; flex-wrap: wrap; gap: 8px; margin-top: 12px; align-items: center; padding: 14px; border-radius: 18px; border: 1px solid var(--border); background: rgb(0 0 0 / .2); }
  .panel p { width: 100%; margin: 0; font-size: 13px; color: var(--muted); }
  .panel input, .panel select { flex: 1; min-width: 140px; border: 1px solid var(--border-strong); background: var(--bg); color: var(--text); border-radius: 12px; padding: 10px 12px; }
  .qr { width: 100%; margin: 4px 0 0; display: flex; align-items: center; gap: 14px; }
  .qr span { width: 132px; flex-shrink: 0; line-height: 0; border-radius: 8px; overflow: hidden; }
  .qr :global(svg) { display: block; width: 100%; height: auto; }
  .qr figcaption { font-size: 13px; color: var(--muted); }
  @media(max-width: 650px) {
    .head small { display: none; }
    .row { flex-wrap: nowrap; overflow-x: auto; margin-right: -18px; padding-right: 18px; scrollbar-width: none; }
    .pick { flex-shrink: 0; }
  }
</style>
