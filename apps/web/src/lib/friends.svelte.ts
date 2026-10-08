import { inviteSlugs, platforms, type Friend, type Platform } from '@app/shared';

// Friends stay in this browser. Nothing about them reaches our server.
type Saved = { friends: Friend[]; groups: { name: string; members: string[] }[]; me: Friend | null };
const KEY = 'musiclink-friends';

export const social = $state<Saved>({ friends: [], groups: [], me: null });

export function loadFriends() {
  try {
    const saved = JSON.parse(localStorage.getItem(KEY) ?? '{}') as Partial<Saved>;
    social.friends = (saved.friends ?? []).filter(friend => friend.platform in platforms);
    social.groups = saved.groups ?? [];
    social.me = saved.me?.platform && saved.me.platform in platforms ? saved.me : null;
  } catch {}
}

function save() {
  try { localStorage.setItem(KEY, JSON.stringify(social)); } catch {}
}

export function addFriend(friend: Friend) {
  social.friends = [...social.friends.filter(other => other.name !== friend.name), friend];
  save();
}

export function removeFriend(name: string) {
  social.friends = social.friends.filter(friend => friend.name !== name);
  social.groups = social.groups.map(group => ({ ...group, members: group.members.filter(member => member !== name) })).filter(group => group.members.length);
  save();
}

export function addGroup(name: string, members: string[]) {
  social.groups = [...social.groups.filter(group => group.name !== name), { name, members }];
  save();
}

export function setMe(me: Friend) {
  social.me = me;
  save();
}

export const inviteUrl = (origin: string, me: Friend) => `${origin}/f/${inviteSlugs[me.platform]}?name=${encodeURIComponent(me.name)}`;

export function platformForSlug(slug: string): Platform | undefined {
  return (Object.keys(inviteSlugs) as Platform[]).find(platform => inviteSlugs[platform] === slug);
}
