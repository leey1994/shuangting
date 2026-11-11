import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:tray_manager/tray_manager.dart' as tm;
import 'package:window_manager/legacy.dart';

import '../player/player_service.dart';
import '../settings.dart';
import 'tray_icon_data.dart';

/// Windows 托盘：tray_manager 的原生 API。
///
/// 两个与 legacy 版不同的要点：
/// 1. 必须显式 `setVisible(true)`，否则图标保持隐藏；
/// 2. 必须显式 `setContextMenuTrigger(rightClicked)`，原生 API 默认不弹菜单。
class DesktopTray with WindowListener {
  DesktopTray._();
  static final DesktopTray instance = DesktopTray._();

  tm.TrayIcon? _tray;
  tm.Menu? _menu;
  final List<TrayMenuItem> _items = [];
  bool _hintShown = false;

  bool get ready => _tray != null;

  Future<void> init() async {
    if (!Platform.isWindows || _tray != null) return;
    try {
      final tray = tm.TrayIcon.create();
      if (tray == null) {
        debugPrint('[tray] TrayIcon.create 失败');
        return;
      }
      // 用内嵌 base64 图标，避免依赖打包资源路径。
      tray.icon = tm.Image.fromBase64(kTrayIconBase64);
      tray.setTooltip('爽听');
      _rebuildMenu(tray);
      tray.setContextMenuTrigger(tm.ContextMenuTrigger.rightClicked);
      tray.setVisible(true);
      _tray = tray;

      windowManager.addListener(this);
      await windowManager.setPreventClose(true);
      unawaited(_watchPlayState());

      // 首次注册偶发失败（Explorer 刚重启等），稍后重试一次。
      debugPrint('[tray] bounds=${tray.getBounds()}');
      if (!tray.isVisible()) {
        await Future<void>.delayed(const Duration(seconds: 2));
        tray.setVisible(true);
        debugPrint('[tray] retry visible=${tray.isVisible()}');
      }
    } catch (e) {
      debugPrint('[tray] init failed: $e');
    }
  }

  void _rebuildMenu(tm.TrayIcon tray) {
    for (final item in _items) {
      item.menuItem.removeListener(item.listenerId);
    }
    _items.clear();
    _menu?.dispose();
    _menu = null;

    final menu = tm.Menu.create();
    if (menu == null) return;
    _items.add(_addItem(menu, 'show', '显示主窗口'));
    _items.add(
        _addItem(menu, 'toggle', PlayerService.instance.playing ? '暂停' : '播放'));
    _items.add(_addItem(menu, 'next', '下一首'));
    menu.addSeparator();
    _items.add(_addItem(menu, 'exit', '退出'));
    tray.setContextMenu(menu);
    _menu = menu;
  }

  TrayMenuItem _addItem(tm.Menu menu, String key, String labelZh) {
    final item = tm.MenuItem.createWithLabelAndType(
        L10n.instance.t(labelZh), tm.MenuItemType.normal)!;
    late final tm.ListenerId listenerId;
    listenerId = item.addListener((event) async {
      if (event is! tm.MenuItemClickedEvent) return;
      await _handle(key);
    });
    menu.addItem(item);
    return TrayMenuItem(item, listenerId);
  }

  Future<void> _handle(String key) async {
    switch (key) {
      case 'show':
        await _showWindow();
      case 'toggle':
        await PlayerService.instance.toggle();
      case 'next':
        await PlayerService.instance.next();
      case 'exit':
        await _exit();
    }
  }

  /// 播放状态变化时刷新菜单文案，避免「播放/暂停」一直是旧值。
  Future<void> _watchPlayState() async {
    var playing = PlayerService.instance.playing;
    while (_tray != null) {
      await Future<void>.delayed(const Duration(seconds: 1));
      final tray = _tray;
      if (tray == null) break;
      if (PlayerService.instance.playing != playing) {
        playing = PlayerService.instance.playing;
        try {
          _rebuildMenu(tray);
        } catch (_) {}
      }
    }
  }

  Future<void> _showWindow() async {
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> _exit() async {
    final tray = _tray;
    _tray = null;
    try {
      tray?.setVisible(false);
      tray?.dispose();
    } catch (_) {}
    await windowManager.setPreventClose(false);
    await windowManager.destroy();
    exit(0);
  }

  @override
  void onWindowClose() async {
    if (Settings.instance.get<bool>('closeToTray') && ready) {
      await windowManager.hide();
      if (!_hintShown) {
        _hintShown = true;
        debugPrint('[tray] 已最小化到托盘（任务栏右下角「隐藏图标」里）');
      }
    } else {
      await _exit();
    }
  }
}

class TrayMenuItem {
  const TrayMenuItem(this.menuItem, this.listenerId);
  final tm.MenuItem menuItem;
  final tm.ListenerId listenerId;
}
