import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/local/app_database.dart';
import '../data/remote/api_exception.dart';
import '../l10n/generated/app_localizations.dart';
import '../providers/providers.dart';

/// Read-only view for a still-pending invite (myRole == 'invited'), reached
/// by tapping its tile on the calendar. Deliberately not the normal
/// [EventFormScreen] — nothing here is editable (the backend rejects edits
/// from an invitee until they've accepted, see EventsService.
/// findEditableOrThrow), so this only ever shows what the event is and lets
/// the user accept or decline it.
class PendingInviteScreen extends ConsumerStatefulWidget {
  const PendingInviteScreen({super.key, required this.event});

  final Event event;

  @override
  ConsumerState<PendingInviteScreen> createState() => _PendingInviteScreenState();
}

class _PendingInviteScreenState extends ConsumerState<PendingInviteScreen> {
  bool _isResponding = false;

  Future<void> _respond(bool accept) async {
    final inviteId = widget.event.inviteId;
    if (inviteId == null) return;

    setState(() => _isResponding = true);
    try {
      await ref.read(eventsRepositoryProvider).respondToInvite(widget.event.id, inviteId, accept);
      // The Invites tab and the main bar's badge count both read this — the
      // event itself already updates live via the local Drift stream, but
      // this needs an explicit nudge since CalendarScreen holds it open
      // permanently (see _buildSocialButton), so it never naturally
      // refetches on its own.
      ref.invalidate(pendingEventInvitesProvider);
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _isResponding = false);
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.inviteRespondFailed(error.message))));
    }
  }

  String _formatWhen(AppLocalizations l10n) {
    final event = widget.event;
    if (event.startTime != null) {
      return event.isAllDay
          ? DateFormat.yMMMd().format(event.startTime!)
          : DateFormat.yMMMd().add_jm().format(event.startTime!);
    }
    if (event.assignedDate != null) {
      return DateFormat.yMMMd().format(event.assignedDate!);
    }
    return l10n.noSpecificTimeLabel;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final event = widget.event;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.pendingInviteScreenTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Icon(Icons.mail_outline, size: 18, color: Colors.blue.shade400),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  event.ownerDisplayName != null
                      ? l10n.pendingInviteMessage(event.ownerDisplayName!)
                      : l10n.sharedWithYou,
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(event.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.event_outlined, size: 18, color: Colors.grey.shade600),
              const SizedBox(width: 8),
              Text(_formatWhen(l10n)),
            ],
          ),
          if ((event.location ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.location_on_outlined, size: 18, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Expanded(child: Text(event.location!)),
              ],
            ),
          ],
          if ((event.description ?? '').isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(event.description!),
          ],
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isResponding ? null : () => _respond(false),
                  child: Text(l10n.actionDecline),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _isResponding ? null : () => _respond(true),
                  child: _isResponding
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.actionAccept),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
