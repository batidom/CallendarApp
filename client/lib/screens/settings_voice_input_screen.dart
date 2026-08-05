import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../l10n/generated/app_localizations.dart';
import '../providers/providers.dart';
import '../services/app_settings.dart';

/// Which microphone the voice assistant records from — separate from
/// [RemindersSettingsScreen]'s sound settings, which are about output
/// (what plays when a reminder fires), not input.
class VoiceInputSettingsScreen extends ConsumerStatefulWidget {
  const VoiceInputSettingsScreen({super.key});

  @override
  ConsumerState<VoiceInputSettingsScreen> createState() => _VoiceInputSettingsScreenState();
}

class _VoiceInputSettingsScreenState extends ConsumerState<VoiceInputSettingsScreen> {
  final _testRecorder = AudioRecorder();
  StreamSubscription<Amplitude>? _testAmplitudeSub;
  bool _isTestingMic = false;
  double _testLevel = 0;
  String? _testFilePath;

  @override
  void dispose() {
    _testAmplitudeSub?.cancel();
    _testRecorder.dispose();
    // Best-effort — dispose can't be awaited, and this is just a throwaway
    // clip nobody will ever play back.
    _deleteQuietly(_testFilePath);
    super.dispose();
  }

  static Future<void> _deleteQuietly(String? path) async {
    if (path == null) return;
    try {
      await File(path).delete();
    } catch (_) {
      // Nothing depends on this succeeding.
    }
  }

  double _levelFromDb(double db) {
    const floor = -50.0;
    final clamped = db.clamp(floor, 0.0);
    return (clamped - floor) / -floor;
  }

  Future<void> _toggleMicTest(AppSettings settings) async {
    if (_isTestingMic) {
      await _testAmplitudeSub?.cancel();
      _testAmplitudeSub = null;
      final path = await _testRecorder.stop();
      unawaited(_deleteQuietly(path));
      _testFilePath = null;
      if (mounted) {
        setState(() {
          _isTestingMic = false;
          _testLevel = 0;
        });
      }
      return;
    }

    if (!await _testRecorder.hasPermission()) return;
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/mic_test_${DateTime.now().millisecondsSinceEpoch}.wav';
    _testFilePath = path;
    final device = settings.microphoneDeviceId != null
        ? InputDevice(id: settings.microphoneDeviceId!, label: settings.microphoneDeviceLabel ?? '')
        : null;
    await _testRecorder.start(RecordConfig(encoder: AudioEncoder.wav, device: device), path: path);
    if (!mounted) return;
    setState(() => _isTestingMic = true);
    _testAmplitudeSub = _testRecorder.onAmplitudeChanged(const Duration(milliseconds: 100)).listen((amp) {
      if (mounted) setState(() => _testLevel = _levelFromDb(amp.current));
    });
  }

  // Stopping (rather than silently continuing to test the old device) is
  // the least surprising thing to do when the selection changes mid-test —
  // the level meter would otherwise keep reacting to a mic that's no
  // longer the one shown as selected.
  void _stopMicTestIfRunning() {
    if (!_isTestingMic) return;
    _testAmplitudeSub?.cancel();
    _testAmplitudeSub = null;
    final path = _testFilePath;
    _testFilePath = null;
    unawaited(_testRecorder.stop().then((_) => _deleteQuietly(path)));
    setState(() {
      _isTestingMic = false;
      _testLevel = 0;
    });
  }

  Widget _buildMicLevelMeter(ThemeData theme) {
    return LayoutBuilder(
      builder: (context, constraints) => Container(
        height: 8,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          color: theme.colorScheme.surfaceContainerHighest,
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            width: constraints.maxWidth * _testLevel.clamp(0.0, 1.0),
            height: 8,
            color: theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsControllerProvider);
    final controller = ref.read(settingsControllerProvider.notifier);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsCategoryVoiceInput)),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              l10n.microphoneSubtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).hintColor),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: ref.watch(inputDevicesProvider).when(
                  data: (devices) => DropdownButtonFormField<String?>(
                    initialValue: devices.any((d) => d.id == settings.microphoneDeviceId)
                        ? settings.microphoneDeviceId
                        : null,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: l10n.fieldMicrophone,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      DropdownMenuItem(value: null, child: Text(l10n.microphoneSystemDefault)),
                      for (final device in devices)
                        DropdownMenuItem(
                          value: device.id,
                          child: Text(device.label, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (value) {
                      _stopMicTestIfRunning();
                      final label =
                          value == null ? null : devices.firstWhere((d) => d.id == value).label;
                      controller.update((s) => s.copyWith(microphoneDevice: (value, label)));
                    },
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (_, _) => Text(l10n.microphoneListError, style: Theme.of(context).textTheme.bodySmall),
                ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                OutlinedButton.icon(
                  icon: Icon(_isTestingMic ? Icons.stop : Icons.graphic_eq, size: 18),
                  label: Text(_isTestingMic ? l10n.actionStopMicTest : l10n.actionTestMicrophone),
                  onPressed: () => _toggleMicTest(settings),
                ),
                if (_isTestingMic) ...[
                  const SizedBox(width: 12),
                  Expanded(child: _buildMicLevelMeter(Theme.of(context))),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
