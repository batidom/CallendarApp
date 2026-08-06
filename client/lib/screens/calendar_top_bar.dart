import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../l10n/generated/app_localizations.dart';
import '../providers/providers.dart';
import '../services/app_window_controller.dart';
import '../services/reminder_engine.dart';
import '../utils/notification_formatting.dart';
import 'assistant_screen.dart';
import 'notifications_screen.dart';
import 'settings_screen.dart';
import 'social_screen.dart';

/// The calendar screen's title row: title, notifications bell (with unseen
/// badge + dropdown preview), friends/groups button (with a badge for
/// pending invites/requests), and the assistant/settings/logout/hide icons.
/// Owns its own "last seen" bookkeeping for the notifications badge — no
/// other part of the app needs to know when the user last opened it.
class CalendarTopBar extends ConsumerStatefulWidget {
  const CalendarTopBar({super.key, required this.onGoToDay});

  // Tapping a pending invite from the Invites tab pops SocialScreen with
  // that invite's day instead of resolving it there (see _EventInvitesTab)
  // — the calendar screen jumps to it so the pending-invite tile is right
  // there to accept/decline.
  final ValueChanged<DateTime> onGoToDay;

  @override
  ConsumerState<CalendarTopBar> createState() => _CalendarTopBarState();
}

class _CalendarTopBarState extends ConsumerState<CalendarTopBar> {
  DateTime _notificationsSeenAt = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 0),
      child: Row(
        children: [
          Icon(
            Icons.calendar_today,
            size: 18,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(l10n.calendarTitle, style: theme.textTheme.titleMedium),
          const Spacer(),
          _buildNotificationsButton(theme, l10n),
          _buildSocialButton(theme, l10n),
          IconButton(
            tooltip: l10n.tooltipAssistant,
            icon: const Icon(Icons.smart_toy_outlined, size: 18),
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const AssistantScreen())),
          ),
          IconButton(
            tooltip: l10n.tooltipSettings,
            icon: const Icon(Icons.settings_outlined, size: 18),
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
          IconButton(
            tooltip: l10n.tooltipSignOut,
            icon: const Icon(Icons.logout, size: 18),
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          ),
          IconButton(
            tooltip: l10n.tooltipHideEsc,
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => AppWindowController.instance.toggleVisibility(),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsButton(ThemeData theme, AppLocalizations l10n) {
    final List<FiredReminder> fired = ref.watch(reminderEngineProvider);
    final serverNotifications =
        ref.watch(notificationsProvider).valueOrNull ?? const [];

    final items = <NotificationItem>[
      for (final entry in fired)
        NotificationItem(message: entry.message(l10n), time: entry.firedAt),
      for (final notification in serverNotifications)
        NotificationItem(
          message: formatServerNotification(notification, l10n),
          time: DateTime.parse(notification['createdAt'] as String).toLocal(),
        ),
    ]..sort((a, b) => b.time.compareTo(a.time));

    final unseenCount = items
        .where((i) => i.time.isAfter(_notificationsSeenAt))
        .length;

    return PopupMenuButton<String>(
      tooltip: l10n.tooltipNotifications,
      onOpened: () => setState(() => _notificationsSeenAt = DateTime.now()),
      onSelected: (value) {
        if (value == 'view_all') {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const NotificationsScreen()),
          );
        }
      },
      itemBuilder: (context) => [
        if (items.isEmpty)
          PopupMenuItem(enabled: false, child: Text(l10n.noNotificationsYet))
        else
          for (final item in items.take(10))
            PopupMenuItem(
              enabled: false,
              child: SizedBox(
                width: 260,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.message,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      DateFormat.MMMd().add_jm().format(item.time),
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'view_all',
          child: Row(
            children: [
              const Icon(Icons.history, size: 16),
              const SizedBox(width: 8),
              Text(l10n.actionViewAllNotifications),
            ],
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Badge(
          isLabelVisible: unseenCount > 0,
          label: Text('$unseenCount'),
          child: const Icon(Icons.notifications_outlined, size: 18),
        ),
      ),
    );
  }

  Widget _buildSocialButton(ThemeData theme, AppLocalizations l10n) {
    final pendingInvites =
        ref.watch(pendingEventInvitesProvider).valueOrNull ?? const [];
    final incomingRequests =
        ref.watch(incomingFriendRequestsProvider).valueOrNull ?? const [];
    final badgeCount = pendingInvites.length + incomingRequests.length;

    return IconButton(
      tooltip: l10n.tooltipFriendsGroups,
      icon: Badge(
        isLabelVisible: badgeCount > 0,
        label: Text('$badgeCount'),
        child: const Icon(Icons.people_outline, size: 18),
      ),
      onPressed: () async {
        final targetDay = await Navigator.of(context).push<DateTime>(
          MaterialPageRoute(builder: (_) => const SocialScreen()),
        );
        if (targetDay != null) widget.onGoToDay(targetDay);
      },
    );
  }
}
