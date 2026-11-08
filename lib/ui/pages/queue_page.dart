import 'package:flutter/material.dart' hide Text;
import '../widgets/l10n_text.dart';

import '../../core/player/player_service.dart';
import '../../core/theme.dart';
import '../dialogs.dart';
import '../widgets/common.dart';

class QueuePage extends StatelessWidget {
  const QueuePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: PlayerService.instance,
      builder: (context, _) {
        final p = PlayerService.instance;
        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: Text('${t('播放列表')} · ${p.queue.length}'),
            actions: [
              PopupMenuButton<PlayMode>(
                initialValue: p.mode,
                onSelected: p.setMode,
                itemBuilder: (context) => PlayMode.values
                    .map((e) => PopupMenuItem(value: e, child: Text(e.label)))
                    .toList(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      Icon(_modeIcon(p.mode), size: 20),
                      const SizedBox(width: 4),
                      Text(p.mode.label, style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ),
              IconButton(
                tooltip: '清空',
                onPressed: p.queue.isEmpty
                    ? null
                    : () async {
                        if (await confirmDialog(context, '清空播放列表？')) {
                          await p.clearQueue();
                        }
                      },
                icon: const Icon(Icons.delete_sweep_outlined),
              ),
            ],
          ),
          body: p.queue.isEmpty
              ? const EmptyView(text: '播放列表是空的', icon: Icons.queue_music_rounded)
              : ReorderableListView.builder(
                  padding: const EdgeInsets.only(top: 6, bottom: 30),
                  itemCount: p.queue.length,
                  onReorder: p.moveQueue,
                  itemBuilder: (context, i) {
                    final song = p.queue[i];
                    final active = i == p.index;
                    return Padding(
                      key: ValueKey('${song.key}_$i'),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: MusicTile(
                        song: song,
                        index: i,
                        isCurrent: active,
                        onTap: () => p.playAt(i),
                        onMore: () => showSongActions(context, song, onRemoved: () async {
                          await p.removeAt(i);
                        }, removeLabel: '从播放列表移除'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (active) PlayIndicator(playing: p.playing),
                            IconButton(
                              onPressed: () => p.removeAt(i),
                              icon: Icon(Icons.close_rounded, size: 18, color: AppPalette.muted(context)),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }

  IconData _modeIcon(PlayMode mode) {
    switch (mode) {
      case PlayMode.sequence:
        return Icons.format_list_numbered_rounded;
      case PlayMode.repeatAll:
        return Icons.repeat_rounded;
      case PlayMode.repeatOne:
        return Icons.repeat_one_rounded;
      case PlayMode.shuffle:
        return Icons.shuffle_rounded;
    }
  }
}
