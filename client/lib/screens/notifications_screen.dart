import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../l10n/generated/app_localizations.dart';
import '../providers/providers.dart';
import '../utils/notification_formatting.dart';

/// The bell dropdown only ever shows the 10 most recent items and forgets
/// them once you navigate away — this is the full history behind it, for
/// browsing back further than "what just happened".
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final fired = ref.watch(reminderEngineProvider);
    final serverNotifications = ref.watch(notificationsProvider).valueOrNull ?? const [];

    final items = <NotificationItem>[
      for (final entry in fired) NotificationItem(message: entry.message(l10n), time: entry.firedAt),
      for (final notification in serverNotifications)
        NotificationItem(
          message: formatServerNotification(notification, l10n),
          time: DateTime.parse(notification['createdAt'] as String).toLocal(),
        ),
    ]..sort((a, b) => b.time.compareTo(a.time));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.notificationsScreenTitle)),
      body: items.isEmpty
          ? Center(child: Text(l10n.noNotificationsYet))
          : ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = items[index];
                return ListTile(
                  title: Text(item.message),
                  subtitle: Text(DateFormat.yMMMd().add_jm().format(item.time)),
                );
              },
            ),
    );
  }
}
