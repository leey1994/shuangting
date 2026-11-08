import 'package:flutter/material.dart' hide Text;
import '../widgets/l10n_text.dart';

import '../../core/app_info.dart';
import '../../core/download_service.dart';
import '../../core/library_store.dart';
import '../../core/local_library.dart';
import '../../core/plugin/plugin_manager.dart';
import '../../core/settings.dart';
import '../../core/theme.dart';
import 'about_page.dart';
import 'backup_page.dart';
import 'downloads_page.dart';
import 'history_page.dart';
import 'library_page.dart';
import 'local_page.dart';
import 'media_detail_page.dart';
import 'plugin_page.dart';
import 'settings_page.dart';
import 'theme_page.dart';

class MePage extends StatelessWidget {
  const MePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        LibraryStore.instance,
        DownloadService.instance,
        LocalLibrary.instance,
        PluginManager.instance,
        Settings.instance,
      ]),
      builder: (context, _) {
        final lib = LibraryStore.instance;
        final fav = lib.favorites;
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: ListView(
            padding: const EdgeInsets.only(bottom: 130),
            children: [
              _Header(favCount: fav.songs.length),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: Icons.playlist_play_rounded,
                        label: '我喜欢',
                        value: '${fav.songs.length}',
                        color: const Color(0xFFFF5C8A),
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => MusicListDetailPage(
                            title: fav.name,
                            artwork: fav.cover,
                            subtitle: '${fav.songs.length} 首',
                            playlist: fav,
                            kind: MediaListKind.localPlaylist,
                          ),
                        )),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.history_rounded,
                        label: '最近播放',
                        value: '${lib.history.length}',
                        color: const Color(0xFF4D8DFF),
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HistoryPage())),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.download_rounded,
                        label: '下载',
                        value: '${DownloadService.instance.tasks.length}',
                        color: const Color(0xFFF5A524),
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DownloadsPage())),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              _MenuGroup(
                items: [
                  _MenuItem(Icons.folder_special_rounded, '本地音乐', '${LocalLibrary.instance.songs.length} 首', const Color(0xFF37C08A), () => _push(context, const LocalMusicPage())),
                  _MenuItem(Icons.library_music_rounded, '我的歌单', '${lib.userPlaylists.length} 个', const Color(0xFF8B5CF6), () => _push(context, const LibraryPage())),
                  _MenuItem(Icons.extension_rounded, '插件管理', '${PluginManager.instance.records.length} 个已安装', const Color(0xFF4D8DFF), () => _push(context, const PluginPage())),
                ],
              ),
              const SizedBox(height: 12),
              _MenuGroup(
                items: [
                  _MenuItem(Icons.palette_outlined, '主题与背景', AppPalette.presetNames[_presetIndex()], const Color(0xFFFF6B5B), () => _push(context, const ThemePage())),
                  _MenuItem(Icons.backup_outlined, '备份与恢复', 'WebDAV / 本地', const Color(0xFF37C08A), () => _push(context, const BackupPage())),
                  _MenuItem(Icons.settings_outlined, '设置', L10n.instance.en ? 'English' : '简体中文', const Color(0xFF6E7686), () => _push(context, const SettingsPage())),
                  _MenuItem(Icons.info_outline_rounded, '关于', 'v${AppInfo.version} · ${AppInfo.author}', const Color(0xFF9AA3B2), () => _push(context, const AboutPage())),
                ],
              ),
              const SizedBox(height: 26),
              Center(
                child: Column(
                  children: [
                    ShaderMask(
                      shaderCallback: (rect) => AppPalette.brandGradient(context).createShader(rect),
                      child: const Text(
                        '爽听',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 4),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('v${AppInfo.fullVersion} · ${AppInfo.slogan}', style: TextStyle(fontSize: 11, color: AppPalette.muted(context))),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  int _presetIndex() {
    final seed = Settings.instance.get<int>('themeSeed');
    final i = AppPalette.presets.indexOf(seed);
    return i < 0 ? 0 : i;
  }

  void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.favCount});
  final int favCount;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Stack(
      children: [
        Container(
          height: 230 + top,
          decoration: BoxDecoration(gradient: AppPalette.brandGradient(context)),
        ),
        Positioned(
          right: -50,
          top: -30,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.10)),
          ),
        ),
        Positioned(
          right: 40,
          bottom: 10,
          child: Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.08)),
          ),
        ),
        Positioned(
          left: 24,
          right: 24,
          bottom: 26,
          child: Row(
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.22),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2),
                ),
                child: const Icon(Icons.headphones_rounded, color: Colors.white, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('爽听用户', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(
                      '已收藏 $favCount 首 · 戴上耳机，世界安静',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.icon, required this.label, required this.value, required this.color, required this.onTap});
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: AppPalette.card(context),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 11, color: AppPalette.muted(context))),
          ],
        ),
      ),
    );
  }
}

class _MenuItem {
  _MenuItem(this.icon, this.title, this.subtitle, this.color, this.onTap);
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
}

class _MenuGroup extends StatelessWidget {
  const _MenuGroup({required this.items});
  final List<_MenuItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppPalette.card(context),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) Divider(height: 1, indent: 60, color: Theme.of(context).colorScheme.outlineVariant),
            ListTile(
              onTap: items[i].onTap,
              leading: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: items[i].color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(items[i].icon, color: items[i].color, size: 20),
              ),
              title: Text(items[i].title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
              subtitle: Text(items[i].subtitle, style: TextStyle(fontSize: 11, color: AppPalette.muted(context))),
              trailing: Icon(Icons.chevron_right_rounded, color: AppPalette.muted(context), size: 20),
            ),
          ],
        ],
      ),
    );
  }
}
