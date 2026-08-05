import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/remote/api_exception.dart';
import '../l10n/generated/app_localizations.dart';
import '../providers/providers.dart';

/// Attachments for a saved event. Visible to anyone who can see the event
/// (owner or any accepted invitee); upload/delete are only offered when
/// [canManage] is true (owner or an accepted 'editor' invitee).
class EventAttachmentsSection extends ConsumerStatefulWidget {
  const EventAttachmentsSection({super.key, required this.eventId, required this.canManage});

  final String eventId;
  final bool canManage;

  @override
  ConsumerState<EventAttachmentsSection> createState() => _EventAttachmentsSectionState();
}

class _EventAttachmentsSectionState extends ConsumerState<EventAttachmentsSection> {
  bool _isUploading = false;
  String? _openingAttachmentId;

  void _showError(Object error) {
    if (!mounted) return;
    final message = error is ApiException ? error.message : error.toString();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _upload() async {
    final l10n = AppLocalizations.of(context)!;
    final result = await FilePicker.pickFiles(dialogTitle: l10n.dialogChooseFileToAttach);
    final path = result?.files.single.path;
    if (path == null) return;

    setState(() => _isUploading = true);
    try {
      await ref.read(apiClientProvider).uploadAttachment(widget.eventId, path);
      ref.invalidate(eventAttachmentsProvider(widget.eventId));
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _delete(String attachmentId) async {
    try {
      await ref.read(apiClientProvider).deleteAttachment(widget.eventId, attachmentId);
      ref.invalidate(eventAttachmentsProvider(widget.eventId));
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _openAttachment(Map<String, dynamic> attachment) async {
    final attachmentId = attachment['id'] as String;
    setState(() => _openingAttachmentId = attachmentId);
    try {
      final cacheDir = await getTemporaryDirectory();
      final savePath = p.join(cacheDir.path, 'attachments', '$attachmentId-${attachment['filename']}');
      await ref
          .read(apiClientProvider)
          .downloadAttachment(widget.eventId, attachmentId, savePath);
      await launchUrl(Uri.file(savePath));
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _openingAttachmentId = null);
    }
  }

  IconData _iconFor(String mimeType) {
    if (mimeType.startsWith('image/')) return Icons.image_outlined;
    if (mimeType == 'application/pdf') return Icons.picture_as_pdf_outlined;
    if (mimeType.contains('word')) return Icons.description_outlined;
    if (mimeType.contains('sheet') || mimeType.contains('excel')) return Icons.table_chart_outlined;
    return Icons.insert_drive_file_outlined;
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final attachmentsAsync = ref.watch(eventAttachmentsProvider(widget.eventId));
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(l10n.attachmentsHeader, style: const TextStyle(fontWeight: FontWeight.w600)),
            const Spacer(),
            if (widget.canManage)
              TextButton.icon(
                onPressed: _isUploading ? null : _upload,
                icon: _isUploading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.attach_file, size: 16),
                label: Text(l10n.actionAddFile),
              ),
          ],
        ),
        attachmentsAsync.when(
          data: (attachments) => attachments.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(l10n.noAttachmentsYet),
                )
              : Column(
                  children: [
                    for (final attachment in attachments)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        leading: _openingAttachmentId == attachment['id']
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Icon(_iconFor(attachment['mimeType'] as String)),
                        title: Text(attachment['filename'] as String),
                        subtitle: Text(_formatSize(attachment['sizeBytes'] as int)),
                        onTap: () => _openAttachment(attachment),
                        trailing: widget.canManage
                            ? IconButton(
                                icon: const Icon(Icons.close, size: 18),
                                tooltip: l10n.tooltipDeleteAttachment,
                                onPressed: () => _delete(attachment['id'] as String),
                              )
                            : null,
                      ),
                  ],
                ),
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(),
          ),
          error: (error, _) => Text(l10n.failedToLoadAttachments(error.toString())),
        ),
      ],
    );
  }
}
