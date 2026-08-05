import 'dart:io';
import 'dart:ui';

import 'package:path/path.dart' as p;
import 'package:screen_retriever/screen_retriever.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

const flyoutSize = Size(400, 780);

/// Hides the main window in the taskbar and instead shows a small
/// frameless "flyout" window near the system tray, matching the Windows
/// Clock/Calendar popup style described in the guidelines' Phase 3.
class AppWindowController with TrayListener, WindowListener {
  AppWindowController._();

  static final AppWindowController instance = AppWindowController._();

  Future<void> init() async {
    await windowManager.ensureInitialized();
    windowManager.addListener(this);
    trayManager.addListener(this);

    const options = WindowOptions(
      size: flyoutSize,
      skipTaskbar: true,
      titleBarStyle: TitleBarStyle.hidden,
      alwaysOnTop: true,
    );

    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.setPreventClose(true);
      await windowManager.setHasShadow(true);
      await windowManager.hide();
    });

    await _setTrayIcon();
    await trayManager.setContextMenu(
      Menu(items: [
        MenuItem(key: 'show', label: 'Show Calendar'),
        MenuItem.separator(),
        MenuItem(key: 'quit', label: 'Quit'),
      ]),
    );
  }

  Future<void> _setTrayIcon() async {
    final exeDir = p.dirname(Platform.resolvedExecutable);
    final iconPath = p.join(exeDir, 'data', 'flutter_assets', 'assets', 'tray_icon.ico');
    await trayManager.setIcon(iconPath);
    await trayManager.setToolTip('Calendar App');
  }

  Future<void> toggleVisibility() async {
    final visible = await windowManager.isVisible();
    if (visible) {
      await windowManager.hide();
    } else {
      await _showNearTray();
    }
  }

  Future<void> _showNearTray() async {
    final display = await screenRetriever.getPrimaryDisplay();
    final screenSize = display.size;
    const margin = 12.0;
    final position = Offset(
      screenSize.width - flyoutSize.width - margin,
      screenSize.height - flyoutSize.height - margin - 48,
    );
    await windowManager.setPosition(position);
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> quit() async {
    await windowManager.setPreventClose(false);
    await windowManager.destroy();
  }

  @override
  void onTrayIconMouseDown() {
    toggleVisibility();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show':
        _showNearTray();
      case 'quit':
        quit();
    }
  }

  @override
  void onWindowClose() async {
    final preventClose = await windowManager.isPreventClose();
    if (preventClose) {
      await windowManager.hide();
    }
  }

  @override
  void onWindowBlur() {
    // Dismiss on outside click, like the Windows Clock/Calendar flyout.
    windowManager.hide();
  }

  void dispose() {
    windowManager.removeListener(this);
    trayManager.removeListener(this);
  }
}
