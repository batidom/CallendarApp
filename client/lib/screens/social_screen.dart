import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/remote/api_exception.dart';
import '../l10n/generated/app_localizations.dart';
import '../providers/providers.dart';

String _displayName(Map<String, dynamic> user) {
  final name = user['name'] as String? ?? '';
  final surname = user['surname'] as String?;
  return surname != null && surname.isNotEmpty ? '$name $surname' : name;
}

class SocialScreen extends ConsumerWidget {
  const SocialScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    // Same counts the main calendar screen's "Friends & Groups" badge sums
    // together (see calendar_screen.dart's _buildSocialButton) — broken back
    // out per-tab here so it's obvious which subsection actually has
    // something waiting, instead of just "something, somewhere".
    final incomingRequestsCount = ref.watch(incomingFriendRequestsProvider).valueOrNull?.length ?? 0;
    final pendingInvitesCount = ref.watch(pendingEventInvitesProvider).valueOrNull?.length ?? 0;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.socialTitle),
          bottom: TabBar(tabs: [
            Tab(text: l10n.tabFriends),
            Tab(child: _TabLabelWithBadge(label: l10n.tabRequests, count: incomingRequestsCount)),
            Tab(text: l10n.tabGroups),
            Tab(child: _TabLabelWithBadge(label: l10n.tabInvites, count: pendingInvitesCount)),
          ]),
        ),
        body: const TabBarView(children: [
          _FriendsTab(),
          _RequestsTab(),
          _GroupsTab(),
          _EventInvitesTab(),
        ]),
      ),
    );
  }
}

/// A tab label with the same kind of count badge used elsewhere (see
/// calendar_screen.dart's notification bell / social button) — hidden
/// entirely when there's nothing pending, so a quiet tab stays quiet.
class _TabLabelWithBadge extends StatelessWidget {
  const _TabLabelWithBadge({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Badge(
      isLabelVisible: count > 0,
      label: Text('$count'),
      offset: const Offset(14, -8),
      child: Text(label),
    );
  }
}

void _showError(BuildContext context, Object error) {
  final message = error is ApiException ? error.message : error.toString();
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

class _FriendsTab extends ConsumerStatefulWidget {
  const _FriendsTab();

  @override
  ConsumerState<_FriendsTab> createState() => _FriendsTabState();
}

class _FriendsTabState extends ConsumerState<_FriendsTab> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>>? _searchResults;
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() => _searchResults = null);
      return;
    }
    setState(() => _isSearching = true);
    try {
      final results = await ref.read(apiClientProvider).searchUsers(query);
      if (mounted) setState(() => _searchResults = results);
    } catch (error) {
      if (mounted) _showError(context, error);
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _sendRequest(String username) async {
    try {
      await ref.read(apiClientProvider).sendFriendRequest(username);
      ref.invalidate(outgoingFriendRequestsProvider);
      await _search();
    } catch (error) {
      if (mounted) _showError(context, error);
    }
  }

  Future<void> _removeFriend(String userId) async {
    try {
      await ref.read(apiClientProvider).removeFriend(userId);
      ref.invalidate(friendsProvider);
    } catch (error) {
      if (mounted) _showError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final friendsAsync = ref.watch(friendsProvider);
    final l10n = AppLocalizations.of(context)!;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: l10n.searchByUsername,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _isSearching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
            ),
            onSubmitted: (_) => _search(),
            onChanged: (_) => _search(),
          ),
        ),
        Expanded(
          child: _searchResults != null
              ? _buildSearchResults(l10n)
              : friendsAsync.when(
                  data: (friends) => friends.isEmpty
                      ? Center(child: Text(l10n.noFriendsYetHint))
                      : ListView(
                          children: [
                            for (final friend in friends)
                              ListTile(
                                title: Text(_displayName(friend)),
                                subtitle: Text('@${friend['username']}'),
                                trailing: IconButton(
                                  icon: const Icon(Icons.person_remove_outlined),
                                  tooltip: l10n.tooltipRemoveFriend,
                                  onPressed: () => _removeFriend(friend['id'] as String),
                                ),
                              ),
                          ],
                        ),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Center(child: Text(l10n.failedToLoadFriends(error.toString()))),
                ),
        ),
      ],
    );
  }

  Widget _buildSearchResults(AppLocalizations l10n) {
    final results = _searchResults!;
    if (results.isEmpty) {
      return Center(child: Text(l10n.noUsersFound));
    }
    return ListView(
      children: [
        for (final user in results)
          ListTile(
            title: Text(_displayName(user)),
            subtitle: Text('@${user['username']}'),
            trailing: _buildRelationshipAction(user, l10n),
          ),
      ],
    );
  }

  Widget _buildRelationshipAction(Map<String, dynamic> user, AppLocalizations l10n) {
    switch (user['relationshipStatus'] as String) {
      case 'friends':
        return Text(l10n.relationshipFriends);
      case 'pending_outgoing':
        return Text(l10n.relationshipRequested);
      case 'pending_incoming':
        return Text(l10n.relationshipCheckRequestsTab);
      default:
        return TextButton(
          onPressed: () => _sendRequest(user['username'] as String),
          child: Text(l10n.actionAdd),
        );
    }
  }
}

class _RequestsTab extends ConsumerWidget {
  const _RequestsTab();

  Future<void> _accept(WidgetRef ref, BuildContext context, String id) async {
    try {
      await ref.read(apiClientProvider).acceptFriendRequest(id);
      ref.invalidate(incomingFriendRequestsProvider);
      ref.invalidate(friendsProvider);
    } catch (error) {
      if (context.mounted) _showError(context, error);
    }
  }

  Future<void> _decline(WidgetRef ref, BuildContext context, String id) async {
    try {
      await ref.read(apiClientProvider).declineFriendRequest(id);
      ref.invalidate(incomingFriendRequestsProvider);
    } catch (error) {
      if (context.mounted) _showError(context, error);
    }
  }

  Future<void> _cancel(WidgetRef ref, BuildContext context, String id) async {
    try {
      await ref.read(apiClientProvider).cancelFriendRequest(id);
      ref.invalidate(outgoingFriendRequestsProvider);
    } catch (error) {
      if (context.mounted) _showError(context, error);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incomingAsync = ref.watch(incomingFriendRequestsProvider);
    final outgoingAsync = ref.watch(outgoingFriendRequestsProvider);
    final l10n = AppLocalizations.of(context)!;

    return ListView(
      children: [
        _SectionHeader(l10n.sectionIncoming),
        incomingAsync.when(
          data: (requests) => requests.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(l10n.noIncomingRequests),
                )
              : Column(children: [
                  for (final request in requests)
                    ListTile(
                      title: Text(_displayName(request['user'] as Map<String, dynamic>)),
                      subtitle: Text('@${(request['user'] as Map<String, dynamic>)['username']}'),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(
                          icon: const Icon(Icons.check, color: Colors.green),
                          onPressed: () => _accept(ref, context, request['id'] as String),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.red),
                          onPressed: () => _decline(ref, context, request['id'] as String),
                        ),
                      ]),
                    ),
                ]),
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => Padding(
            padding: const EdgeInsets.all(16),
            child: Text(l10n.failedToLoadGeneric(error.toString())),
          ),
        ),
        const Divider(),
        _SectionHeader(l10n.sectionSent),
        outgoingAsync.when(
          data: (requests) => requests.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(l10n.noPendingSentRequests),
                )
              : Column(children: [
                  for (final request in requests)
                    ListTile(
                      title: Text(_displayName(request['user'] as Map<String, dynamic>)),
                      subtitle: Text('@${(request['user'] as Map<String, dynamic>)['username']}'),
                      trailing: TextButton(
                        onPressed: () => _cancel(ref, context, request['id'] as String),
                        child: Text(l10n.actionCancel),
                      ),
                    ),
                ]),
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => Padding(
            padding: const EdgeInsets.all(16),
            child: Text(l10n.failedToLoadGeneric(error.toString())),
          ),
        ),
      ],
    );
  }
}

class _GroupsTab extends ConsumerWidget {
  const _GroupsTab();

  Future<void> _createGroup(WidgetRef ref, BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final name = await _promptForName(context, title: l10n.dialogNewGroupTitle);
    if (name == null || name.isEmpty) return;
    try {
      await ref.read(apiClientProvider).createGroup(name);
      ref.invalidate(groupsProvider);
    } catch (error) {
      if (context.mounted) _showError(context, error);
    }
  }

  Future<void> _renameGroup(WidgetRef ref, BuildContext context, String groupId, String currentName) async {
    final l10n = AppLocalizations.of(context)!;
    final name =
        await _promptForName(context, title: l10n.dialogRenameGroupTitle, initialValue: currentName);
    if (name == null || name.isEmpty) return;
    try {
      await ref.read(apiClientProvider).renameGroup(groupId, name);
      ref.invalidate(groupsProvider);
    } catch (error) {
      if (context.mounted) _showError(context, error);
    }
  }

  Future<void> _deleteGroup(WidgetRef ref, BuildContext context, String groupId) async {
    try {
      await ref.read(apiClientProvider).deleteGroup(groupId);
      ref.invalidate(groupsProvider);
    } catch (error) {
      if (context.mounted) _showError(context, error);
    }
  }

  Future<void> _addMember(WidgetRef ref, BuildContext context, String groupId) async {
    final l10n = AppLocalizations.of(context)!;
    final friends = await ref.read(friendsProvider.future);
    if (!context.mounted) return;
    final selected = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(l10n.dialogAddFriendTitle),
        children: [
          if (friends.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(l10n.addFriendsFirstHint),
            ),
          for (final friend in friends)
            SimpleDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop(friend),
              child: Text(_displayName(friend)),
            ),
        ],
      ),
    );
    if (selected == null) return;
    try {
      await ref.read(apiClientProvider).addGroupMember(groupId, selected['id'] as String);
      ref.invalidate(groupsProvider);
    } catch (error) {
      if (context.mounted) _showError(context, error);
    }
  }

  Future<void> _removeMember(WidgetRef ref, BuildContext context, String groupId, String userId) async {
    try {
      await ref.read(apiClientProvider).removeGroupMember(groupId, userId);
      ref.invalidate(groupsProvider);
    } catch (error) {
      if (context.mounted) _showError(context, error);
    }
  }

  Future<String?> _promptForName(BuildContext context, {required String title, String? initialValue}) {
    final controller = TextEditingController(text: initialValue);
    final l10n = AppLocalizations.of(context)!;
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: l10n.fieldGroupName),
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
            child: Text(l10n.actionSave),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(groupsProvider);
    final membershipsAsync = ref.watch(groupMembershipsProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: ListView(
        children: [
          _SectionHeader(l10n.sectionMyGroups),
          groupsAsync.when(
            data: (groups) => groups.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(l10n.noGroupsYetHint),
                  )
                : Column(children: [
                    for (final group in groups)
                      ExpansionTile(
                        title: Text(group['name'] as String),
                        subtitle: Text(l10n.memberCount((group['members'] as List).length)),
                        children: [
                          for (final member in (group['members'] as List).cast<Map<String, dynamic>>())
                            ListTile(
                              dense: true,
                              title: Text(_displayName(member['user'] as Map<String, dynamic>)),
                              trailing: IconButton(
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: () => _removeMember(
                                  ref,
                                  context,
                                  group['id'] as String,
                                  (member['user'] as Map<String, dynamic>)['id'] as String,
                                ),
                              ),
                            ),
                          OverflowBar(children: [
                            TextButton.icon(
                              onPressed: () => _addMember(ref, context, group['id'] as String),
                              icon: const Icon(Icons.person_add_alt, size: 16),
                              label: Text(l10n.actionAddMember),
                            ),
                            TextButton.icon(
                              onPressed: () => _renameGroup(
                                ref,
                                context,
                                group['id'] as String,
                                group['name'] as String,
                              ),
                              icon: const Icon(Icons.edit, size: 16),
                              label: Text(l10n.actionRename),
                            ),
                            TextButton.icon(
                              onPressed: () => _deleteGroup(ref, context, group['id'] as String),
                              icon: const Icon(Icons.delete_outline, size: 16),
                              label: Text(l10n.actionDelete),
                            ),
                          ]),
                        ],
                      ),
                  ]),
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(l10n.failedToLoadGroups(error.toString())),
            ),
          ),
          const Divider(),
          // Membership here doesn't require accepting anything (see the
          // Group model comment on the backend) — this is the only place a
          // member can see where they've been placed, so it's read-only:
          // no rename/delete/add-member actions, only the owner manages
          // that.
          _SectionHeader(l10n.sectionGroupsImIn),
          membershipsAsync.when(
            data: (groups) => groups.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(l10n.notInAnyGroupsHint),
                  )
                : Column(children: [
                    for (final group in groups)
                      ExpansionTile(
                        title: Text(group['name'] as String),
                        subtitle: Text(l10n.groupOwnedBy(
                          _displayName(group['owner'] as Map<String, dynamic>),
                        )),
                        children: [
                          for (final member in (group['members'] as List).cast<Map<String, dynamic>>())
                            ListTile(
                              dense: true,
                              title: Text(_displayName(member['user'] as Map<String, dynamic>)),
                            ),
                        ],
                      ),
                  ]),
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(l10n.failedToLoadGroups(error.toString())),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        mini: true,
        tooltip: l10n.dialogNewGroupTitle,
        onPressed: () => _createGroup(ref, context),
        child: const Icon(Icons.add),
      ),
    );
  }
}

// Accepting/declining now only happens from the calendar itself (see
// PendingInviteScreen) — it shows the full event and reads much better than
// a bare list row here ever could. This tab is just a way to notice a
// pending invite and jump straight to its day; tapping one pops this whole
// screen with that day, which _buildSocialButton (calendar_screen.dart)
// picks up and scrolls the calendar to.
class _EventInvitesTab extends ConsumerWidget {
  const _EventInvitesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invitesAsync = ref.watch(pendingEventInvitesProvider);
    final l10n = AppLocalizations.of(context)!;

    return invitesAsync.when(
      data: (invites) => invites.isEmpty
          ? Center(child: Text(l10n.noPendingEventInvites))
          : ListView(
              children: [
                for (final invite in invites)
                  ListTile(
                    title: Text((invite['event'] as Map<String, dynamic>)['title'] as String),
                    subtitle: Text(_inviteSubtitle(invite, l10n)),
                    trailing: const Icon(Icons.chevron_right, size: 20),
                    onTap: () => Navigator.of(context).pop(_inviteDay(invite)),
                  ),
              ],
            ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text(l10n.failedToLoadInvites(error.toString()))),
    );
  }

  String _inviteSubtitle(Map<String, dynamic> invite, AppLocalizations l10n) {
    final invitedBy = invite['invitedBy'] as Map<String, dynamic>;
    final event = invite['event'] as Map<String, dynamic>;
    final startTime = event['startTime'] as String?;
    final when = startTime != null
        ? DateFormat.yMMMd().add_jm().format(DateTime.parse(startTime).toLocal())
        : l10n.noSpecificTimeLabel;
    return l10n.inviteSubtitle(_displayName(invitedBy), when);
  }

  // Null for a bare backlog idea (no day/time at all) — there's nowhere on
  // the calendar grid to jump to, so the tap just closes back to it as-is.
  DateTime? _inviteDay(Map<String, dynamic> invite) {
    final event = invite['event'] as Map<String, dynamic>;
    final startTime = event['startTime'] as String?;
    if (startTime != null) return DateTime.parse(startTime).toLocal();
    final assignedDate = event['assignedDate'] as String?;
    if (assignedDate != null) return DateTime.parse(assignedDate);
    return null;
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelLarge
            ?.copyWith(color: Theme.of(context).colorScheme.primary),
      ),
    );
  }
}
