import 'dart:convert';

import 'package:flutter/material.dart' hide Text;
import 'package:http/http.dart' as http;
import '../widgets/l10n_text.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_info.dart';
import '../../core/theme.dart';
import '../update_flow.dart';
import '../widgets/common.dart';

/// 关于页：版本、作者、仓库与更新入口。
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  Future<void> _copy(BuildContext context, String text, String label) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) showToast(context, '已复制$label：$text');
  }

  Future<void> _open(BuildContext context, String url) async {
    try {
      final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) await _copy(context, url, '链接');
    } catch (_) {
      if (context.mounted) await _copy(context, url, '链接');
    }
  }

  @override
  Widget build(BuildContext context) {
    final muted = TextStyle(fontSize: 12, color: AppPalette.muted(context));
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Tr('关于')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          const SizedBox(height: 18),
          Center(
            child: Column(
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    gradient: AppPalette.brandGradient(context),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.graphic_eq_rounded, color: Colors.white, size: 40),
                ),
                const SizedBox(height: 14),
                ShaderMask(
                  shaderCallback: (rect) => AppPalette.brandGradient(context).createShader(rect),
                  child: const Text(
                    AppInfo.appName,
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 3),
                  ),
                ),
                const SizedBox(height: 6),
                Text('v${AppInfo.fullVersion} · ${AppInfo.slogan}', style: muted),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const SectionTitle('作者'),
          ListTile(
            leading: const Icon(Icons.person_outline_rounded),
            title: const Text(AppInfo.author),
            subtitle: const Text(AppInfo.email, style: TextStyle(fontSize: 12)),
            trailing: const Icon(Icons.copy_rounded, size: 18),
            onTap: () => _copy(context, AppInfo.email, '邮箱'),
          ),
          ListTile(
            leading: const Icon(Icons.code_rounded),
            title: const Text('GitHub 仓库'),
            subtitle: Text(AppInfo.repoUrl, style: const TextStyle(fontSize: 12)),
            trailing: const Icon(Icons.open_in_new_rounded, size: 18),
            onTap: () => _open(context, AppInfo.repoUrl),
          ),
          ListTile(
            leading: const Icon(Icons.home_outlined),
            title: const Text('项目主页'),
            subtitle: Text(AppInfo.homepageUrl, style: const TextStyle(fontSize: 12)),
            trailing: const Icon(Icons.open_in_new_rounded, size: 18),
            onTap: () => _open(context, AppInfo.homepageUrl),
          ),
          ListTile(
            leading: const Icon(Icons.bug_report_outlined),
            title: const Text('问题反馈'),
            subtitle: Text(AppInfo.issuesUrl, style: const TextStyle(fontSize: 12)),
            trailing: const Icon(Icons.open_in_new_rounded, size: 18),
            onTap: () => _open(context, AppInfo.issuesUrl),
          ),
          const SectionTitle('更新'),
          ListTile(
            leading: const Icon(Icons.system_update_rounded),
            title: const Text('检查更新'),
            subtitle: Text('当前 v${AppInfo.version} · 更新来自 GitHub Releases', style: const TextStyle(fontSize: 12)),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => checkForUpdates(context),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('版本日志'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChangelogPage())),
          ),
          ListTile(
            leading: const Icon(Icons.gavel_rounded),
            title: const Text('开源许可'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => showLicensePage(
              context: context,
              applicationName: AppInfo.appName,
              applicationVersion: AppInfo.fullVersion,
              applicationLegalese: '作者 ${AppInfo.author} · ${AppInfo.email}',
            ),
          ),
          const SizedBox(height: 20),
          Center(child: Text('仅用于个人学习与研究', style: muted)),
        ],
      ),
    );
  }
}

class ChangelogPage extends StatefulWidget {
  const ChangelogPage({super.key});

  @override
  State<ChangelogPage> createState() => _ChangelogPageState();
}

class _ChangelogPageState extends State<ChangelogPage> {
  static List<(String, List<String>)>? _cached;
  List<(String, List<String>)>? _entries = _cached;
  String? _error;
  bool _loading = _cached == null;

  @override
  void initState() {
    super.initState();
    if (_cached == null) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await http
          .get(Uri.parse(AppInfo.changelogUrl))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) throw StateError('HTTP ${res.statusCode}');
      final parsed = _parse(utf8.decode(res.bodyBytes));
      if (parsed.isEmpty) throw StateError('日志为空');
      _cached = parsed;
      if (mounted) setState(() {
        _entries = parsed;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  /// 直接解析仓库里的 CHANGELOG.md：## 标题为版本，随后 - / * 为条目。
  static List<(String, List<String>)> _parse(String text) {
    final result = <(String, List<String>)>[];
    List<String>? current;
    final newline = String.fromCharCode(10);
    for (final raw in text.split(newline)) {
      final line = raw.trimRight();
      if (line.startsWith('## ')) {
        current = <String>[];
        result.add((line.substring(3).trim(), current));
      } else if (current != null &&
          (line.startsWith('- ') || line.startsWith('* '))) {
        current.add(line.substring(2).trim());
      }
    }
    return result;
  }

  static bool _isCurrent(String heading) {
    var h = heading.toLowerCase();
    if (h.startsWith('v')) h = h.substring(1);
    final version = AppInfo.version.toLowerCase();
    return h == version || h.startsWith('$version ');
  }

  @override
  Widget build(BuildContext context) {
    final entries = _entries;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Tr('版本日志'),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: '刷新',
          ),
        ],
      ),
      body: _loading
          ? const LoadingView(text: '正在获取版本日志…')
          : entries == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('版本日志加载失败：$_error',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: AppPalette.muted(context))),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('重试'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text('实时来自 GitHub CHANGELOG.md',
                            style: TextStyle(fontSize: 11, color: AppPalette.muted(context))),
                      ),
                      for (final entry in entries) ...[
                        Row(
                          children: [
                            Expanded(
                              child: Text(entry.$1,
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                            ),
                            if (_isCurrent(entry.$1))
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text('当前',
                                    style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.primary)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        for (final line in entry.$2)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text('• $line',
                                style: TextStyle(fontSize: 12.5, height: 1.45, color: AppPalette.muted(context))),
                          ),
                        const SizedBox(height: 18),
                      ],
                    ],
                  ),
                ),
    );
  }
}
