import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/audio_cache.dart';
import '../../data/store.dart';
import '../../player/player_controller.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  Future<int>? _cacheSize;
  String _version = '';

  @override
  void initState() {
    super.initState();
    _refreshCache();
    PackageInfo.fromPlatform().then((v) {
      if (mounted) setState(() => _version = v.version);
    });
  }

  void _refreshCache() {
    setState(() => _cacheSize = context.read<AudioCache>().totalSize());
  }

  /// 关闭蓝牙歌词时，把 MediaItem 恢复成不含歌词行的原始元数据。
  Future<void> _restoreMediaItem() async {
    final p = context.read<PlayerController>();
    if (p.current == null) return;
    await p.restoreBtLyricMediaItem();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsModel>();
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
        children: [
          _Section(
            title: '播放',
            icon: Icons.play_circle_outline_rounded,
            children: [
              _SettingRow(
                title: '音质偏好',
                subtitle: '高音质会消耗更多流量与缓存空间',
                child: Wrap(
                  spacing: 6,
                  children: [
                    for (final q in const [
                      ('128', '标准'),
                      ('320', '高质'),
                      ('flac', '无损'),
                      ('hires', 'Hi-Res'),
                    ])
                      ChoiceChip(
                        label: Text(q.$2),
                        selected: settings.quality == q.$1,
                        showCheckmark: false,
                        selectedColor: scheme.primary,
                        labelStyle: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: settings.quality == q.$1
                              ? scheme.onPrimary
                              : scheme.onSurface.withValues(alpha: 0.6),
                        ),
                        onSelected: (_) => settings.quality = q.$1,
                      ),
                  ],
                ),
              ),
              _SwitchRow(
                title: '自动缓存',
                subtitle: '听过的歌曲自动保存，断网也能继续听',
                value: settings.autoCache,
                onChanged: (v) => settings.autoCache = v,
              ),
              _SwitchRow(
                title: '蓝牙歌词',
                subtitle: '把当前歌词行推送到蓝牙车机/音箱屏幕（AVRCP）',
                value: settings.btLyric,
                onChanged: (v) {
                  settings.btLyric = v;
                  context.read<PlayerController>().btLyric = v;
                  if (!v) unawaited(_restoreMediaItem());
                },
              ),
              _SettingRow(
                title: '缓存上限',
                subtitle: '超出后自动清理最久未播放的缓存',
                child: Wrap(
                  spacing: 6,
                  children: [
                    for (final mb in [512, 1024, 2048, 4096])
                      ChoiceChip(
                        label: Text(mb >= 1024 ? '${mb ~/ 1024} GB' : '$mb MB'),
                        selected: settings.cacheLimitMb == mb,
                        showCheckmark: false,
                        selectedColor: scheme.primary,
                        labelStyle: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: settings.cacheLimitMb == mb
                              ? scheme.onPrimary
                              : scheme.onSurface.withValues(alpha: 0.6),
                        ),
                        onSelected: (_) => settings.cacheLimitMb = mb,
                      ),
                  ],
                ),
              ),
              _SwitchRow(
                title: '拖动进度条时暂停',
                subtitle: '松手后从新位置继续播放',
                value: settings.dragPause,
                onChanged: (v) => settings.dragPause = v,
              ),
              _SettingRow(
                title: '播放页样式',
                subtitle: '唱片、歌词、极简三种沉浸布局',
                child: Wrap(
                  spacing: 6,
                  children: [
                    for (final s in const [('vinyl', '唱片'), ('lyrics', '歌词'), ('minimal', '极简')])
                      ChoiceChip(
                        label: Text(s.$2),
                        selected: settings.playerStyle == s.$1,
                        showCheckmark: false,
                        selectedColor: scheme.primary,
                        labelStyle: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: settings.playerStyle == s.$1
                              ? scheme.onPrimary
                              : scheme.onSurface.withValues(alpha: 0.6),
                        ),
                        onSelected: (_) => settings.playerStyle = s.$1,
                      ),
                  ],
                ),
              ),
              _SettingRow(
                title: '歌词字号',
                subtitle: '${(settings.lyricScale * 100).round()}%',
                child: Slider(
                  value: settings.lyricScale,
                  min: 0.8,
                  max: 1.5,
                  divisions: 7,
                  onChanged: (v) => settings.lyricScale = v,
                ),
              ),
              _SwitchRow(
                title: '歌词辉光',
                subtitle: '逐字歌词的柔和光晕效果',
                value: settings.glow,
                onChanged: (v) => settings.glow = v,
              ),
              _SwitchRow(
                title: '动态流光背景',
                subtitle: '跟随封面与主题色变化',
                value: settings.flowBg,
                onChanged: (v) => settings.flowBg = v,
              ),
            ],
          ),
          _Section(
            title: '外观',
            icon: Icons.palette_outlined,
            children: [
              _SettingRow(
                title: '主题模式',
                subtitle: '深色更适合夜间听歌',
                child: Wrap(
                  spacing: 6,
                  children: [
                    for (final m in const [
                      ('dark', '深色'),
                      ('light', '浅色'),
                      ('system', '跟随系统'),
                      ('black', '纯黑'),
                    ])
                      ChoiceChip(
                        label: Text(m.$2),
                        selected: settings.themeMode == m.$1,
                        showCheckmark: false,
                        selectedColor: scheme.primary,
                        labelStyle: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: settings.themeMode == m.$1
                              ? scheme.onPrimary
                              : scheme.onSurface.withValues(alpha: 0.6),
                        ),
                        onSelected: (_) => settings.themeMode = m.$1,
                      ),
                  ],
                ),
              ),
              _SettingRow(
                title: '主题色',
                subtitle: '选一个属于你的声音颜色',
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final entry in accentChoices.entries)
                      GestureDetector(
                        onTap: () => settings.accent = entry.key,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: entry.value,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: settings.accent == entry.key
                                  ? scheme.onSurface
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: settings.accent == entry.key
                              ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                              : null,
                        ),
                      ),
                  ],
                ),
              ),
              _SettingRow(
                title: '设备模式',
                subtitle: '自动根据窗口尺寸切换，横屏车机也能用',
                child: Wrap(
                  spacing: 6,
                  children: [
                    for (final m in const [
                      ('auto', '自动'),
                      ('phone', '手机'),
                      ('tablet', '平板'),
                      ('car', '车机'),
                    ])
                      ChoiceChip(
                        label: Text(m.$2),
                        selected: settings.deviceMode == m.$1,
                        showCheckmark: false,
                        selectedColor: scheme.primary,
                        labelStyle: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: settings.deviceMode == m.$1
                              ? scheme.onPrimary
                              : scheme.onSurface.withValues(alpha: 0.6),
                        ),
                        onSelected: (_) => settings.deviceMode = m.$1,
                      ),
                  ],
                ),
              ),
              if (Platform.isWindows)
                _SwitchRow(
                  title: '桌面歌词模式',
                  subtitle: '缩小窗口并置顶显示当前歌词',
                  value: settings.desktopLyric,
                  onChanged: (v) async {
                    settings.desktopLyric = v;
                    if (v) {
                      await windowManager.setAlwaysOnTop(true);
                      await windowManager.setSize(const Size(960, 230));
                    } else {
                      await windowManager.setAlwaysOnTop(false);
                      await windowManager.setSize(const Size(1280, 840));
                    }
                    await windowManager.center();
                  },
                ),
            ],
          ),
          _Section(
            title: '通用',
            icon: Icons.settings_suggest_outlined,
            children: [
              _SwitchRow(
                title: '启动后自动签到',
                subtitle: '打开爽听即完成 VIP 每日签到',
                value: settings.autoSignIn,
                onChanged: (v) => settings.autoSignIn = v,
              ),
              _SwitchRow(
                title: '自动检查更新',
                subtitle: '从 GitHub Releases 获取最新版本',
                value: settings.autoUpdate,
                onChanged: (v) => settings.autoUpdate = v,
              ),
              _SettingRow(
                title: '播放缓存',
                subtitle: '已缓存的歌曲可离线播放',
                child: FutureBuilder<int>(
                  future: _cacheSize,
                  builder: (context, snap) {
                    final size = snap.data;
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(size == null ? '计算中…' : formatBytes(size),
                            style: TextStyle(
                                fontSize: 12, color: scheme.onSurface.withValues(alpha: 0.5))),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () => _clearCache(context),
                          child: const Text('清理'),
                        ),
                      ],
                    );
                  },
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('播放历史与收藏', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                subtitle: const Text('在音乐库中管理', style: TextStyle(fontSize: 11.5)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.pushNamed(context, '/favorites'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('音效与播放速度', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                subtitle: const Text('均衡器、倍速、音质', style: TextStyle(fontSize: 11.5)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.pushNamed(context, '/sound'),
              ),
            ],
          ),
          _Section(
            title: '关于',
            icon: Icons.info_outline_rounded,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [scheme.primary, AppTheme.mint]),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  alignment: Alignment.center,
                  child: const Text('爽',
                      style: TextStyle(
                          fontWeight: FontWeight.w900, color: Color(0xFF0A0C12), fontSize: 20)),
                ),
                title: const Text('关于爽听', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('版本 v${_version.isEmpty ? '0.0.1' : _version}'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.pushNamed(context, '/about'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('重置所有设置', style: TextStyle(fontSize: 14, color: Colors.redAccent)),
                onTap: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('重置所有设置？'),
                      content: const Text('收藏、历史与下载不会被删除，仅恢复默认偏好。'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
                        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('重置')),
                      ],
                    ),
                  );
                  if (ok == true) {
                    await settings.resetAll();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(const SnackBar(content: Text('设置已重置')));
                    }
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          Center(
            child: Text('爽听 · 用全新的方式听音乐',
                style: TextStyle(fontSize: 11, color: scheme.onSurface.withValues(alpha: 0.3))),
          ),
        ],
      ),
    );
  }

  Future<void> _clearCache(BuildContext context) async {
    final cache = context.read<AudioCache>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清理播放缓存？'),
        content: const Text('已下载到音乐库的歌曲不会被删除。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('清理')),
        ],
      ),
    );
    if (ok == true) {
      await cache.clear();
      _refreshCache();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('缓存已清理')));
      }
    }
  }
}

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  const _Section({required this.title, required this.icon, required this.children});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Row(
              children: [
                Icon(icon, size: 16, color: scheme.primary),
                const SizedBox(width: 7),
                Text(title,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                        color: scheme.onSurface.withValues(alpha: 0.55))),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: scheme.surface.withValues(alpha: 0.66),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: scheme.outline.withValues(alpha: 0.2)),
            ),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  const _SettingRow({required this.title, required this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(subtitle,
              style: TextStyle(fontSize: 11.5, color: scheme.onSurface.withValues(alpha: 0.42))),
          const SizedBox(height: 10),
          Align(alignment: Alignment.centerLeft, child: child),
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 11.5, color: scheme.onSurface.withValues(alpha: 0.42))),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
