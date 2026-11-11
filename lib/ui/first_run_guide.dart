import 'package:flutter/material.dart' hide Text;
import 'package:url_launcher/url_launcher.dart';

import '../core/app_info.dart';
import '../core/plugin/plugin_manager.dart';
import '../core/settings.dart';
import '../core/theme.dart';
import 'widgets/common.dart';
import 'widgets/l10n_text.dart';

/// 首次运行引导：爽听不内置音源，指引用户到 hebijunge 的 MusicFree 插件订阅站。
class FirstRunGuide {
  FirstRunGuide._();

  static const siteUrl = AppInfo.pluginSiteUrl;
  static const recommendedUrl = AppInfo.recommendedSubscribeUrl;

  static Future<void> maybeShow(BuildContext context) async {
    if (Settings.instance.get<bool>('firstRunDone')) return;
    if (PluginManager.instance.records.isNotEmpty) {
      await Settings.instance.set('firstRunDone', true);
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          _FirstRunDialog(onSubscribe: () => subscribeRecommended(context)),
    );
    await Settings.instance.set('firstRunDone', true);
  }

  static Future<void> openSite(BuildContext context) async {
    try {
      final ok = await launchUrl(
        Uri.parse(siteUrl),
        mode: LaunchMode.externalApplication,
      );
      if (!ok && context.mounted) showToast(context, '无法打开浏览器：$siteUrl');
    } catch (e) {
      if (context.mounted) showToast(context, '无法打开浏览器：$siteUrl');
    }
  }

  /// 订阅常用六平台清单；进度与结果都在当前页面反馈。
  static Future<void> subscribeRecommended(BuildContext context) async {
    BuildContext? dialogContext;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (c) {
        dialogContext = c;
        return const PopScope(
          canPop: false,
          child: Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 30, vertical: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(strokeWidth: 2.4),
                    SizedBox(height: 16),
                    Text('正在安装常用音源插件…', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
    try {
      await Settings.instance.set('subscribeUrl', recommendedUrl);
      final installed = await PluginManager.instance.installFromUrl(
        recommendedUrl,
      );
      if (context.mounted) showToast(context, '已安装 ${installed.length} 个音源插件');
    } catch (e) {
      if (context.mounted) showToast(context, '订阅失败：$e\n可打开订阅站手动复制 .json 链接');
    } finally {
      // 进度卡带 PopScope(canPop: false)，maybePop 会被拦下来弹不掉，
      // 用弹窗自己的 context 直接 pop，避免误关下面的页面。
      final c = dialogContext;
      if (c != null && c.mounted) Navigator.of(c).pop();
    }
  }
}

class _FirstRunDialog extends StatelessWidget {
  const _FirstRunDialog({required this.onSubscribe});
  final Future<void> Function() onSubscribe;

  @override
  Widget build(BuildContext context) {
    final muted = AppPalette.muted(context);
    return AlertDialog(
      title: const Text('首次使用 · 订阅音源'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '爽听本身不内置任何音源。请先通过 hebijunge 的 MusicFree 插件订阅站安装插件，'
              '之后即可搜索、播放、查看榜单与歌词。',
              style: TextStyle(fontSize: 13, height: 1.6),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.link_rounded, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      FirstRunGuide.siteUrl,
                      style: TextStyle(fontSize: 11, color: muted),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '推荐「常用六平台」清单：QQ / 酷我 / 酷狗 / 咪咕 / 网易云 / 汽水，'
              '体积小、成功率高；需要更多音源可在订阅站选择分类或全部插件。',
              style: TextStyle(fontSize: 11.5, height: 1.5, color: muted),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('稍后'),
        ),
        TextButton(
          onPressed: () => FirstRunGuide.openSite(context),
          child: const Text('打开订阅站'),
        ),
        FilledButton(
          onPressed: () async {
            Navigator.of(context).pop();
            await onSubscribe();
          },
          child: const Text('订阅常用六平台'),
        ),
      ],
    );
  }
}
