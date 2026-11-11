import 'dart:io';

import 'package:flutter/material.dart' hide Text;
import 'package:url_launcher/url_launcher.dart';
import './widgets/l10n_text.dart';

import '../core/app_info.dart';
import '../core/settings.dart';
import '../core/theme.dart';
import '../core/updater.dart';
import 'widgets/common.dart';

/// 检查更新入口：静默检查只提示一次，手动检查给出明确反馈。
Future<void> checkForUpdates(BuildContext context, {bool silent = false}) async {
  if (!silent) showToast(context, '正在检查更新…');
  final info = await Updater.check(force: !silent);
  if (!context.mounted) return;
  if (info == null) {
    if (!silent) showToast(context, '已是最新版本 v${AppInfo.version}');
    return;
  }
  final dismissed = Settings.instance.get<String>('skipUpdateVersion', '');
  if (silent && dismissed == info.version) return;
  await showDialog<void>(
    context: context,
    builder: (_) => UpdateDialog(info: info),
  );
}

class UpdateDialog extends StatefulWidget {
  const UpdateDialog({super.key, required this.info});
  final UpdateInfo info;

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  double? _progress;
  String? _error;

  bool get _canInstall => widget.info.asset != null;

  Future<void> _start() async {
    setState(() {
      _progress = 0;
      _error = null;
    });
    try {
      final file = await Updater.download(
        widget.info,
        onProgress: (v) {
          if (mounted) setState(() => _progress = v);
        },
      );
      if (!mounted) return;
      setState(() => _progress = null);
      await Updater.install(file);
      if (!mounted) return;
      if (Platform.isAndroid) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() {
        _progress = null;
        _error = '$e';
      });
    }
  }

  Future<void> _openPage() async {
    try {
      await launchUrl(Uri.parse(widget.info.pageUrl), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.info;
    final notes = info.notes.isEmpty ? '包含问题修复与体验优化。' : info.notes;
    final busy = _progress != null;
    return AlertDialog(
      title: Text('发现新版本 v${info.version}'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '当前版本 v${AppInfo.version}',
              style: TextStyle(fontSize: 12, color: AppPalette.muted(context)),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: SingleChildScrollView(
                child: Text(notes, style: const TextStyle(fontSize: 12.5, height: 1.5)),
              ),
            ),
            if (info.asset != null) ...[
              const SizedBox(height: 12),
              Text(
                '${info.asset!.name} · ${info.asset!.sizeMb.toStringAsFixed(1)} MB',
                style: TextStyle(fontSize: 11, color: AppPalette.muted(context)),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: TextStyle(fontSize: 11.5, color: Theme.of(context).colorScheme.error)),
            ],
            if (busy) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(value: _progress == 0 ? null : _progress),
              const SizedBox(height: 6),
              Text(
                _progress == 0 ? '准备下载…' : '下载中 ${((_progress ?? 0) * 100).round()}%',
                style: TextStyle(fontSize: 11, color: AppPalette.muted(context)),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (!busy)
          TextButton(
            onPressed: () {
              Settings.instance.set('skipUpdateVersion', info.version);
              Navigator.of(context).pop();
            },
            child: const Text('跳过此版本'),
          ),
        if (!busy)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('稍后'),
          ),
        if (!busy && _canInstall)
          FilledButton(
            onPressed: _start,
            child: Text(Platform.isAndroid ? '下载并安装' : '下载更新'),
          ),
        if (!busy && !_canInstall)
          FilledButton(
            onPressed: () async {
              await _openPage();
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('前往下载页'),
          ),
      ],
    );
  }
}
