import 'dart:io';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme.dart';
import '../../data/update_service.dart';
import '../widgets/common.dart';
import '../widgets/update_dialog.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  String _version = '0.0.1';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((v) {
      if (mounted) setState(() => _version = v.version);
    });
  }

  Future<void> _open(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('无法打开链接：$url')));
    }
  }

  Future<void> _checkUpdate() async {
    final service = context.read<UpdateService>();
    final info = await service.check();
    if (!mounted) return;
    if (info == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(service.message ?? '已是最新版本')));
      return;
    }
    showDialog(context: context, builder: (_) => UpdateDialog(service: service, info: info));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = AppTheme.coverGradient(0, isDark: isDark);
    return Scaffold(
      appBar: AppBar(title: const Text('关于')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
        children: [
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [colors.first, colors.last],
                ),
                boxShadow: [
                  BoxShadow(
                      color: colors.first.withValues(alpha: 0.35),
                      blurRadius: 30,
                      offset: const Offset(0, 14)),
                ],
              ),
              alignment: Alignment.center,
              child: const Text('爽听',
                  style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 2)),
            ),
          ),
          const SizedBox(height: 18),
          Center(
            child: Text('爽听',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w900, letterSpacing: 4)),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text('版本 v$_version',
                style: TextStyle(fontSize: 12, color: scheme.onSurface.withValues(alpha: 0.45))),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text('一款重新设计的音乐播放器',
                style: TextStyle(fontSize: 12.5, color: scheme.onSurface.withValues(alpha: 0.55))),
          ),
          const SizedBox(height: 26),
          _LinkCard(
            icon: Icons.code_rounded,
            title: 'GitHub 开源仓库',
            subtitle: UpdateService.repoUrl,
            color: const Color(0xFF8B6CFF),
            onTap: () => _open(UpdateService.repoUrl),
          ),
          const SizedBox(height: 10),
          _LinkCard(
            icon: Icons.public_rounded,
            title: 'GitHub Pages 主页',
            subtitle: UpdateService.pagesUrl,
            color: AppTheme.mint,
            onTap: () => _open(UpdateService.pagesUrl),
          ),
          const SizedBox(height: 10),
          _LinkCard(
            icon: Icons.system_update_rounded,
            title: '检查更新',
            subtitle: '自动从 GitHub Releases 下载构建物',
            color: scheme.primary,
            onTap: _checkUpdate,
          ),
          const SizedBox(height: 10),
          _LinkCard(
            icon: Icons.download_rounded,
            title: '历史版本下载',
            subtitle: UpdateService.releasesUrl,
            color: const Color(0xFFFFA62B),
            onTap: () => _open(UpdateService.releasesUrl),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: scheme.surface.withValues(alpha: 0.66),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: scheme.outline.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.new_releases_rounded, size: 18, color: scheme.primary),
                    const SizedBox(width: 8),
                    const Text('版本日志 · v0.0.1',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: 12),
                const _Bullet('全新设计的界面，首页、发现、榜单、音乐库、播放页全部重做'),
                const _Bullet('听过的歌自动缓存，没网也能继续听'),
                const _Bullet('支持手机、平板与横屏车机三种布局'),
                const _Bullet('启动自动签到，连续签到天数一目了然'),
                const _Bullet('内置 GitHub 自动更新，双端构建一键升级'),
                const _Bullet('每日推荐、排行榜、私人 FM、逐字歌词、音效均衡器'),
                const SizedBox(height: 6),
                Text('首个公开版本，欢迎在 GitHub 反馈问题与建议。',
                    style: TextStyle(
                        fontSize: 11.5, color: scheme.onSurface.withValues(alpha: 0.45))),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.description_outlined, size: 20),
            title: const Text('开源许可', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
            trailing: const Icon(Icons.chevron_right_rounded, size: 18),
            onTap: () => showLicensePage(
              context: context,
              applicationName: '爽听',
              applicationVersion: _version,
              applicationIcon: const BrandMark(size: 20),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              Platform.isAndroid ? 'Android 构建 · 以 com.kugou.android 为包名' : 'Windows 构建 · x64',
              style: TextStyle(fontSize: 10.5, color: scheme.onSurface.withValues(alpha: 0.3)),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text('本项目仅用于技术研究与学习，音乐版权归原作者所有。',
                style: TextStyle(fontSize: 10.5, color: scheme.onSurface.withValues(alpha: 0.3))),
          ),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet(this.text);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(color: scheme.primary, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize: 12.5, height: 1.45, color: scheme.onSurface.withValues(alpha: 0.7))),
          ),
        ],
      ),
    );
  }
}

class _LinkCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  const _LinkCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: scheme.surface.withValues(alpha: 0.66),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: scheme.outline.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: color, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 10.5, color: scheme.onSurface.withValues(alpha: 0.4))),
                ],
              ),
            ),
            Icon(Icons.open_in_new_rounded,
                size: 17, color: scheme.onSurface.withValues(alpha: 0.35)),
          ],
        ),
      ),
    );
  }
}
