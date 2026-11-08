import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' hide Text;
import '../widgets/l10n_text.dart';

import '../../core/local_library.dart';
import '../../core/player/player_service.dart';
import '../../core/theme.dart';
import '../dialogs.dart';
import '../widgets/common.dart';

class LocalMusicPage extends StatefulWidget {
  const LocalMusicPage({super.key});

  @override
  State<LocalMusicPage> createState() => _LocalMusicPageState();
}

class _LocalMusicPageState extends State<LocalMusicPage> {
  bool _scanning = false;
  int _found = 0;
  String _currentFile = '';

  Future<void> _addFolder() async {
    try {
      final path = await FilePicker.getDirectoryPath(dialogTitle: '选择音乐文件夹');
      if (path == null) return;
      await LocalLibrary.instance.addFolder(path);
      await _rescan();
    } catch (e) {
      if (mounted) showToast(context, '选择文件夹失败：$e');
    }
  }

  Future<void> _rescan() async {
    if (_scanning) return;
    setState(() {
      _scanning = true;
      _found = 0;
      _currentFile = '';
    });
    final count = await LocalLibrary.instance.rescan(onProgress: (found, name) {
      if (!mounted) return;
      setState(() {
        _found = found;
        _currentFile = name;
      });
    });
    if (mounted) {
      setState(() => _scanning = false);
      showToast(context, '扫描完成，共 $count 首');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LocalLibrary.instance,
      builder: (context, _) {
        final lib = LocalLibrary.instance;
        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: Text('${t('本地音乐')} · ${lib.songs.length}'),
            actions: [
              IconButton(onPressed: _scanning ? null : _rescan, icon: const Icon(Icons.refresh_rounded)),
              IconButton(onPressed: _addFolder, icon: const Icon(Icons.create_new_folder_outlined)),
              if (lib.songs.isNotEmpty)
                IconButton(
                  onPressed: () => PlayerService.instance.playQueue(lib.songs),
                  icon: const Icon(Icons.play_circle_outline_rounded),
                ),
            ],
          ),
          body: Column(
            children: [
              if (lib.folders.isNotEmpty)
                SizedBox(
                  height: 44,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
                    itemCount: lib.folders.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final f = lib.folders[i];
                      return InputChip(
                        label: Text(f, style: const TextStyle(fontSize: 11)),
                        visualDensity: VisualDensity.compact,
                        onDeleted: () async {
                          if (await confirmDialog(context, '移除该文件夹并重新扫描？')) {
                            await lib.removeFolder(f);
                          }
                        },
                      );
                    },
                  ),
                ),
              if (_scanning)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Column(
                    children: [
                      const LinearProgressIndicator(minHeight: 3),
                      const SizedBox(height: 6),
                      Text('已找到 $_found 首 · $_currentFile', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: AppPalette.muted(context))),
                    ],
                  ),
                ),
              Expanded(
                child: lib.songs.isEmpty
                    ? EmptyView(
                        icon: Icons.folder_open_rounded,
                        text: '还没有本地音乐\n添加一个文件夹，扫描手机或电脑里的音频',
                        action: _scanning ? null : _addFolder,
                        actionLabel: '添加文件夹',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 40),
                        itemCount: lib.songs.length,
                        itemBuilder: (context, i) {
                          final song = lib.songs[i];
                          return MusicTile(
                            song: song,
                            index: i,
                            onTap: () => PlayerService.instance.playQueue(lib.songs, startIndex: i),
                            onMore: () => showSongActions(context, song),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
