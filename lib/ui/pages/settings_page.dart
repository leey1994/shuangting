import 'dart:io';

import 'package:flutter/material.dart' hide Text;
import '../widgets/l10n_text.dart';

import '../../core/library_store.dart';
import '../../core/media_cache.dart';
import '../../core/plugin/plugin_manager.dart';
import '../../core/app_info.dart';
import '../../core/settings.dart';
import '../../core/theme.dart';
import '../dialogs.dart';
import '../update_flow.dart';
import '../widgets/common.dart';
import 'about_page.dart';
import 'backup_page.dart';
import 'plugin_page.dart';
import 'theme_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Settings.instance,
      builder: (context, _) {
        final s = Settings.instance;
        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(title: const Tr('设置')),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 40),
            children: [
              const SectionTitle('播放'),
              ListTile(
                leading: const Icon(Icons.high_quality_outlined),
                title: const Text('默认音质'),
                trailing: Text(_qualityName(s.get<String>('defaultQuality')), style: TextStyle(fontSize: 12, color: AppPalette.muted(context))),
                onTap: () => _selectQuality(context, 'defaultQuality'),
              ),
              ListTile(
                leading: const Icon(Icons.download_outlined),
                title: const Text('下载音质'),
                trailing: Text(_qualityName(s.get<String>('downloadQuality')), style: TextStyle(fontSize: 12, color: AppPalette.muted(context))),
                onTap: () => _selectQuality(context, 'downloadQuality'),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.swap_horiz_rounded),
                title: const Text('播放失败时自动换源'),
                subtitle: Text('在当前插件失败后，尝试其他插件搜索同名歌曲', style: TextStyle(fontSize: 11, color: AppPalette.muted(context))),
                value: s.get<bool>('tryChangeSource'),
                onChanged: (v) => s.set('tryChangeSource', v),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.skip_next_rounded),
                title: const Tr('播放失败自动下一首'),
                value: !s.get<bool>('autoStopWhenError'),
                onChanged: (v) => s.set('autoStopWhenError', !v),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.play_circle_outline_rounded),
                title: const Text('启动时自动播放'),
                value: s.get<bool>('autoPlayOnStart'),
                onChanged: (v) => s.set('autoPlayOnStart', v),
              ),
              ListTile(
                leading: const Icon(Icons.speed_rounded),
                title: const Text('默认播放速度'),
                trailing: Text('${s.get<double>('playSpeed').toStringAsFixed(2)}x', style: TextStyle(fontSize: 12, color: AppPalette.muted(context))),
                onTap: () async {
                  final value = await showModalBottomSheet<double>(
                    context: context,
                    showDragHandle: true,
                    builder: (context) => SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final v in [0.75, 1.0, 1.25, 1.5, 2.0])
                            ListTile(
                              title: Text('${v}x'),
                              trailing: (s.get<double>('playSpeed') - v).abs() < 0.01 ? const Icon(Icons.check_rounded) : null,
                              onTap: () => Navigator.pop(context, v),
                            ),
                        ],
                      ),
                    ),
                  );
                  if (value != null) await s.set('playSpeed', value);
                },
              ),
              ListTile(
                leading: const Icon(Icons.download_for_offline_outlined),
                title: const Text('同时下载数量'),
                trailing: Text('${s.get<int>('maxDownload')}', style: TextStyle(fontSize: 12, color: AppPalette.muted(context))),
                onTap: () async {
                  final value = await showModalBottomSheet<int>(
                    context: context,
                    showDragHandle: true,
                    builder: (context) => SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final v in [1, 2, 3, 4, 5])
                            ListTile(
                              title: Text('$v'),
                              trailing: s.get<int>('maxDownload') == v ? const Icon(Icons.check_rounded) : null,
                              onTap: () => Navigator.pop(context, v),
                            ),
                        ],
                      ),
                    ),
                  );
                  if (value != null) await s.set('maxDownload', value);
                },
              ),
              const SectionTitle('歌词'),
              SwitchListTile(
                secondary: const Icon(Icons.lyrics_outlined),
                title: const Text('播放页默认显示歌词'),
                value: s.get<String>('musicDetailDefault') == 'lyric',
                onChanged: (v) => s.set('musicDetailDefault', v ? 'lyric' : 'album'),
              ),
              ListTile(
                leading: const Icon(Icons.format_size_rounded),
                title: const Text('歌词字号'),
                subtitle: Slider(
                  value: s.get<double>('lyricFontSize').clamp(14, 26),
                  min: 14,
                  max: 26,
                  divisions: 12,
                  label: s.get<double>('lyricFontSize').round().toString(),
                  onChanged: (v) => s.set('lyricFontSize', v),
                ),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.settings_bluetooth_rounded),
                title: Text(t('蓝牙歌词')),
                subtitle: Text(
                  t('将当前歌词行写入蓝牙媒体信息'),
                  style: TextStyle(fontSize: 11, color: AppPalette.muted(context)),
                ),
                value: s.get<bool>('bluetoothLyric'),
                onChanged: (v) => s.set('bluetoothLyric', v),
              ),
              const SectionTitle('个性化'),
              ListTile(
                leading: const Icon(Icons.palette_outlined),
                title: const Text('主题与背景'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ThemePage())),
              ),
              ListTile(
                leading: const Icon(Icons.translate_rounded),
                title: const Tr('语言 / Language'),
                trailing: Text(s.isEnglish ? 'English' : '简体中文', style: TextStyle(fontSize: 12, color: AppPalette.muted(context))),
                onTap: () async {
                  final value = await showModalBottomSheet<String>(
                    context: context,
                    showDragHandle: true,
                    builder: (context) => SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(title: const Text('简体中文'), trailing: !s.isEnglish ? const Icon(Icons.check_rounded) : null, onTap: () => Navigator.pop(context, 'zh')),
                          ListTile(title: const Text('English'), trailing: s.isEnglish ? const Icon(Icons.check_rounded) : null, onTap: () => Navigator.pop(context, 'en')),
                        ],
                      ),
                    ),
                  );
                  if (value != null) {
                    await s.set('language', value);
                    ThemeController.instance.refresh();
                  }
                },
              ),
              const SectionTitle('插件'),
              ListTile(
                leading: const Icon(Icons.extension_rounded),
                title: const Text('插件管理'),
                trailing: Text('${PluginManager.instance.records.length} 个', style: TextStyle(fontSize: 12, color: AppPalette.muted(context))),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PluginPage())),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.update_rounded),
                title: const Text('启动时自动检查插件更新'),
                value: s.get<bool>('autoUpdatePlugin'),
                onChanged: (v) => s.set('autoUpdatePlugin', v),
              ),
              const SectionTitle('数据'),
              ListTile(
                leading: const Icon(Icons.backup_outlined),
                title: const Text('备份与恢复'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BackupPage())),
              ),
              ListTile(
                leading: const Icon(Icons.cleaning_services_outlined),
                title: const Text('清除搜索与音源缓存'),
                onTap: () async {
                  PluginManager.instance.clearCaches();
                  showToast(context, '缓存已清除');
                },
              ),
              ListTile(
                leading: const Icon(Icons.restart_alt_rounded),
                title: const Text('清除歌词缓存'),
                onTap: () async {
                  await MediaCache.instance.clear();
                  showToast(context, '歌词缓存已清除');
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                title: const Text('清空所有歌单与历史', style: TextStyle(color: Colors.redAccent)),
                onTap: () async {
                  if (await confirmDialog(context, '清空所有歌单与历史？', content: '「我喜欢」中的歌曲也会被清空，此操作不可恢复。')) {
                    await LibraryStore.instance.clearAllUserData();
                    if (context.mounted) showToast(context, '已清空');
                  }
                },
              ),
              const SectionTitle('关于'),
              ListTile(
                leading: const Icon(Icons.info_outline_rounded),
                title: const Text('爽听'),
                subtitle: Text('v${AppInfo.fullVersion} · 插件化音乐播放器，界面完全重绘', style: TextStyle(fontSize: 11, color: AppPalette.muted(context))),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AboutPage())),
              ),
              ListTile(
                leading: const Icon(Icons.system_update_rounded),
                title: const Text('检查更新'),
                subtitle: const Text('从 GitHub Releases 获取最新版本', style: TextStyle(fontSize: 11)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => checkForUpdates(context),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.update_rounded),
                title: const Text('启动时检查更新'),
                value: s.get<bool>('autoCheckUpdate'),
                onChanged: (v) => s.set('autoCheckUpdate', v),
              ),
              if (Platform.isWindows) ...[
                SwitchListTile(
                  secondary: const Icon(Icons.window_rounded),
                  title: const Text('关闭窗口时最小化到托盘'),
                  subtitle: Text(
                    '图标在任务栏右下角「隐藏图标」里，可拖出固定',
                    style: TextStyle(fontSize: 11),
                  ),
                  value: s.get<bool>('closeToTray'),
                  onChanged: (v) => s.set('closeToTray', v),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  String _qualityName(String key) {
    switch (key) {
      case 'low':
        return '低';
      case 'standard':
        return '标准';
      case 'high':
        return '高';
      case 'super':
        return '超高';
      default:
        return key;
    }
  }

  Future<void> _selectQuality(BuildContext context, String key) async {
    final s = Settings.instance;
    final value = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(key == 'defaultQuality' ? '默认音质' : '下载音质', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
            for (final q in ['low', 'standard', 'high', 'super'])
              ListTile(
                title: Text(_qualityName(q)),
                trailing: s.get<String>(key) == q ? const Icon(Icons.check_rounded) : null,
                onTap: () => Navigator.pop(context, q),
              ),
          ],
        ),
      ),
    );
    if (value != null) await s.set(key, value);
  }
}
