import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:tray_manager/legacy.dart';
import 'package:window_manager/legacy.dart';

import '../player/player_service.dart';
import '../settings.dart';

class DesktopTray with TrayListener, WindowListener {
  DesktopTray._();
  static final DesktopTray instance = DesktopTray._();

  Future<void> init() async {
    if (!Platform.isWindows) return;
    try {
      await trayManager.setIcon('assets/icon/shuangting-icon.png');
      await trayManager.setToolTip('爽听');
      await trayManager.setContextMenu(Menu(items: _buildItems()));
      trayManager.addListener(this);
      windowManager.addListener(this);
      await windowManager.setPreventClose(true);
    } catch (e) {
      debugPrint('[tray] init failed: $e');
    }
  }

  List<MenuItem> _buildItems() {
    String tr(String text) => L10n.instance.t(text);
    return [
      MenuItem(key: 'show', label: tr('显示主窗口')),
      MenuItem(key: 'toggle', label: tr(PlayerService.instance.playing ? '暂停' : '播放')),
      MenuItem(key: 'next', label: tr('下一首')),
      MenuItem.separator(),
      MenuItem(key: 'exit', label: tr('退出')),
    ];
  }

  Future<void> _showWindow() async {
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> _exit() async {
    trayManager.removeListener(this);
    windowManager.removeListener(this);
    await windowManager.setPreventClose(false);
    await windowManager.destroy();
    exit(0);
  }

  @override
  void onWindowClose() {
    windowManager.hide();
  }

  @override
  void onTrayIconMouseDown() {
    _showWindow();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show':
        _showWindow();
        break;
      case 'toggle':
        PlayerService.instance.toggle();
        break;
      case 'next':
        PlayerService.instance.next();
        break;
      case 'exit':
        _exit();
        break;
    }
  }
}