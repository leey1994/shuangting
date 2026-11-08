import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart' hide Text;
import './widgets/l10n_text.dart';

import '../core/plugin/plugin_manager.dart';
import '../core/settings.dart';
import '../core/theme.dart';
import 'update_flow.dart';
import 'pages/discover_page.dart';
import 'pages/library_page.dart';
import 'pages/me_page.dart';
import 'pages/search_page.dart';
import 'widgets/common.dart';
import 'widgets/mini_player.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  final List<bool> _visited = [true, false, false, false];

  static const _tabs = [
    _Tab(Icons.explore_outlined, Icons.explore_rounded, '发现'),
    _Tab(Icons.search_outlined, Icons.search_rounded, '搜索'),
    _Tab(Icons.library_music_outlined, Icons.library_music_rounded, '音乐库'),
    _Tab(Icons.person_outline_rounded, Icons.person_rounded, '我的'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(PluginManager.instance.warmup());
      unawaited(_maybeCheckUpdate());
    });
  }

  Future<void> _maybeCheckUpdate() async {
    if (!Settings.instance.get<bool>('autoCheckUpdate')) return;
    // 等首帧和插件预热安静下来再联网，避免和启动抢带宽。
    await Future<void>.delayed(const Duration(seconds: 5));
    if (!mounted) return;
    await checkForUpdates(context, silent: true);
  }

  void _select(int index) {
    if (index == _index) return;
    setState(() {
      _index = index;
      _visited[index] = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final wide = size.width >= 760;
    // IndexedStack 固定四个槽位；未访问过的 Tab 不构建页面，降低冷启动开销。
    final stack = IndexedStack(
      index: _index,
      children: [
        _visited[0] ? const DiscoverPage() : const SizedBox.shrink(),
        _visited[1] ? const SearchPage() : const SizedBox.shrink(),
        _visited[2] ? const LibraryPage() : const SizedBox.shrink(),
        _visited[3] ? const MePage() : const SizedBox.shrink(),
      ],
    );
    final content = Column(
      children: [
        Expanded(child: stack),
        const MiniPlayer(),
      ],
    );

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        body: SafeArea(
          bottom: !wide,
          child: wide
              ? Row(
                  children: [
                    _SideNav(index: _index, tabs: _tabs, onChanged: _select),
                    Expanded(child: content),
                  ],
                )
              : Column(
                  children: [
                    Expanded(child: content),
                    _BottomNav(index: _index, tabs: _tabs, onChanged: _select),
                  ],
                ),
        ),
      ),
    );
  }
}

class _SideNav extends StatelessWidget {
  const _SideNav({required this.index, required this.tabs, required this.onChanged});
  final int index;
  final List<_Tab> tabs;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 6.0;
        const padding = 20.0;
        final available = constraints.maxHeight - padding - gap * (tabs.length - 1);
        final itemHeight = max(46.0, available / tabs.length);
        final itemWidth = min(112.0, itemHeight * 1.3);

        return Container(
          width: itemWidth + 20,
          margin: const EdgeInsets.fromLTRB(10, 10, 4, 10),
          decoration: BoxDecoration(
            color: AppPalette.card(context).withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(28),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Column(
            children: [
              const Spacer(),
              for (var i = 0; i < tabs.length; i++)
                Padding(
                  padding: EdgeInsets.only(bottom: i == tabs.length - 1 ? 0 : gap),
                  child: InkWell(
                    onTap: () => onChanged(i),
                    borderRadius: BorderRadius.circular(18),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: itemWidth,
                      height: itemHeight,
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                      decoration: BoxDecoration(
                        color: index == i ? primary.withValues(alpha: 0.18) : Colors.transparent,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            index == i ? tabs[i].activeIcon : tabs[i].icon,
                            size: 19,
                            color: index == i ? primary : AppPalette.muted(context),
                          ),
                          const SizedBox(height: 3),
                          Flexible(
                            child: Text(
                              t(tabs[i].label),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: index == i ? FontWeight.w700 : FontWeight.w500,
                                color: index == i ? primary : AppPalette.muted(context),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              const Spacer(),
            ],
          ),
        );
      },
    );
  }
}

class _Tab {
  const _Tab(this.icon, this.activeIcon, this.label);
  final IconData icon;
  final IconData activeIcon;
  final String label;
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.index, required this.tabs, required this.onChanged});
  final int index;
  final List<_Tab> tabs;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, max(8.0, bottom + 6)),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppPalette.card(context).withValues(alpha: 0.86),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: AppPalette.isDark(context) ? 0.35 : 0.08),
              blurRadius: 20,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Row(
            children: [
              for (var i = 0; i < tabs.length; i++)
                Expanded(
                  child: InkWell(
                    onTap: () => onChanged(i),
                    borderRadius: BorderRadius.circular(22),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      height: 60,
                      decoration: BoxDecoration(
                        color: index == i ? primary.withValues(alpha: 0.16) : Colors.transparent,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            index == i ? tabs[i].activeIcon : tabs[i].icon,
                            size: 22,
                            color: index == i ? primary : AppPalette.muted(context),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            t(tabs[i].label),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: index == i ? FontWeight.w700 : FontWeight.w500,
                              color: index == i ? primary : AppPalette.muted(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
