import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../data/remote/api_exception.dart';
import '../l10n/generated/app_localizations.dart';
import '../providers/providers.dart';
import '../utils/app_locale.dart';

enum _Role { user, assistant, error }

class _ChatEntry {
  _ChatEntry.user(this.text)
      : role = _Role.user,
        pendingDeletes = null;

  _ChatEntry.assistant(this.text, {this.pendingDeletes}) : role = _Role.assistant;

  _ChatEntry.error(this.text)
      : role = _Role.error,
        pendingDeletes = null;

  final _Role role;
  final String text;
  final List<Map<String, dynamic>>? pendingDeletes;
}

/// A chat interface for the local-LLM calendar assistant (see backend
/// src/assistant/). The mic button records locally and sends the clip to
/// the backend's Whisper endpoint, filling the input box with the
/// transcript for review rather than auto-sending. Conversation history
/// lives only in this screen's state (not persisted), matching the
/// backend's stateless-per-request design.
class AssistantScreen extends ConsumerStatefulWidget {
  const AssistantScreen({super.key});

  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends ConsumerState<AssistantScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final List<_ChatEntry> _entries = [];
  // Plain-text turns sent back to the backend as conversation context —
  // kept separate from _entries since error bubbles and confirmation cards
  // aren't part of what the LLM itself should see replayed.
  final List<Map<String, String>> _history = [];
  bool _isSending = false;

  final _recorder = AudioRecorder();
  bool _isRecording = false;
  bool _isTranscribing = false;
  // Driven by the recorder's amplitude stream so the mic button can pulse
  // with the user's actual voice, and so recording can stop itself once
  // they've clearly finished talking instead of requiring a second tap.
  double _micLevel = 0;
  StreamSubscription<Amplitude>? _amplitudeSub;
  bool _hasHeardSpeech = false;
  Timer? _silenceTimer;
  Timer? _maxRecordingTimer;

  // dBFS below this is treated as silence — recorder amplitude on Windows
  // sits around -50 to -160 dB with nobody talking and rises toward 0 dB
  // with normal speech, so this sits comfortably above the noise floor
  // without requiring the user to speak unusually loudly.
  static const _speechThresholdDb = -30.0;
  static const _silenceStopDelay = Duration(milliseconds: 1400);
  static const _maxRecordingDuration = Duration(seconds: 60);

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _amplitudeSub?.cancel();
    _silenceTimer?.cancel();
    _maxRecordingTimer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isSending) return;
    _textController.clear();

    setState(() {
      _entries.add(_ChatEntry.user(text));
      _history.add({'role': 'user', 'content': text});
      _isSending = true;
    });
    _scrollToBottom();

    final now = DateTime.now();
    final language = ref.read(settingsControllerProvider).language;
    try {
      final response = await ref.read(apiClientProvider).sendAssistantMessage(
            messages: List.of(_history),
            clientNowLocal: now.toIso8601String().split('.').first,
            utcOffsetMinutes: now.timeZoneOffset.inMinutes,
            language: resolveLanguageCode(language),
          );

      final reply = response['reply'] as String? ?? '';
      final pendingDeletes = ((response['pendingDeletes'] as List?) ?? const [])
          .cast<Map<String, dynamic>>();
      final actionsPerformed = (response['actionsPerformed'] as List?) ?? const [];

      setState(() {
        _entries.add(_ChatEntry.assistant(
          reply,
          pendingDeletes: pendingDeletes.isEmpty ? null : pendingDeletes,
        ));
        _history.add({
          'role': 'assistant',
          'content': reply.isNotEmpty
              ? reply
              : (pendingDeletes.isNotEmpty
                  ? "(proposed deleting: ${pendingDeletes.map((p) => p['title']).join(', ')})"
                  : ''),
        });
      });

      if (actionsPerformed.isNotEmpty) {
        ref.invalidate(eventsForVisibleRangeProvider);
      }
    } catch (error) {
      final message = error is ApiException ? error.message : error.toString();
      setState(() {
        _entries.add(_ChatEntry.error(
          AppLocalizations.of(context)!.assistantErrorGeneric(message),
        ));
      });
    } finally {
      if (mounted) setState(() => _isSending = false);
      _scrollToBottom();
    }
  }

  // Maps the recorder's raw dBFS reading onto a 0..1 level used both for the
  // mic button's pulse animation and for deciding whether the user is
  // currently speaking.
  double _levelFromDb(double db) {
    const floor = -50.0;
    final clamped = db.clamp(floor, 0.0);
    return (clamped - floor) / -floor;
  }

  void _onAmplitude(Amplitude amplitude) {
    if (!mounted) return;
    setState(() => _micLevel = _levelFromDb(amplitude.current));

    if (amplitude.current > _speechThresholdDb) {
      _hasHeardSpeech = true;
      _silenceTimer?.cancel();
      _silenceTimer = null;
    } else if (_hasHeardSpeech && _silenceTimer == null) {
      // Wait for a beat of continued silence before stopping — a single
      // quiet sample (a natural pause between words) shouldn't cut the
      // user off mid-sentence.
      _silenceTimer = Timer(_silenceStopDelay, () {
        if (_isRecording) _toggleRecording();
      });
    }
  }

  void _stopListening() {
    _amplitudeSub?.cancel();
    _amplitudeSub = null;
    _silenceTimer?.cancel();
    _silenceTimer = null;
    _maxRecordingTimer?.cancel();
    _maxRecordingTimer = null;
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      _stopListening();
      final path = await _recorder.stop();
      setState(() {
        _isRecording = false;
        _micLevel = 0;
      });
      if (path == null) return;

      setState(() => _isTranscribing = true);
      try {
        final language = resolveLanguageCode(ref.read(settingsControllerProvider).language);
        final text = await ref.read(apiClientProvider).transcribeAudio(path, language);
        if (text.isNotEmpty) {
          _textController.text = text;
          _textController.selection = TextSelection.collapsed(offset: text.length);
        }
      } catch (error) {
        final message = error is ApiException ? error.message : error.toString();
        if (mounted) {
          setState(() {
            _entries.add(_ChatEntry.error(AppLocalizations.of(context)!.assistantErrorGeneric(message)));
          });
        }
      } finally {
        if (mounted) setState(() => _isTranscribing = false);
      }
      return;
    }

    if (!await _recorder.hasPermission()) return;
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/assistant_voice_${DateTime.now().millisecondsSinceEpoch}.wav';
    final settings = ref.read(settingsControllerProvider);
    final device = settings.microphoneDeviceId != null
        ? InputDevice(id: settings.microphoneDeviceId!, label: settings.microphoneDeviceLabel ?? '')
        : null;
    await _recorder.start(RecordConfig(encoder: AudioEncoder.wav, device: device), path: path);
    _hasHeardSpeech = false;
    setState(() => _isRecording = true);
    _amplitudeSub =
        _recorder.onAmplitudeChanged(const Duration(milliseconds: 100)).listen(_onAmplitude);
    // Backstop in case the room is never quiet enough to trip the silence
    // detector (background noise, a mic with a noisy floor) — the button
    // still works as a manual toggle regardless, this just guarantees a
    // recording can't run forever.
    _maxRecordingTimer = Timer(_maxRecordingDuration, () {
      if (_isRecording) _toggleRecording();
    });
  }

  // A ring behind the mic icon that grows and brightens with the recorder's
  // amplitude stream, so the button visibly pulses along with the user's
  // own voice instead of just showing a static "recording" state.
  Widget _buildMicButton(ThemeData theme) {
    final level = _isRecording ? _micLevel.clamp(0.0, 1.0) : 0.0;
    return Stack(
      alignment: Alignment.center,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          width: 44 + level * 26,
          height: 44 + level * 26,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: theme.colorScheme.primary.withValues(alpha: _isRecording ? 0.12 + level * 0.35 : 0),
          ),
        ),
        IconButton.filled(
          onPressed: _isSending || _isTranscribing ? null : _toggleRecording,
          isSelected: _isRecording,
          icon: _isTranscribing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(_isRecording ? Icons.stop : Icons.mic),
        ),
      ],
    );
  }

  // Drops the pending-confirmation card at [index] (keeping whatever text
  // the assistant said alongside it), so it can't be tapped twice and
  // actually disappears on cancel instead of just sitting there inert.
  void _clearPendingDeletes(int index) {
    _entries[index] = _ChatEntry.assistant(_entries[index].text);
  }

  Future<void> _confirmDeletes(int index, List<Map<String, dynamic>> pending) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _clearPendingDeletes(index);
      _isSending = true;
    });

    final deletedTitles = <String>[];
    final failedTitles = <String>[];
    for (final p in pending) {
      try {
        final response = await ref.read(apiClientProvider).confirmAssistantDelete(p['eventId'] as String);
        deletedTitles.add(response['title'] as String? ?? p['title'] as String);
      } catch (_) {
        failedTitles.add(p['title'] as String);
      }
    }

    setState(() {
      if (deletedTitles.isNotEmpty) {
        _entries.add(_ChatEntry.assistant(l10n.assistantDeletedConfirmation(deletedTitles.join(', '))));
      }
      if (failedTitles.isNotEmpty) {
        _entries.add(_ChatEntry.error(l10n.assistantErrorGeneric(failedTitles.join(', '))));
      }
    });
    if (deletedTitles.isNotEmpty) ref.invalidate(eventsForVisibleRangeProvider);
    if (mounted) setState(() => _isSending = false);
    _scrollToBottom();
  }

  void _cancelDeletes(int index) {
    setState(() => _clearPendingDeletes(index));
  }

  String _formatWhen(String when) {
    final parsed = DateTime.tryParse(when);
    if (parsed == null) return when;
    if (when.length <= 10) return DateFormat.yMMMd().format(parsed);
    return DateFormat.yMMMd().add_jm().format(parsed.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.assistantTitle)),
      body: Column(
        children: [
          Expanded(
            child: _entries.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        l10n.assistantEmptyState,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: theme.colorScheme.outline),
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: _entries.length,
                    itemBuilder: (context, index) => _buildEntry(index, _entries[index], theme, l10n),
                  ),
          ),
          if (_isSending) const LinearProgressIndicator(minHeight: 2),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      decoration: InputDecoration(
                        hintText: _isRecording
                            ? l10n.assistantRecordingHint
                            : _isTranscribing
                                ? l10n.assistantTranscribingHint
                                : l10n.assistantInputHint,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      enabled: !_isSending && !_isRecording && !_isTranscribing,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildMicButton(theme),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _isSending || _isRecording ? null : _send,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntry(int index, _ChatEntry entry, ThemeData theme, AppLocalizations l10n) {
    final pendingDeletes = entry.pendingDeletes;
    if (pendingDeletes != null && pendingDeletes.isNotEmpty) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Card(
          margin: const EdgeInsets.symmetric(vertical: 6),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (entry.text.isNotEmpty) ...[
                  Text(entry.text),
                  const SizedBox(height: 8),
                ],
                Text(
                  l10n.assistantConfirmDeleteCount(pendingDeletes.length),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                for (final pending in pendingDeletes)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, top: 2),
                    child: Text(
                      '• ${pending['title']} — ${_formatWhen(pending['when'] as String)}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => _cancelDeletes(index), child: Text(l10n.actionCancel)),
                    const SizedBox(width: 8),
                    FilledButton.tonal(
                      onPressed: () => _confirmDeletes(index, pendingDeletes),
                      child: Text(l10n.actionDelete),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    final isUser = entry.role == _Role.user;
    final isError = entry.role == _Role.error;
    final bubbleColor = isUser
        ? theme.colorScheme.primaryContainer
        : isError
            ? theme.colorScheme.errorContainer
            : theme.colorScheme.surfaceContainerHighest;
    final textColor = isUser
        ? theme.colorScheme.onPrimaryContainer
        : isError
            ? theme.colorScheme.onErrorContainer
            : theme.colorScheme.onSurfaceVariant;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: bubbleColor, borderRadius: BorderRadius.circular(12)),
        child: Text(entry.text, style: TextStyle(color: textColor)),
      ),
    );
  }
}
