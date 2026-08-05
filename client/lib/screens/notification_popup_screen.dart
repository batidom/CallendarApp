import 'dart:async';

import 'package:flutter/material.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

import '../services/app_settings.dart';

const _popupSize = Size(340, 100);
const _screenMargin = 24.0;

/// The content and self-positioning logic for a reminder's popup window. Runs
/// in its own Flutter engine (see main.dart) — entirely separate from the
/// main calendar window, so it can appear even while that window is hidden.
/// [corner] and [autoCloseAfter] come from the user's settings.
class NotificationPopupScreen extends StatefulWidget {
  const NotificationPopupScreen({
    super.key,
    required this.title,
    required this.message,
    required this.corner,
    required this.autoCloseAfter,
  });

  final String title;
  final String message;
  final NotificationCorner corner;
  final Duration autoCloseAfter;

  @override
  State<NotificationPopupScreen> createState() => _NotificationPopupScreenState();
}

class _NotificationPopupScreenState extends State<NotificationPopupScreen> {
  Timer? _autoCloseTimer;

  @override
  void initState() {
    super.initState();
    _autoCloseTimer = Timer(widget.autoCloseAfter, _dismiss);
    unawaited(_setUpWindow());
  }

  Future<void> _setUpWindow() async {
    final display = await screenRetriever.getPrimaryDisplay();
    final screenSize = display.size;

    final corner = widget.corner;
    final left = corner == NotificationCorner.topLeft || corner == NotificationCorner.bottomLeft
        ? _screenMargin
        : screenSize.width - _popupSize.width - _screenMargin;
    final top = corner == NotificationCorner.topLeft || corner == NotificationCorner.topRight
        ? _screenMargin
        : screenSize.height - _popupSize.height - _screenMargin - 48;

    const options = WindowOptions(
      size: _popupSize,
      backgroundColor: Colors.transparent,
      skipTaskbar: true,
      alwaysOnTop: true,
      titleBarStyle: TitleBarStyle.hidden,
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.setAsFrameless();
      // A native window shadow renders as a translucent halo around the
      // rounded rect on a transparent-background frameless window, so it's
      // disabled — the card should be the only thing visible.
      await windowManager.setHasShadow(false);
      await windowManager.setPosition(Offset(left, top));
      await windowManager.show();
    });
  }

  void _dismiss() {
    _autoCloseTimer?.cancel();
    windowManager.close();
  }

  @override
  void dispose() {
    _autoCloseTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: Scaffold(
        backgroundColor: Colors.transparent,
        // A plain, un-elevated Container filling the whole window: no
        // Material shadow and no padding around it, so nothing but the
        // rounded rectangle itself is visible against the transparent
        // window background.
        body: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: _dismiss,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.notifications_active, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.message,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    splashRadius: 14,
                    onPressed: _dismiss,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
