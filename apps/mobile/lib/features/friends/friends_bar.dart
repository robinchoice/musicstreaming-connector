import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/brand.dart';
import '../converter/conversion.dart';
import 'friends_screen.dart';
import 'social.dart';

/// Initial on a steady colour per name with the friend's service as a badge,
/// the same colour as on the web.
class FriendAvatar extends StatelessWidget {
  final Friend friend;
  final double size;
  const FriendAvatar(this.friend, {super.key, this.size = 50});

  @override
  Widget build(BuildContext context) {
    final hue = friend.name.codeUnits
        .fold(7, (sum, unit) => (sum * 31 + unit) % 360)
        .toDouble();
    final badge = (size * 0.38).roundToDouble();
    return SizedBox(
      width: size + 3,
      height: size + 3,
      child: Stack(
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: HSLColor.fromAHSL(1, hue, 0.35, 0.30).toColor(),
            ),
            alignment: Alignment.center,
            child: Text(
              friend.name.characters.first.toUpperCase(),
              style: TextStyle(
                fontSize: size * 0.4,
                fontWeight: FontWeight.w700,
                color: HSLColor.fromAHSL(1, hue, 0.6, 0.88).toColor(),
              ),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Tooltip(
              message: platforms[friend.platform],
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: background,
                  shape: BoxShape.circle,
                ),
                child: ServiceLogo(friend.platform, size: badge),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A rounded chip, its border turns into the gradient when picked.
class PickChip extends StatelessWidget {
  final bool selected;
  final VoidCallback? onTap;
  final Widget? leading;
  final String label;
  final bool dashed;
  const PickChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.leading,
    this.dashed = false,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: EdgeInsets.fromLTRB(leading == null ? 14 : 5, 5, 14, 5),
      constraints: const BoxConstraints(minHeight: 38),
      decoration: BoxDecoration(
        color: selected ? raised : const Color(0x08FFFFFF),
        borderRadius: BorderRadius.circular(999),
        border: selected
            ? null
            : Border.all(color: dashed ? hairline : hairlineStrong),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 8)],
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: dashed ? muted : text,
            ),
          ),
        ],
      ),
    );
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: selected
            ? Container(
                padding: const EdgeInsets.all(1.5),
                decoration: BoxDecoration(
                  gradient: bandGradient(glow),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: content,
              )
            : content,
      ),
    );
  }
}

/// "An wen?": everyone, a group or friends. Picking people picks their
/// services, the service tiles can change those on their own.
class FriendsBar extends ConsumerWidget {
  final List<String> selected;
  final List<String> services;
  final void Function(List<String> names, List<String> services) onChanged;
  final bool enabled;
  const FriendsBar({
    super.key,
    required this.selected,
    required this.services,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final social = ref.watch(socialProvider);
    final theme = Theme.of(context);
    // Read at call time: "+ Neu" picks a friend saved after this build
    void pick(List<String> names) => onChanged(names, [
      for (final platform in serviceOrder)
        if (ref
            .read(socialProvider)
            .friends
            .any(
              (friend) =>
                  names.contains(friend.name) && friend.platform == platform,
            ))
          platform,
    ]);
    bool groupOn(Group group) =>
        group.members.length == selected.length &&
        group.members.every(selected.contains);
    final anyGroup = social.groups.any(groupOn);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'An wen?',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
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
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final chip in [
                PickChip(
                  key: const ValueKey('pick-all'),
                  label: 'Alle',
                  selected: services.isEmpty,
                  onTap: enabled ? () => onChanged([], []) : null,
                ),
                for (final group in social.groups)
                  PickChip(
                    key: ValueKey('group-${group.name}'),
                    label: group.name,
                    selected: groupOn(group),
                    leading: CircleAvatar(
                      radius: 14,
                      backgroundColor: raised,
                      child: Text(
                        '${group.members.length}',
                        style: const TextStyle(fontSize: 12, color: text),
                      ),
                    ),
                    onTap: enabled
                        ? () => pick(
                            groupOn(group)
                                ? []
                                : group.members
                                      .where(
                                        (member) => social.friends.any(
                                          (friend) => friend.name == member,
                                        ),
                                      )
                                      .toList(),
                          )
                        : null,
                  ),
                for (final friend in social.friends)
                  PickChip(
                    key: ValueKey('friend-${friend.name}'),
                    label: friend.name,
                    selected: selected.contains(friend.name) && !anyGroup,
                    leading: FriendAvatar(friend, size: 28),
                    onTap: enabled
                        ? () => pick(
                            selected.contains(friend.name)
                                ? selected
                                      .where((name) => name != friend.name)
                                      .toList()
                                : [...selected, friend.name],
                          )
                        : null,
                  ),
                PickChip(
                  key: const ValueKey('friend-add'),
                  label: '+ Neu',
                  dashed: true,
                  onTap: enabled
                      ? () async {
                          final friend = await showAddFriendDialog(
                            context,
                            ref,
                          );
                          if (friend != null) {
                            pick([
                              ...selected.where((name) => name != friend.name),
                              friend.name,
                            ]);
                          }
                        }
                      : null,
                ),
                if (selected.length > 1 && !anyGroup)
                  PickChip(
                    key: const ValueKey('group-add'),
                    label: 'Als Gruppe speichern',
                    dashed: true,
                    onTap: enabled
                        ? () async {
                            final name = await askText(
                              context,
                              title: 'Gruppe aus ${selected.join(', ')}',
                              label: 'Name, z. B. WG',
                            );
                            if (name != null) {
                              ref
                                  .read(socialProvider.notifier)
                                  .addGroup(name, selected);
                            }
                          }
                        : null,
                  ),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Center(child: chip),
                ),
            ],
          ),
        ),
        if (social.friends.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Speichere, wer welchen Dienst hört. Dann bekommt jeder den Link für seinen Player.',
              style: theme.textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}
