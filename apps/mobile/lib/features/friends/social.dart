import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config.dart';
import '../converter/conversion.dart';

/// Invite links name the service with a short slug, see packages/shared.
const inviteSlugs = {
  'appleMusic': 'apple',
  'youtubeMusic': 'youtube',
  'spotify': 'spotify',
  'deezer': 'deezer',
};

String? platformForSlug(String? slug) => inviteSlugs.entries
    .where((entry) => entry.value == slug)
    .map((entry) => entry.key)
    .firstOrNull;

class Friend {
  final String name;
  final String platform;
  const Friend(this.name, this.platform);
  Map<String, String> toJson() => {'name': name, 'platform': platform};
  static Friend? fromJson(Object? json) {
    if (json is! Map) return null;
    final name = json['name'];
    final platform = json['platform'];
    if (name is! String || !platforms.containsKey(platform)) return null;
    return Friend(name, platform as String);
  }
}

class Group {
  final String name;
  final List<String> members;
  const Group(this.name, this.members);
  Map<String, Object> toJson() => {'name': name, 'members': members};
}

/// Friends stay on the device. On iOS they live in the app group, so the
/// share extension sees the same list.
class Social {
  final List<Friend> friends;
  final List<Group> groups;
  final Friend? me;
  const Social({this.friends = const [], this.groups = const [], this.me});

  factory Social.fromJson(Map<String, dynamic> json) => Social(
    friends: [
      for (final item in json['friends'] as List? ?? []) ?Friend.fromJson(item),
    ],
    groups: [
      for (final item in json['groups'] as List? ?? [])
        if (item is Map && item['name'] is String && item['members'] is List)
          Group(
            item['name'] as String,
            (item['members'] as List).whereType<String>().toList(),
          ),
    ],
    me: Friend.fromJson(json['me']),
  );

  Map<String, Object?> toJson() => {
    'friends': [for (final friend in friends) friend.toJson()],
    'groups': [for (final group in groups) group.toJson()],
    'me': me?.toJson(),
  };
}

final socialProvider = NotifierProvider<SocialNotifier, Social>(
  SocialNotifier.new,
);

class SocialNotifier extends Notifier<Social> {
  static const _channel = MethodChannel('org.musiclink.prototype/preferences');

  @override
  Social build() {
    _load();
    return const Social();
  }

  Future<void> _load() async {
    try {
      final saved = await _channel.invokeMethod<Object?>('getSocial');
      if (saved is String) {
        state = Social.fromJson(jsonDecode(saved) as Map<String, dynamic>);
      }
    } on PlatformException {
      // Nothing saved yet or no storage, start without friends
    } on FormatException {
      // Unreadable leftovers, start without friends
    }
  }

  Future<void> _save(Social next) async {
    state = next;
    try {
      await _channel.invokeMethod('setSocial', jsonEncode(next.toJson()));
    } on PlatformException {
      // Kept for this session at least
    }
  }

  Future<void> addFriend(Friend friend) => _save(
    Social(
      friends: [
        ...state.friends.where((other) => other.name != friend.name),
        friend,
      ],
      groups: state.groups,
      me: state.me,
    ),
  );

  Future<void> removeFriend(String name) => _save(
    Social(
      friends: state.friends.where((friend) => friend.name != name).toList(),
      groups: [
        for (final group in state.groups)
          if (group.members.any((member) => member != name))
            Group(
              group.name,
              group.members.where((member) => member != name).toList(),
            ),
      ],
      me: state.me,
    ),
  );

  Future<void> addGroup(String name, List<String> members) => _save(
    Social(
      friends: state.friends,
      groups: [
        ...state.groups.where((group) => group.name != name),
        Group(name, members),
      ],
      me: state.me,
    ),
  );

  Future<void> removeGroup(String name) => _save(
    Social(
      friends: state.friends,
      groups: state.groups.where((group) => group.name != name).toList(),
      me: state.me,
    ),
  );

  Future<void> setMe(Friend me) =>
      _save(Social(friends: state.friends, groups: state.groups, me: me));
}

String _origin() => apiUrl.replaceFirst(RegExp(r'/+$'), '');

String inviteUrl(Friend me) =>
    '${_origin()}/f/${inviteSlugs[me.platform]}?name=${Uri.encodeQueryComponent(me.name)}';

String inviteText(Friend me) =>
    'Ich höre auf ${platforms[me.platform]}. Speicher mich in MusicLink, dann bekomme ich deine Songs immer passend:\n${inviteUrl(me)}';

/// One link if everyone uses the same service, otherwise one line per
/// service plus the share page for everyone else. Same as packages/shared.
String friendsMessage(Song song, List<Friend> friends) {
  final head = '🎵 ${song.title} – ${song.artist}';
  final services = <String>[];
  for (final friend in friends) {
    if (!services.contains(friend.platform)) services.add(friend.platform);
  }
  if (services.length == 1) return '$head\n${song.links[services.first]}';
  return [
    head,
    for (final platform in services)
      '${platforms[platform]} (${friends.where((friend) => friend.platform == platform).map((friend) => friend.name).join(', ')}): ${song.links[platform]}',
    'Andere: ${_origin()}${song.sharePath}',
  ].join('\n');
}
