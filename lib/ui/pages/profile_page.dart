import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../data/kg_api.dart';
import '../../data/store.dart';
import '../../data/update_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final settings = context.watch<SettingsModel>();
    final library = context.watch<LibraryModel>();
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 170),
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('我的',
                      style: TextStyle(
                          fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: -1)),
                  SizedBox(height: 3),
                  Text('认真听歌，也认真生活', style: TextStyle(fontSize: 12.5)),
                ],
              ),
            ),
            IconButton(
              onPressed: () => Navigator.pushNamed(context, '/settings'),
              icon: const Icon(Icons.settings_rounded),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _ProfileCard(settings: settings, library: library),
        const SizedBox(height: 16),
        _SignInCard(settings: settings),
        const SizedBox(height: 16),
        _Stats(library: library),
        const SizedBox(height: 24),
        Text('我的音乐', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        _GridActions(
          items: [
            (Icons.favorite_rounded, '我的收藏', '${library.favorites.length}', const Color(0xFFFF4D6D), '/favorites'),
            (Icons.history_rounded, '播放历史', '${library.history.length}', const Color(0xFF3AA0FF), '/history'),
            (Icons.download_done_rounded, '下载管理', '${library.downloads.length}', const Color(0xFF7B5CFF), '/downloads'),
            (Icons.graphic_eq_rounded, '音效设置', '均衡器', AppTheme.mint, '/sound'),
          ],
        ),
        const SizedBox(height: 12),
        _GridActions(
          items: [
            (Icons.queue_music_rounded, '自建歌单', '${library.playlists.length}', const Color(0xFFFFA62B), '/library_playlists'),
            (Icons.folder_rounded, '本地音乐', '${library.local.length}', const Color(0xFFF25C9C), '/library_local'),
            (Icons.directions_car_rounded, '车机模式', '横屏', const Color(0xFF35D6A4), '/car'),
            (Icons.info_rounded, '关于爽听', 'v0.0.1', scheme.onSurface.withValues(alpha: 0.5), '/about'),
          ],
        ),
        const SizedBox(height: 24),
        Text('账号与同步', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        _AccountCard(settings: settings),
        const SizedBox(height: 18),
        Center(
          child: Text('爽听 · 为热爱音乐的你而作',
              style: TextStyle(fontSize: 11, color: scheme.onSurface.withValues(alpha: 0.3))),
        ),
      ],
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final SettingsModel settings;
  final LibraryModel library;
  const _ProfileCard({required this.settings, required this.library});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary.withValues(alpha: 0.28),
            const Color(0xFF7B5CFF).withValues(alpha: 0.18),
            scheme.surface,
          ],
        ),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [scheme.primary, AppTheme.mint]),
            ),
            alignment: Alignment.center,
            child: Text(
              settings.nickname.isEmpty ? '爽' : settings.nickname.substring(0, 1),
              style: const TextStyle(
                  fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF0A0C12)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(settings.nickname,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('VIP',
                          style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.5)),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text('连续签到 ${settings.signInStreak} 天 · 累计 ${settings.signInTotal} 天',
                    style: TextStyle(
                        fontSize: 11.5, color: scheme.onSurface.withValues(alpha: 0.5))),
                const SizedBox(height: 10),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () => _rename(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: const Size(0, 28),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: const Icon(Icons.edit_rounded, size: 14),
                      label: const Text('编辑昵称', style: TextStyle(fontSize: 11)),
                    ),
                    Text('· 已收藏 ${library.favorites.length} 首',
                        style: TextStyle(
                            fontSize: 11, color: scheme.onSurface.withValues(alpha: 0.4))),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _rename(BuildContext context) async {
    final controller = TextEditingController(text: settings.nickname);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('修改昵称'),
        content: TextField(controller: controller, autofocus: true, maxLength: 16),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('保存')),
        ],
      ),
    );
    if (name != null && name.trim().isNotEmpty) {
      settings.nickname = name.trim();
    }
  }
}

class _SignInCard extends StatelessWidget {
  final SettingsModel settings;
  const _SignInCard({required this.settings});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final days = List.generate(7, (i) {
      final d = now.subtract(Duration(days: 6 - i));
      final key =
          '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      return (d, settings.signInDates.contains(key));
    });
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFA62B).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.workspace_premium_rounded,
                    color: Color(0xFFFFA62B), size: 21),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('爽听 VIP · 每日签到',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                    SizedBox(height: 2),
                    Text('启动后自动签到，连续签到积累天数',
                        style: TextStyle(fontSize: 10.5)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.mint.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(settings.signedInToday ? '今日已签' : '待签到',
                    style: const TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.mint)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final d in days)
                Column(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: d.$2
                            ? scheme.primary.withValues(alpha: 0.18)
                            : scheme.surfaceContainerHighest.withValues(alpha: 0.7),
                        border: Border.all(
                          color: d.$2
                              ? scheme.primary.withValues(alpha: 0.55)
                              : Colors.transparent,
                        ),
                      ),
                      child: Icon(
                        d.$2 ? Icons.check_rounded : Icons.circle_outlined,
                        size: 15,
                        color: d.$2
                            ? scheme.primary
                            : scheme.onSurface.withValues(alpha: 0.2),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('${d.$1.day}',
                        style: TextStyle(
                            fontSize: 9,
                            color: scheme.onSurface.withValues(alpha: 0.4))),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  final LibraryModel library;
  const _Stats({required this.library});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final minutes = library.listenSeconds ~/ 60;
    final items = [
      ('收藏', '${library.favorites.length}'),
      ('下载', '${library.downloads.length}'),
      ('听歌', minutes >= 60 ? '${(minutes / 60).toStringAsFixed(1)}h' : '${minutes}m'),
    ];
    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: scheme.surface.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Text(items[i].$2,
                      style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 3),
                  Text(items[i].$1,
                      style: TextStyle(
                          fontSize: 10.5,
                          color: scheme.onSurface.withValues(alpha: 0.4))),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _GridActions extends StatelessWidget {
  final List<(IconData, String, String, Color, String)> items;
  const _GridActions({required this.items});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: InkWell(
              onTap: () {
                final route = items[i].$5;
                Navigator.pushNamed(context, route);
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                decoration: BoxDecoration(
                  color: scheme.surface.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: scheme.outline.withValues(alpha: 0.18)),
                ),
                child: Column(
                  children: [
                    Icon(items[i].$1, color: items[i].$4, size: 23),
                    const SizedBox(height: 7),
                    Text(items[i].$2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(items[i].$3,
                        style: TextStyle(
                            fontSize: 9,
                            color: scheme.onSurface.withValues(alpha: 0.35))),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _AccountCard extends StatelessWidget {
  final SettingsModel settings;
  const _AccountCard({required this.settings});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final api = context.read<KgApi>();
    final bound = settings.cookie.trim().isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          ListTile(
            leading: Icon(bound ? Icons.link_rounded : Icons.link_off_rounded,
                color: bound ? AppTheme.mint : scheme.onSurface.withValues(alpha: 0.4)),
            title: Text(bound ? '已绑定酷狗账号' : '未绑定酷狗账号',
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
            subtitle: Text(bound ? '签到时会同步调用账号签到接口' : '绑定 Cookie 后可同步账号签到',
                style: const TextStyle(fontSize: 11)),
            trailing: FilledButton.tonal(
              onPressed: () => _bind(context, api),
              child: Text(bound ? '更新' : '绑定'),
            ),
          ),
          Divider(height: 1, color: scheme.outline.withValues(alpha: 0.2)),
          ListTile(
            leading: const Icon(Icons.public_rounded),
            title: const Text('GitHub 项目主页', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
            subtitle: const Text(UpdateService.repoUrl, style: TextStyle(fontSize: 11)),
            trailing: const Icon(Icons.open_in_new_rounded, size: 18),
            onTap: () => Navigator.pushNamed(context, '/about'),
          ),
        ],
      ),
    );
  }

  Future<void> _bind(BuildContext context, KgApi api) async {
    final controller = TextEditingController(text: settings.cookie);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('绑定酷狗账号'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '在浏览器登录酷狗音乐网页版，复制请求头中的 Cookie（包含 token、userid 等字段），粘贴到下方。',
                style: TextStyle(fontSize: 12, height: 1.5),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 4,
                decoration: const InputDecoration(hintText: 'token=...; userid=...;'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ''),
            child: const Text('解除绑定'),
          ),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('保存')),
        ],
      ),
    );
    if (result != null) {
      settings.cookie = result;
      api.cookie = result;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result.isEmpty ? '已解除绑定' : '账号绑定已保存')));
      }
    }
  }
}
