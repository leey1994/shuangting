import 'package:flutter/material.dart' hide Text;
import '../widgets/l10n_text.dart';

import '../../core/download_service.dart';
import '../../core/player/player_service.dart';
import '../../core/theme.dart';
import '../dialogs.dart';
import '../widgets/common.dart';

class DownloadsPage extends StatelessWidget {
  const DownloadsPage({super.key});

  String _statusText(DownloadTask t) {
    switch (t.status) {
      case DownloadStatus.waiting:
        return '等待中';
      case DownloadStatus.downloading:
        return '下载中 ${(t.progress * 100).toStringAsFixed(0)}%';
      case DownloadStatus.completed:
        return '已完成';
      case DownloadStatus.failed:
        return '失败${t.error == null ? '' : '：${t.error}'}';
      case DownloadStatus.canceled:
        return '已取消';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: DownloadService.instance,
      builder: (context, _) {
        final service = DownloadService.instance;
        final tasks = service.tasks;
        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: Text('${t('下载管理')} · ${tasks.length}'),
            actions: [
              IconButton(
                onPressed: tasks.isEmpty
                    ? null
                    : () async {
                        if (await confirmDialog(context, '清除已完成的下载记录？')) {
                          await service.clearCompleted();
                        }
                      },
                icon: const Icon(Icons.cleaning_services_outlined),
              ),
            ],
          ),
          body: tasks.isEmpty
              ? const EmptyView(
                  icon: Icons.download_done_rounded,
                  text: '还没有下载任务\n在歌曲菜单里点「下载」即可离线保存',
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(top: 6, bottom: 40),
                  itemCount: tasks.length,
                  itemBuilder: (context, i) {
                    final task = tasks[i];
                    final done = task.status == DownloadStatus.completed;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: done ? () => PlayerService.instance.playNow(task.song) : null,
                            child: CoverImage(path: task.song.artwork, size: 54, radius: 14),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(task.song.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                                const SizedBox(height: 3),
                                Text(
                                  '${task.song.displayArtist} · ${_statusText(task)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 11, color: task.status == DownloadStatus.failed ? Colors.redAccent : AppPalette.muted(context)),
                                ),
                                if (task.status == DownloadStatus.downloading) ...[
                                  const SizedBox(height: 6),
                                  LinearProgressIndicator(value: task.progress, minHeight: 3),
                                ],
                              ],
                            ),
                          ),
                          if (done)
                            IconButton(onPressed: () => PlayerService.instance.playNow(task.song), icon: const Icon(Icons.play_circle_outline_rounded))
                          else if (task.status == DownloadStatus.downloading || task.status == DownloadStatus.waiting)
                            IconButton(onPressed: () => service.cancel(task), icon: const Icon(Icons.close_rounded))
                          else
                            IconButton(onPressed: () => service.remove(task), icon: const Icon(Icons.delete_outline_rounded)),
                        ],
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}
