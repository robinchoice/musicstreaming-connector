import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../converter/conversion.dart';
import 'friends_screen.dart';
import 'social.dart';

const serviceColors = {
  'appleMusic': Color(0xFFFA2D48),
  'youtubeMusic': Color(0xFFFF0033),
  'spotify': Color(0xFF1DB954),
  'deezer': Color(0xFFA238FF),
};

class FriendAvatar extends StatelessWidget {
  final Friend friend;
  final bool selected;
  final double size;
  const FriendAvatar(
    this.friend, {
    super.key,
    this.selected = false,
    this.size = 50,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: size + 4,
      height: size + 4,
      child: Stack(
        children: [
          Container(
            width: size,
            height: size,
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.primaryContainer,
              border: Border.all(
                color: selected ? scheme.primary : Colors.transparent,
                width: 2.5,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              friend.name.characters.first.toUpperCase(),
              style: TextStyle(
                fontSize: size * 0.36,
                fontWeight: FontWeight.w700,
                color: scheme.onPrimaryContainer,
              ),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Tooltip(
              message: platforms[friend.platform],
              child: Container(
                width: size * 0.36,
                height: size * 0.36,
                decoration: BoxDecoration(
                  color: serviceColors[friend.platform],
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: scheme.surface, width: 2),
                ),
              ),
            ),
          ),
          if (selected)
            Positioned(
              right: 0,
              top: 0,
              child: CircleAvatar(
                radius: 9,
                backgroundColor: scheme.primary,
                child: Icon(Icons.check, size: 12, color: scheme.onPrimary),
              ),
            ),
        ],
      ),
    );
  }
}

/// Tap friends to pick them, tap a group to pick all its members.
class FriendsBar extends ConsumerWidget {
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;
  final bool enabled;
  const FriendsBar({
    super.key,
    required this.selected,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final social = ref.watch(socialProvider);
    final theme = Theme.of(context);
    bool groupOn(Group group) =>
        group.members.length == selected.length &&
        group.members.every(selected.contains);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Für wen?', style: theme.textTheme.titleSmall),
            const Spacer(),
            TextButton(
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const FriendsScreen())),
              child: const Text('Bearbeiten'),
            ),
          ],
        ),
        SizedBox(
          height: 82,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final friend in social.friends)
                _item(
                  key: ValueKey('friend-${friend.name}'),
                  label: friend.name,
                  onTap: enabled
                      ? () => onChanged(
                          selected.contains(friend.name)
                              ? ({...selected}..remove(friend.name))
                              : {...selected, friend.name},
                        )
                      : null,
                  child: FriendAvatar(
                    friend,
                    selected: selected.contains(friend.name),
                  ),
                ),
              _item(
                key: const ValueKey('friend-add'),
                label: 'Neu',
                onTap: enabled
                    ? () async {
                        final friend = await showAddFriendDialog(context, ref);
                        if (friend != null) {
                          onChanged({...selected, friend.name});
                        }
                      }
                    : null,
                child: Container(
                  width: 50,
                  height: 50,
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: theme.colorScheme.outline),
                  ),
                  child: const Icon(Icons.add),
                ),
              ),
            ],
          ),
        ),
        if (social.groups.isNotEmpty || selected.length > 1)
          Wrap(
            spacing: 8,
            children: [
              for (final group in social.groups)
                FilterChip(
                  label: Text(group.name),
                  selected: groupOn(group),
                  onSelected: enabled
                      ? (_) => onChanged(
                          groupOn(group)
                              ? {}
                              : group.members
                                    .where(
                                      (member) => social.friends.any(
                                        (friend) => friend.name == member,
                                      ),
                                    )
                                    .toSet(),
                        )
                      : null,
                ),
              if (selected.length > 1)
                ActionChip(
                  avatar: const Icon(Icons.add, size: 18),
                  label: const Text('Gruppe'),
                  onPressed: enabled
                      ? () async {
                          final name = await askText(
                            context,
                            title: 'Gruppe aus ${selected.join(', ')}',
                            label: 'Name, z. B. WG',
                          );
                          if (name != null) {
                            ref
                                .read(socialProvider.notifier)
                                .addGroup(name, selected.toList());
                          }
                        }
                      : null,
                ),
            ],
          ),
      ],
    );
  }

  Widget _item({
    required Key key,
    required String label,
    required VoidCallback? onTap,
    required Widget child,
  }) => Padding(
    key: key,
    padding: const EdgeInsets.only(right: 10),
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: SizedBox(
        width: 60,
        child: Column(
          children: [
            child,
            const SizedBox(height: 4),
            Text(label, overflow: TextOverflow.ellipsis, maxLines: 1),
          ],
        ),
      ),
    ),
  );
}
