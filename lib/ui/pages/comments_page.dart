import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../data/kg_api.dart';
import '../../data/models.dart';
import '../widgets/common.dart';

class CommentsPage extends StatefulWidget {
  final Song? song;
  const CommentsPage({super.key, this.song});

  @override
  State<CommentsPage> createState() => _CommentsPageState();
}

class _CommentsPageState extends State<CommentsPage> {
  List<CommentItem> _comments = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final song = widget.song;
    if (song == null) {
      setState(() => _loading = false);
      return;
    }
    final list = await context.read<KgApi>().comments(song);
    if (!mounted) return;
    setState(() {
      _comments = list;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final song = widget.song;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('歌曲评论')),
      body: song == null
          ? const EmptyView(title: '没有选择歌曲')
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: Row(
                    children: [
                      CoverArt(url: song.coverUrl, size: 52, radius: 14, seed: song.hash.hashCode),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(song.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text(song.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 11,
                                    color: scheme.onSurface.withValues(alpha: 0.45))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: scheme.outline.withValues(alpha: 0.2)),
                Expanded(
                  child: _loading
                      ? const LoadingView(label: '正在加载评论…')
                      : _comments.isEmpty
                          ? const EmptyView(
                              icon: Icons.chat_bubble_outline_rounded,
                              title: '暂时没有可显示的评论',
                              subtitle: '评论服务可能受地区或版权限制\n你仍然可以安静地听完这首歌',
                            )
                          : RefreshIndicator(
                              onRefresh: _load,
                              child: ListView.separated(
                                padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                                itemCount: _comments.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 18),
                                itemBuilder: (_, i) {
                                  final c = _comments[i];
                                  return Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      CoverArt(
                                          url: c.avatarUrl,
                                          size: 38,
                                          radius: 19,
                                          seed: c.user.hashCode),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(c.user,
                                                      style: TextStyle(
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.w700,
                                                          color: scheme.onSurface
                                                              .withValues(alpha: 0.65))),
                                                ),
                                                Text(c.time,
                                                    style: TextStyle(
                                                        fontSize: 9.5,
                                                        color: scheme.onSurface
                                                            .withValues(alpha: 0.3))),
                                              ],
                                            ),
                                            const SizedBox(height: 5),
                                            Text(c.content,
                                                style: const TextStyle(fontSize: 13, height: 1.5)),
                                            const SizedBox(height: 6),
                                            Row(
                                              children: [
                                                Icon(Icons.favorite_border_rounded,
                                                    size: 13,
                                                    color:
                                                        scheme.onSurface.withValues(alpha: 0.3)),
                                                const SizedBox(width: 4),
                                                Text(formatCount(c.likes),
                                                    style: TextStyle(
                                                        fontSize: 10,
                                                        color: scheme.onSurface
                                                            .withValues(alpha: 0.3))),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                ),
              ],
            ),
    );
  }
}
