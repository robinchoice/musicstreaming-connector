import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

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
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            controller.text.trim().isEmpty ? null : controller.text.trim(),
          ),
          child: const Text('Speichern'),
        ),
      ],
    ),
  ).whenComplete(controller.dispose);
}

/// Name plus service. Saves it as a friend unless [save] is false.
Future<Friend?> showAddFriendDialog(
  BuildContext context,
  WidgetRef ref, {
  String title = 'Freund hinzufügen',
  Friend? initial,
  bool save = true,
}) async {
  final controller = TextEditingController(text: initial?.name ?? '');
  var platform = initial?.platform ?? 'spotify';
  final friend = await showDialog<Friend>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              autofocus: initial == null,
              maxLength: 40,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            DropdownButtonFormField<String>(
              initialValue: platform,
              decoration: const InputDecoration(labelText: 'Hört auf'),
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
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(context, Friend(name, platform));
              }
            },
            child: const Text('Speichern'),
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
  final current = ref.read(socialProvider).me;
  final me = await showAddFriendDialog(
    context,
    ref,
    title: 'Meine Einladung',
    initial: current ?? const Friend('', 'spotify'),
    save: false,
  );
  if (me == null) return;
  await ref.read(socialProvider.notifier).setMe(me);
  try {
    await SharePlus.instance.share(
      ShareParams(text: inviteText(me), sharePositionOrigin: origin),
    );
  } on PlatformException {
    await Clipboard.setData(ClipboardData(text: inviteText(me)));
  }
}

class FriendsScreen extends ConsumerWidget {
  const FriendsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final social = ref.watch(socialProvider);
    final notifier = ref.read(socialProvider.notifier);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Freunde')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Damit MusicLink weiß, wohin deine Songs sollen. Alles bleibt auf diesem Handy.',
          ),
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
                    ? 'Meine Einladung teilen'
                    : 'Einladung teilen (${social.me!.name} · ${platforms[social.me!.platform]})',
              ),
            ),
          ),
          TextButton.icon(
            onPressed: () => showAddFriendDialog(context, ref),
            icon: const Icon(Icons.person_add_alt),
            label: const Text('Freund von Hand hinzufügen'),
          ),
          const SizedBox(height: 8),
          if (social.friends.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'Noch keine Freunde. Schick deine Einladung, wer sie öffnet, kann dich speichern und dir seine zurückschicken.',
                style: theme.textTheme.bodySmall,
              ),
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
                title: 'Freund bearbeiten',
                initial: friend,
              ),
              trailing: IconButton(
                tooltip: '${friend.name} entfernen',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => notifier.removeFriend(friend.name),
              ),
            ),
          if (social.groups.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Gruppen', style: theme.textTheme.titleSmall),
            for (final group in social.groups)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(child: Icon(Icons.group_outlined)),
                title: Text(group.name),
                subtitle: Text(group.members.join(', ')),
                trailing: IconButton(
                  tooltip: '${group.name} entfernen',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => notifier.removeGroup(group.name),
                ),
              ),
          ],
          const SizedBox(height: 16),
          Text(
            'Gruppen legst du beim Teilen an: mehrere Freunde wählen, dann „+ Gruppe“.',
            style: theme.textTheme.bodySmall,
          ),
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
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Einladung')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: !valid
            ? const Text(
                'Diese Einladung ist unvollständig. Bitte um einen neuen Link.',
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(child: FriendAvatar(Friend(name, platform), size: 76)),
                  const SizedBox(height: 16),
                  Text(
                    '$name hört auf ${platforms[platform]}',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Speicher $name, dann landen deine Songs bei $name immer direkt in ${platforms[platform]}.',
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
                    child: Text('$name speichern'),
                  ),
                  TextButton(
                    onPressed: () => context.go('/'),
                    child: const Text('Nicht jetzt'),
                  ),
                ],
              ),
      ),
    );
  }
}
