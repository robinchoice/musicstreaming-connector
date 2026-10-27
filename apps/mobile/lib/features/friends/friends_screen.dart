import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/locale.dart';
import '../converter/conversion.dart';
import 'friends_bar.dart';
import 'social.dart';

Future<String?> askText(
  BuildContext context, {
  required String title,
  required String label,
  String initial = '',
}) {
  final controller = TextEditingController(text: initial);
  final t = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(messagesProvider);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLength: 40,
        decoration: InputDecoration(labelText: label),
        onSubmitted: (value) =>
            Navigator.pop(context, value.trim().isEmpty ? null : value.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            controller.text.trim().isEmpty ? null : controller.text.trim(),
          ),
          child: Text(t.save),
        ),
      ],
    ),
  ).whenComplete(controller.dispose);
}

/// Name plus service. Saves it as a friend unless [save] is false.
Future<Friend?> showAddFriendDialog(
  BuildContext context,
  WidgetRef ref, {
  String? title,
  Friend? initial,
  bool save = true,
}) async {
  final t = ref.read(messagesProvider);
  final controller = TextEditingController(text: initial?.name ?? '');
  var platform = initial?.platform ?? 'spotify';
  final friend = await showDialog<Friend>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(title ?? t.addFriend),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              autofocus: initial == null,
              maxLength: 40,
              decoration: InputDecoration(labelText: t.name),
            ),
            DropdownButtonFormField<String>(
              initialValue: platform,
              decoration: InputDecoration(labelText: t.listensOn),
              items: [
                for (final entry in platforms.entries)
                  DropdownMenuItem(value: entry.key, child: Text(entry.value)),
              ],
              onChanged: (value) => setState(() => platform = value!),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t.cancel),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(context, Friend(name, platform));
              }
            },
            child: Text(t.save),
          ),
        ],
      ),
    ),
  );
  controller.dispose();
  if (friend != null && save) {
    await ref.read(socialProvider.notifier).addFriend(friend);
  }
  return friend;
}

Future<void> shareInvite(
  BuildContext context,
  WidgetRef ref, {
  Rect? origin,
}) async {
  final t = ref.read(messagesProvider);
  final current = ref.read(socialProvider).me;
  final me = await showAddFriendDialog(
    context,
    ref,
    title: t.myInvite,
    initial: current ?? const Friend('', 'spotify'),
    save: false,
  );
  if (me == null) return;
  await ref.read(socialProvider.notifier).setMe(me);
  try {
    await SharePlus.instance.share(
      ShareParams(text: inviteText(me, t), sharePositionOrigin: origin),
    );
  } on PlatformException {
    await Clipboard.setData(ClipboardData(text: inviteText(me, t)));
  }
}

/// Face to face the invite is scanned instead of sent.
Future<void> showInviteQr(BuildContext context, WidgetRef ref) async {
  final t = ref.read(messagesProvider);
  final current = ref.read(socialProvider).me;
  final me =
      current ??
      await showAddFriendDialog(
        context,
        ref,
        title: t.myInvite,
        initial: const Friend('', 'spotify'),
        save: false,
      );
  if (me == null || !context.mounted) return;
  if (current == null) await ref.read(socialProvider.notifier).setMe(me);
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('${me.name} · ${platforms[me.platform]}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 240,
            height: 240,
            child: QrImageView(
              data: inviteUrl(me),
              backgroundColor: Colors.white,
              semanticsLabel: t.inviteQrLabel,
            ),
          ),
          const SizedBox(height: 12),
          Text(t.scanHint, textAlign: TextAlign.center),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t.done),
        ),
      ],
    ),
  );
}

class FriendsScreen extends ConsumerWidget {
  const FriendsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final social = ref.watch(socialProvider);
    final notifier = ref.read(socialProvider.notifier);
    final t = ref.watch(messagesProvider);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.friends)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(t.friendsIntro),
          const SizedBox(height: 16),
          Builder(
            builder: (context) => FilledButton.icon(
              onPressed: () {
                final box = context.findRenderObject()! as RenderBox;
                shareInvite(
                  context,
                  ref,
                  origin: box.localToGlobal(Offset.zero) & box.size,
                );
              },
              icon: const Icon(Icons.ios_share),
              label: Text(
                social.me == null
                    ? t.shareMyInvite
                    : t.shareInviteAs(
                        social.me!.name,
                        platforms[social.me!.platform]!,
                      ),
              ),
            ),
          ),
          TextButton.icon(
            onPressed: () => showInviteQr(context, ref),
            icon: const Icon(Icons.qr_code_2),
            label: Text(t.showInviteQr),
          ),
          TextButton.icon(
            onPressed: () => showAddFriendDialog(context, ref),
            icon: const Icon(Icons.person_add_alt),
            label: Text(t.addFriendManually),
          ),
          const SizedBox(height: 8),
          if (social.friends.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(t.noFriends, style: theme.textTheme.bodySmall),
            ),
          for (final friend in social.friends)
            ListTile(
              key: ValueKey('manage-${friend.name}'),
              contentPadding: EdgeInsets.zero,
              leading: FriendAvatar(friend, size: 40),
              title: Text(friend.name),
              subtitle: Text(platforms[friend.platform]!),
              onTap: () => showAddFriendDialog(
                context,
                ref,
                title: t.editFriend,
                initial: friend,
              ),
              trailing: IconButton(
                tooltip: t.remove(friend.name),
                icon: const Icon(Icons.delete_outline),
                onPressed: () => notifier.removeFriend(friend.name),
              ),
            ),
          if (social.groups.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(t.groups, style: theme.textTheme.titleSmall),
            for (final group in social.groups)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(child: Icon(Icons.group_outlined)),
                title: Text(group.name),
                subtitle: Text(group.members.join(', ')),
                trailing: IconButton(
                  tooltip: t.remove(group.name),
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => notifier.removeGroup(group.name),
                ),
              ),
          ],
          const SizedBox(height: 16),
          Text(t.groupsHint, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// Opened by musiclink://app/friend?name=…&service=… from an invite page.
class AddFriendScreen extends ConsumerWidget {
  final String? name;
  final String? service;
  const AddFriendScreen({super.key, this.name, this.service});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final platform = platformForSlug(service);
    final name = this.name?.trim() ?? '';
    final valid = platform != null && name.isNotEmpty && name.length <= 40;
    final t = ref.watch(messagesProvider);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.invite)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: !valid
            ? Text(t.inviteIncomplete)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(child: FriendAvatar(Friend(name, platform), size: 76)),
                  const SizedBox(height: 16),
                  Text(
                    t.friendListensOn(name, platforms[platform]!),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t.saveFriendHint(name, platforms[platform]!),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () async {
                      await ref
                          .read(socialProvider.notifier)
                          .addFriend(Friend(name, platform));
                      if (context.mounted) context.go('/');
                    },
                    child: Text(t.saveName(name)),
                  ),
                  TextButton(
                    onPressed: () => context.go('/'),
                    child: Text(t.notNow),
                  ),
                ],
              ),
      ),
    );
  }
}
