import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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
          const _ReleaseNotesCard(),
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

/// 版本日志卡片：拉 GitHub Releases 最新版的用户侧更新说明（body）。
/// 拉取失败时回退显示当前版本号。
class _ReleaseNotesCard extends StatefulWidget {
  const _ReleaseNotesCard();

  @override
  State<_ReleaseNotesCard> createState() => _ReleaseNotesCardState();
}

class _ReleaseNotesCardState extends State<_ReleaseNotesCard> {
  String? _tag;
  List<String>? _bullets;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await http.get(
        Uri.parse(
            'https://api.github.com/repos/${UpdateService.repo}/releases/latest'),
        headers: const {
          'Accept': 'application/vnd.github+json',
          'User-Agent': 'ShuangTing-About',
        },
      ).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) throw StateError('http ${res.statusCode}');
      final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final body = (data['body'] as String?) ?? '';
      final lines = body
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.startsWith('- ') || l.startsWith('* '))
          .map((l) => l.substring(2).trim())
          .where((l) => l.isNotEmpty)
          .take(8)
          .toList();
      if (!mounted) return;
      setState(() {
        _tag = (data['tag_name'] as String?) ?? '';
        _bullets = lines.isEmpty ? null : lines;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
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
              Text(
                _failed
                    ? '版本日志'
                    : '版本日志 · ${(_tag ?? '').isEmpty || _tag == 'null' ? '最新版' : _tag!.replaceFirst('v', '')}',
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_bullets == null)
            Text(
              _failed ? '暂未获取到更新说明' : '正在获取最新版本说明…',
              style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurface.withValues(alpha: 0.45)),
            )
          else
            ...[
              for (final b in _bullets!) _Bullet(b),
              const SizedBox(height: 6),
              Text('以上为最新版本更新内容，欢迎在 GitHub 反馈问题与建议。',
                  style: TextStyle(
                      fontSize: 11.5,
                      color: scheme.onSurface.withValues(alpha: 0.45))),
            ],
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {  final String text;
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
