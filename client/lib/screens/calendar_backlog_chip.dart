import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local/app_database.dart';
import '../l10n/generated/app_localizations.dart';
import '../providers/providers.dart';
import '../utils/event_colors.dart';
import 'event_form_screen.dart';
import 'pending_invite_screen.dart';

class BacklogChip extends ConsumerWidget {
  const BacklogChip({super.key, required this.event, required this.index});

  final Event event;
  // Position within the currently-displayed backlog list — only used to
  // wire up the drag_indicator handle to ReorderableListView's onReorder;
  // unrelated to backlogOrder itself, which is recomputed for the whole
  // list once a drag actually completes (see CalendarBacklogPanel).
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = colorForEvent(event.id);
    final hasDescription = (event.description ?? '').trim().isNotEmpty;
    final isPendingInvite = event.myRole == 'invited';
    final l10n = AppLocalizations.of(context)!;

    final content = Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(
          color: isPendingInvite ? Colors.blue.shade300 : color,
        ),
        borderRadius: BorderRadius.circular(6),
        color: isPendingInvite ? Colors.blue.withAlpha(14) : null,
      ),
      child: Row(
        children: [
          // A separate drag affordance from the rest of the chip (which
          // stays a Draggable<Event> for dragging OUT onto a calendar day)
          // — grabbing this handle instead reorders within this list. A
          // still-pending invite can't be scheduled until accepted, so it
          // skips both drag affordances (see the outer Draggable below too).
          if (!isPendingInvite)
            ReorderableDragStartListener(
              index: index,
              child: Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Icon(
                  Icons.drag_indicator,
                  size: 16,
                  color: Colors.grey.shade400,
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Tooltip(
                message: l10n.pendingInviteBadge,
                child: Icon(
                  Icons.mail_outline,
                  size: 14,
                  color: Colors.blue.shade400,
                ),
              ),
            ),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => isPendingInvite
                      ? PendingInviteScreen(event: event)
                      : EventFormScreen(existingEvent: event),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        event.title,
                        style: TextStyle(
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                          fontWeight: isPendingInvite
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: isPendingInvite ? Colors.blue.shade400 : null,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (event.myRole != 'owner' && !isPendingInvite)
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Tooltip(
                          message: event.ownerDisplayName != null
                              ? l10n.tooltipSharedEvent(event.ownerDisplayName!)
                              : l10n.sharedWithYou,
                          child: Icon(
                            Icons.group_outlined,
                            size: 12,
                            color: Colors.blue.shade400,
                          ),
                        ),
                      ),
                    if (hasDescription)
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Icon(
                          Icons.notes,
                          size: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    if (event.pendingOperation != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Icon(
                          Icons.cloud_off,
                          size: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    // Deleting is owner-only server-side (see
                    // EventsService.remove / findOwnedOrThrow) — any
                    // accepted invitee can change an event's
                    // content/schedule but not remove it entirely.
                    if (event.myRole == 'owner')
                      InkWell(
                        onTap: () => ref
                            .read(eventsRepositoryProvider)
                            .deleteEvent(event.id),
                        child: Icon(
                          Icons.close,
                          size: 14,
                          color: Colors.grey.shade500,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (isPendingInvite) return content;

    return Draggable<Event>(
      data: event,
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(width: 200, child: content),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: content),
      child: content,
    );
  }
}
