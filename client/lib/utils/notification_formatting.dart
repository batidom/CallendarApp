import 'package:intl/intl.dart';

import '../l10n/generated/app_localizations.dart';

/// A local reminder firing and a server notification look different on the
/// wire, but the bell dropdown and the notifications archive both just want
/// "a line of text plus when it happened" — this is that shared shape.
class NotificationItem {
  const NotificationItem({required this.message, required this.time});
  final String message;
  final DateTime time;
}

// type is a free-form discriminator server-side (see the Notification model
// comment) so the message is composed here rather than server-side — that
// keeps it in the viewer's own UI language instead of whatever language
// happened to be active when the notification was created.
String formatServerNotification(Map<String, dynamic> notification, AppLocalizations l10n) {
  final actor = notification['actor'] as Map<String, dynamic>;
  final actorName = actor['name'] as String;
  final eventTitle = notification['eventTitle'] as String? ?? '';
  final oldValue = notification['oldValue'] as String?;
  final newValue = notification['newValue'] as String?;
  switch (notification['type']) {
    case 'friend_request_received':
      return l10n.notificationFriendRequestReceived(actorName);
    case 'friend_request_accepted':
      return l10n.notificationFriendRequestAccepted(actorName);
    case 'left_event':
      return l10n.notificationLeftEvent(actorName, eventTitle);
    case 'invite_accepted':
      return l10n.notificationInviteAccepted(actorName, eventTitle);
    case 'invite_declined':
      return l10n.notificationInviteDeclined(actorName, eventTitle);
    case 'date_changed':
      return l10n.notificationDateChanged(
        actorName,
        eventTitle,
        _formatNotificationDate(oldValue, l10n),
        _formatNotificationDate(newValue, l10n),
      );
    case 'time_changed':
      return l10n.notificationTimeChanged(
        actorName,
        eventTitle,
        _formatNotificationTime(oldValue, l10n),
        _formatNotificationTime(newValue, l10n),
      );
    case 'location_changed':
      return l10n.notificationLocationChanged(
        actorName,
        eventTitle,
        _formatNotificationText(oldValue, l10n),
        _formatNotificationText(newValue, l10n),
      );
    case 'description_changed':
      return l10n.notificationDescriptionChanged(
        actorName,
        eventTitle,
        _formatNotificationText(oldValue, l10n),
        _formatNotificationText(newValue, l10n),
      );
    default:
      return actorName;
  }
}

String _formatNotificationDate(String? iso, AppLocalizations l10n) {
  if (iso == null) return l10n.notificationEmptyValue;
  return DateFormat.yMMMd().format(DateTime.parse(iso).toLocal());
}

String _formatNotificationTime(String? iso, AppLocalizations l10n) {
  if (iso == null) return l10n.notificationEmptyValue;
  return DateFormat.jm().format(DateTime.parse(iso).toLocal());
}

// Location/description are free text, so this is the closest to "exactly
// what changed" that still fits in the notification dropdown's width.
String _formatNotificationText(String? value, AppLocalizations l10n) {
  if (value == null || value.isEmpty) return l10n.notificationEmptyValue;
  const maxLength = 60;
  return value.length > maxLength ? '${value.substring(0, maxLength)}…' : value;
}
