import 'package:flutter/material.dart' hide Text;
import '../widgets/l10n_text.dart';

import '../../core/library_store.dart';
import '../../core/player/player_service.dart';
import '../../core/theme.dart';
import '../dialogs.dart';
import '../widgets/common.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LibraryStore.instance,
      builder: (context, _) {
        final lib = LibraryStore.instance;
        final entries = lib.history;
        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: Text('${t('最近播放')} · ${entries.length}'),
            actions: [
              IconButton(
                onPressed: entries.isEmpty
                    ? null
                    : () async {
                        if (await confirmDialog(context, '清空播放历史？')) {
                          await lib.clearHistory();
                        }
                      },
                icon: const Icon(Icons.delete_sweep_outlined),
              ),
            ],
          ),
          body: entries.isEmpty
              ? const EmptyView(text: '还没有播放记录', icon: Icons.history_rounded)
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 40),
                  itemCount: entries.length,
                  itemBuilder: (context, i) {
                    final song = entries[i].song;
                    return MusicTile(
                      song: song,
                      index: i,
                      onTap: () {
                        final songs = entries.map((e) => e.song).toList();
                        PlayerService.instance.playQueue(songs, startIndex: i);
                      },
                      onMore: () => showSongActions(context, song),
                      trailing: Text(
                        _time(entries[i].playedAt),
                        style: TextStyle(fontSize: 10, color: AppPalette.muted(context)),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }

  String _time(int ts) {
    if (ts <= 0) return '';
    final d = DateTime.fromMillisecondsSinceEpoch(ts);
    final now = DateTime.now();
    if (d.year == now.year && d.month == now.month && d.day == now.day) {
      return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    }
    return '${d.month}/${d.day}';
  }
}
