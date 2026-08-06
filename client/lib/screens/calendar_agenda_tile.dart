import 'package:flutter/material.dart';

import '../data/local/app_database.dart';
import '../l10n/generated/app_localizations.dart';
import '../utils/event_colors.dart';
import '../utils/recurrence.dart';

/// Normalizes a timed occurrence or a loose task into one shape so the day
/// agenda can render and sort them together.
class AgendaEntry {
  AgendaEntry.timed(EventOccurrence occurrence)
    : event = occurrence.master,
      start = occurrence.start,
      end = occurrence.end,
      isLoose = false;

  AgendaEntry.loose(this.event) : start = null, end = null, isLoose = true;

  final Event event;
  final DateTime? start;
  final DateTime? end;
  final bool isLoose;

  String get id => event.id;
  String get title => event.title;
  bool get isAllDay => event.isAllDay;
  bool get isPending => event.pendingOperation != null;
  bool get isRecurring => event.rrule != null;
  bool get hasDescription => (event.description ?? '').trim().isNotEmpty;
}

class AgendaTile extends StatelessWidget {
  const AgendaTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.colorId,
    required this.isPending,
    required this.dragData,
    required this.onTap,
    this.isRecurring = false,
    this.isLoose = false,
    this.hasDescription = false,
    this.draggable = true,
    this.isHappeningNow = false,
    this.hasFiredReminder = false,
    this.isShared = false,
    this.isPendingInvite = false,
    this.ownerName,
  });

  final String title;
  final String subtitle;
  final String colorId;
  final bool isPending;
  final bool isRecurring;
  final bool isLoose;
  final bool hasDescription;
  final bool draggable;
  // Mutually exclusive (see CalendarScreen._buildAgendaTile) — a timed event
  // currently between its start/end, vs. one whose reminder fired but hasn't
  // started (or has no end) yet. Different colors so the two states read
  // distinctly at a glance rather than just "something about this one is
  // special".
  final bool isHappeningNow;
  final bool hasFiredReminder;
  // True when this task belongs to someone else and was shared with the
  // current user (myRole != 'owner') — surfaced as a small icon so a task
  // someone else added is obviously distinct from the user's own, without
  // having to open it first.
  final bool isShared;
  // True for a still-pending invite (myRole == 'invited') — takes over the
  // tile's whole appearance (see build below) rather than just adding an
  // icon, since this isn't "my" task yet at all, just something waiting on
  // a yes/no from the user.
  final bool isPendingInvite;
  final String? ownerName;
  final Event dragData;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = colorForEvent(colorId);
    final l10n = AppLocalizations.of(context)!;
    final highlightColor = isHappeningNow
        ? Colors.green
        : hasFiredReminder
        ? Colors.amber.shade800
        : null;

    // Loose (no specific time) tasks render as a light, outlined chip —
    // visually distinct from a fully-scheduled tile with a solid color bar,
    // so it's obvious at a glance which tasks are still just placeholders.
    // A highlight (happening now / reminder fired) takes priority over that
    // styling, but loose tasks never carry one anyway (see _buildAgendaTile).
    // A pending invite overrides all of the above — see isPendingInvite.
    final content = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: isPendingInvite
            ? BoxDecoration(
                border: Border.all(color: Colors.blue.shade300, width: 1.2),
                borderRadius: BorderRadius.circular(8),
                color: Colors.blue.withAlpha(14),
              )
            : highlightColor != null
            ? BoxDecoration(
                border: Border.all(color: highlightColor),
                borderRadius: BorderRadius.circular(8),
                color: highlightColor.withAlpha(28),
              )
            : isLoose
            ? BoxDecoration(
                border: Border.all(color: color.withAlpha(160)),
                borderRadius: BorderRadius.circular(8),
                color: color.withAlpha(12),
              )
            : null,
        child: Row(
          children: [
            if (isPendingInvite)
              Icon(Icons.mail_outline, size: 18, color: Colors.blue.shade400)
            else if (isLoose)
              Icon(Icons.circle_outlined, size: 14, color: color)
            else
              Container(
                width: 4,
                height: 36,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: isLoose ? FontWeight.normal : FontWeight.w500,
                      fontStyle: isLoose ? FontStyle.italic : FontStyle.normal,
                    ),
                  ),
                  Text(
                    isPendingInvite
                        ? (ownerName != null
                              ? l10n.sharedByOwner(ownerName!)
                              : l10n.pendingInviteBadge)
                        : subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isPendingInvite
                          ? Colors.blue.shade400
                          : Colors.grey.shade600,
                      fontWeight: isPendingInvite
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            if (isShared && !isPendingInvite)
              Tooltip(
                message: ownerName != null
                    ? l10n.tooltipSharedEvent(ownerName!)
                    : l10n.sharedWithYou,
                child: Icon(
                  Icons.group_outlined,
                  size: 15,
                  color: Colors.blue.shade400,
                ),
              ),
            if (hasDescription)
              Tooltip(
                message: l10n.tooltipHasDescription,
                child: Icon(Icons.notes, size: 15, color: Colors.grey.shade500),
              ),
            if (isRecurring)
              Tooltip(
                message: l10n.tooltipRepeats,
                child: Icon(
                  Icons.repeat,
                  size: 16,
                  color: Colors.grey.shade500,
                ),
              ),
            if (isPending)
              Tooltip(
                message: l10n.tooltipNotSynced,
                child: Icon(
                  Icons.cloud_off,
                  size: 16,
                  color: Colors.grey.shade500,
                ),
              ),
          ],
        ),
      ),
    );

    if (!draggable) return content;

    // A plain (not long-press) drag, matching the backlog chips — the inner
    // InkWell still gets a clean tap when the pointer doesn't move far
    // enough to count as a drag, so quick taps keep opening the edit form.
    return Draggable<Event>(
      data: dragData,
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(width: 220, child: content),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: content),
      child: content,
    );
  }
}
