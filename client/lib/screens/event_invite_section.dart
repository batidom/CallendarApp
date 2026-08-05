import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/generated/app_localizations.dart';
import '../providers/providers.dart';

String _displayName(Map<String, dynamic> user) {
  final name = user['name'] as String? ?? '';
  final surname = user['surname'] as String?;
  return surname != null && surname.isNotEmpty ? '$name $surname' : name;
}

String _statusLabel(String status, AppLocalizations l10n) => switch (status) {
      'pending' => l10n.statusPending,
      'accepted' => l10n.statusAccepted,
      'declined' => l10n.statusDeclined,
      _ => status,
    };

/// What the user has picked in this form session but hasn't saved yet.
/// [EventInviteSection] reports this up after every change; the event form
/// only actually calls the invite/revoke API once the whole form is saved.
class InviteStaging {
  const InviteStaging({
    this.newUserIds = const {},
    this.newGroupIds = const {},
    this.revokedInviteIds = const {},
  });

  final Set<String> newUserIds;
  final Set<String> newGroupIds;
  final Set<String> revokedInviteIds;

  bool get isEmpty => newUserIds.isEmpty && newGroupIds.isEmpty && revokedInviteIds.isEmpty;
}

/// Owner-only "who's invited" editor for an event: existing invites plus
/// separate "Add people"/"Add groups" pickers for staging more. Nothing
/// here talks to the network directly — every add/remove just updates local
/// state and reports the current [InviteStaging] up via [onStagingChanged];
/// the event form is the one that actually sends it, only once the form
/// itself is saved.
class EventInviteSection extends ConsumerStatefulWidget {
  const EventInviteSection({
    super.key,
    required this.eventId,
    required this.eventExistsOnServer,
    required this.onStagingChanged,
  });

  final String eventId;
  // Whether this event has actually been saved before (so its invite list
  // is worth fetching from the server) — false for a brand-new event that's
  // only been assigned a client-side id so far.
  final bool eventExistsOnServer;
  final ValueChanged<InviteStaging> onStagingChanged;

  @override
  ConsumerState<EventInviteSection> createState() => _EventInviteSectionState();
}

class _EventInviteSectionState extends ConsumerState<EventInviteSection> {
  final Map<String, Map<String, dynamic>> _newUsers = {};
  final Map<String, Map<String, dynamic>> _newGroups = {};
  final Set<String> _revokedInviteIds = {};

  void _notifyStagingChanged() {
    widget.onStagingChanged(InviteStaging(
      newUserIds: _newUsers.keys.toSet(),
      newGroupIds: _newGroups.keys.toSet(),
      revokedInviteIds: Set.of(_revokedInviteIds),
    ));
  }

  // friendsProvider/groupsProvider already come back sorted by the backend
  // (most-frequently-used first, then alphabetical — see
  // FriendsService.listFriends / GroupsService.listGroups) so the picker
  // just filters that order live as the user types, it never re-sorts.
  Future<void> _addPeople(List<Map<String, dynamic>> existingInvites) async {
    final friends = await ref.read(friendsProvider.future);
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final alreadyShownIds = {
      ...existingInvites.map((i) => (i['user'] as Map<String, dynamic>)['id'] as String),
      ..._newUsers.keys,
    };
    final selectedIds = await showDialog<List<String>>(
      context: context,
      builder: (_) => _PickerDialog(
        title: l10n.dialogAddPeopleTitle,
        items: friends,
        excludeIds: alreadyShownIds,
        emptyHint: l10n.addFriendsFirstHint,
        itemTitle: _displayName,
        searchFields: (friend) => [
          friend['name'] as String? ?? '',
          friend['surname'] as String? ?? '',
          friend['username'] as String? ?? '',
        ],
      ),
    );
    if (selectedIds == null || selectedIds.isEmpty) return;
    setState(() {
      for (final friend in friends) {
        if (selectedIds.contains(friend['id'])) {
          _newUsers[friend['id'] as String] = friend;
        }
      }
    });
    _notifyStagingChanged();
  }

  Future<void> _addGroups() async {
    final groups = await ref.read(groupsProvider.future);
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final selectedIds = await showDialog<List<String>>(
      context: context,
      builder: (_) => _PickerDialog(
        title: l10n.dialogAddGroupsTitle,
        items: groups,
        excludeIds: _newGroups.keys.toSet(),
        emptyHint: l10n.noGroupsToPickHint,
        itemTitle: (group) => group['name'] as String,
        itemSubtitle: (group) => l10n.memberCount((group['members'] as List).length),
        searchFields: (group) => [group['name'] as String? ?? ''],
      ),
    );
    if (selectedIds == null || selectedIds.isEmpty) return;
    setState(() {
      for (final group in groups) {
        if (selectedIds.contains(group['id'])) {
          _newGroups[group['id'] as String] = group;
        }
      }
    });
    _notifyStagingChanged();
  }

  void _removeExistingInvite(String inviteId) {
    setState(() => _revokedInviteIds.add(inviteId));
    _notifyStagingChanged();
  }

  void _unstageNewUser(String userId) {
    setState(() => _newUsers.remove(userId));
    _notifyStagingChanged();
  }

  void _unstageNewGroup(String groupId) {
    setState(() => _newGroups.remove(groupId));
    _notifyStagingChanged();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final invitesAsync = widget.eventExistsOnServer
        ? ref.watch(eventInvitesProvider(widget.eventId))
        : const AsyncValue<List<Map<String, dynamic>>>.data([]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(l10n.peopleHeader, style: const TextStyle(fontWeight: FontWeight.w600)),
            const Spacer(),
            TextButton.icon(
              onPressed: () => _addPeople(invitesAsync.valueOrNull ?? const []),
              icon: const Icon(Icons.person_add_alt, size: 16),
              label: Text(l10n.actionAddPeople),
            ),
            TextButton.icon(
              onPressed: _addGroups,
              icon: const Icon(Icons.group_add_outlined, size: 16),
              label: Text(l10n.actionAddGroups),
            ),
          ],
        ),
        invitesAsync.when(
          data: (invites) {
            final visibleInvites = invites.where((i) => !_revokedInviteIds.contains(i['id'])).toList();
            final isEmpty = visibleInvites.isEmpty && _newUsers.isEmpty && _newGroups.isEmpty;
            if (isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(l10n.noOneElseInvited),
              );
            }
            return Column(
              children: [
                for (final invite in visibleInvites)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(_displayName(invite['user'] as Map<String, dynamic>)),
                    subtitle: Text(_statusLabel(invite['status'] as String, l10n)),
                    trailing: IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      tooltip: l10n.tooltipRemove,
                      onPressed: () => _removeExistingInvite(invite['id'] as String),
                    ),
                  ),
                for (final entry in _newUsers.entries)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(_displayName(entry.value)),
                    subtitle: Text(l10n.willBeSentOnSave),
                    trailing: IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      tooltip: l10n.tooltipRemove,
                      onPressed: () => _unstageNewUser(entry.key),
                    ),
                  ),
                for (final entry in _newGroups.entries)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(entry.value['name'] as String),
                    subtitle: Text(l10n.willBeSentOnSave),
                    trailing: IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      tooltip: l10n.tooltipRemove,
                      onPressed: () => _unstageNewGroup(entry.key),
                    ),
                  ),
              ],
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(),
          ),
          error: (error, _) => Text(l10n.failedToLoadInvites(error.toString())),
        ),
      ],
    );
  }
}

/// Non-owner counterpart to [EventInviteSection]: a plain, read-only list of
/// everyone else this event is shared with (the owner is shown separately,
/// see event_form_screen.dart's "Shared by X" banner). The backend already
/// lets any accepted invitee fetch the full invite list, same as the owner
/// (see EventInvitesService.assertCanView) — this just surfaces it in the
/// UI instead of hiding it behind the owner-only management controls.
class SharedWithReadOnlySection extends ConsumerWidget {
  const SharedWithReadOnlySection({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final invitesAsync = ref.watch(eventInvitesProvider(eventId));
    final currentUserId = ref.watch(currentUserIdProvider).valueOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.alsoSharedWithHeader, style: const TextStyle(fontWeight: FontWeight.w600)),
        invitesAsync.when(
          data: (allInvites) {
            // The viewer is always one of these entries themself (that's why
            // they can see this event at all) — only the *other* invitees
            // are "also shared with" from their point of view.
            final invites = allInvites
                .where((i) => (i['user'] as Map<String, dynamic>)['id'] != currentUserId)
                .toList();
            if (invites.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(l10n.noOneElseInvited),
              );
            }
            return Column(
              children: [
                for (final invite in invites)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(_displayName(invite['user'] as Map<String, dynamic>)),
                    subtitle: Text(_statusLabel(invite['status'] as String, l10n)),
                  ),
              ],
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(),
          ),
          error: (error, _) => Text(l10n.failedToLoadInvites(error.toString())),
        ),
      ],
    );
  }
}

/// Shared search-and-multiselect picker for both "Add people" and "Add
/// groups". Typing filters [items] to entries where any of [searchFields]
/// *starts with* what's typed (not a substring match anywhere), live,
/// without disturbing the order [items] was already given in. [excludeIds]
/// hides entries already invited/staged so the same person/group can't be
/// picked twice.
class _PickerDialog extends StatefulWidget {
  const _PickerDialog({
    required this.title,
    required this.items,
    required this.itemTitle,
    required this.searchFields,
    required this.emptyHint,
    this.itemSubtitle,
    this.excludeIds = const {},
  });

  final String title;
  final List<Map<String, dynamic>> items;
  final String Function(Map<String, dynamic> item) itemTitle;
  final String Function(Map<String, dynamic> item)? itemSubtitle;
  final List<String> Function(Map<String, dynamic> item) searchFields;
  final String emptyHint;
  final Set<String> excludeIds;

  @override
  State<_PickerDialog> createState() => _PickerDialogState();
}

class _PickerDialogState extends State<_PickerDialog> {
  final _searchController = TextEditingController();
  final Set<String> _selectedIds = {};
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matches(Map<String, dynamic> item) {
    if (_query.isEmpty) return true;
    return widget.searchFields(item).any((field) => field.toLowerCase().startsWith(_query));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final selectable = widget.items.where((item) => !widget.excludeIds.contains(item['id'])).toList();
    final filtered = selectable.where(_matches).toList();

    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 360,
        height: 420,
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search, size: 20),
                hintText: l10n.searchHint,
                isDense: true,
              ),
              onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: selectable.isEmpty
                  ? Center(child: Text(widget.emptyHint))
                  : filtered.isEmpty
                      ? Center(child: Text(l10n.noResultsForSearch))
                      : ListView(
                          children: [
                            for (final item in filtered)
                              CheckboxListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text(widget.itemTitle(item)),
                                subtitle: widget.itemSubtitle != null
                                    ? Text(widget.itemSubtitle!(item))
                                    : null,
                                value: _selectedIds.contains(item['id']),
                                onChanged: (checked) => setState(() {
                                  if (checked ?? false) {
                                    _selectedIds.add(item['id'] as String);
                                  } else {
                                    _selectedIds.remove(item['id']);
                                  }
                                }),
                              ),
                          ],
                        ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.actionCancel)),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_selectedIds.toList()),
          child: Text(l10n.actionAdd),
        ),
      ],
    );
  }
}
