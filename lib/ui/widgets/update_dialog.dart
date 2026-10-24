import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/update_service.dart';

class UpdateDialog extends StatefulWidget {
  final UpdateService service;
  final UpdateInfo info;
  const UpdateDialog({super.key, required this.service, required this.info});

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _started = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: widget.service,
      builder: (context, _) {
        final s = widget.service;
        return AlertDialog(
          icon: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [scheme.primary, AppTheme.mint]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.rocket_launch_rounded, color: Colors.white),
          ),
          title: Text('发现新版本 v${widget.info.version}'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  constraints: const BoxConstraints(maxHeight: 220),
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      widget.info.notes.isEmpty ? '本次更新带来了体验优化与问题修复。' : widget.info.notes,
                      style: const TextStyle(fontSize: 13, height: 1.6),
                    ),
                  ),
                ),
                if (s.downloading) ...[
                  const SizedBox(height: 18),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(100),
                    child: LinearProgressIndicator(
                      value: s.progress > 0 ? s.progress : null,
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(s.message ?? '正在下载…', style: const TextStyle(fontSize: 12)),
                ] else if (s.message != null) ...[
                  const SizedBox(height: 12),
                  Text(s.message!, style: TextStyle(fontSize: 12, color: scheme.primary)),
                ],
                if (!Platform.isAndroid && !Platform.isWindows) ...[
                  const SizedBox(height: 12),
                  const Text('当前平台暂不支持自动安装，请前往发布页手动下载。', style: TextStyle(fontSize: 12)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: s.downloading ? null : () => Navigator.pop(context),
              child: const Text('稍后'),
            ),
            FilledButton(
              onPressed: s.downloading
                  ? null
                  : () async {
                      setState(() => _started = true);
                      final ok = await s.downloadAndInstall();
                      if (!ok && context.mounted) setState(() {});
                    },
              child: Text(s.downloading ? '下载中…' : (_started ? '重试' : '立即更新')),
            ),
          ],
        );
      },
    );
  }
}
