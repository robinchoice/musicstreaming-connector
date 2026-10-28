import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config.dart';
import '../../core/messages.dart';
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
    if (name is! String || name.isEmpty || !platforms.containsKey(platform)) {
      return null;
    }
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

String inviteText(Friend me, Messages t) =>
    t.inviteText(platforms[me.platform]!, inviteUrl(me));

/// A share page may name its sender, so the recipient can save them and
/// answer with their own service. Same as shareUrl in packages/shared.
String shareUrl(String path, Friend? from) => from == null
    ? '${_origin()}$path'
    : '${_origin()}$path?from=${Uri.encodeQueryComponent(from.name)}&service=${inviteSlugs[from.platform]}';

/// Without services only the share page, for group chats where everyone
/// picks their own. One service gets its link, several get one line each
/// plus the share page for everyone else. With an own invite the share page
/// comes along for one service too. The services default to those of the
/// friends, who are named next to their service. Same as packages/shared.
String friendsMessage(
  Song song,
  List<Friend> friends, {
  Friend? from,
  List<String>? services,
  AppLocale locale = AppLocale.de,
}) {
  final t = locale.messages;
  final head = '${song.album ? '💿' : '🎵'} ${song.title} – ${song.artist}';
  final everyone = shareUrl(song.sharePath, from);
  // Every message ends with where it was made, so recipients find Songgate too
  final footer =
      '\n\n${t.sharedWith} ${_origin().replaceFirst(RegExp(r'^https?://'), '')}';
  final chosen =
      services ?? friends.map((friend) => friend.platform).toSet().toList();
  if (chosen.isEmpty) return [head, everyone].join('\n') + footer;
  if (chosen.length == 1) {
    return [
          head,
          '${song.links[chosen.first]}',
          if (from != null) '${t.allServices}: $everyone',
        ].join('\n') +
        footer;
  }
  return [
        head,
        for (final platform in chosen)
          _serviceLine(
            platform,
            friends.where((friend) => friend.platform == platform),
            song.links[platform],
          ),
        '${t.others}: $everyone',
      ].join('\n') +
      footer;
}

String _serviceLine(String platform, Iterable<Friend> friends, String? url) {
  final names = friends.map((friend) => friend.name).join(', ');
  return '${platforms[platform]}${names.isEmpty ? '' : ' ($names)'}: $url';
}
