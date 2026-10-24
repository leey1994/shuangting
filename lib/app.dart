import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/theme.dart';
import 'data/audio_cache.dart';
import 'data/download_manager.dart';
import 'data/kg_api.dart';
import 'data/models.dart';
import 'data/store.dart';
import 'data/update_service.dart';
import 'player/player_controller.dart';
import 'ui/pages/about_page.dart';
import 'ui/pages/artist_page.dart';
import 'ui/pages/car_page.dart';
import 'ui/pages/charts_page.dart';
import 'ui/pages/comments_page.dart';
import 'ui/pages/library_page.dart';
import 'ui/pages/onboarding_page.dart';
import 'ui/pages/player_page.dart';
import 'ui/pages/playlist_page.dart';
import 'ui/pages/search_page.dart';
import 'ui/pages/settings_page.dart';
import 'ui/pages/shell.dart';
import 'ui/pages/sound_page.dart';
import 'ui/widgets/update_dialog.dart';

final appNavigatorKey = GlobalKey<NavigatorState>();
final appMessengerKey = GlobalKey<ScaffoldMessengerState>();

class ShuangTingApp extends StatefulWidget {
  final SettingsModel settings;
  final LibraryModel library;
  final PlayerController player;
  final DownloadManager downloads;
  final UpdateService updates;
  final KgApi api;
  final AudioCache cache;

  const ShuangTingApp({
    super.key,
    required this.settings,
    required this.library,
    required this.player,
    required this.downloads,
    required this.updates,
    required this.api,
    required this.cache,
  });

  @override
  State<ShuangTingApp> createState() => _ShuangTingAppState();
}

class _ShuangTingAppState extends State<ShuangTingApp> {
  bool _startupDone = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startup());
  }

  Future<void> _startup() async {
    if (_startupDone) return;
    _startupDone = true;
    final settings = widget.settings;
    if (!settings.onboarded) return;

    if (settings.autoSignIn && !settings.signedInToday) {
      await settings.signInToday();
      if (settings.cookie.isNotEmpty) {
        await widget.api.dailySignIn();
      }
      appMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.verified_rounded, color: Color(0xFF7CE7C4), size: 20),
              const SizedBox(width: 10),
              Text('每日签到成功 · 已连续 ${settings.signInStreak} 天'),
            ],
          ),
        ),
      );
    }

    if (settings.autoUpdate) {
      final info = await widget.updates.check();
      if (info != null && mounted) {
        final ctx = appNavigatorKey.currentContext;
        if (ctx != null) {
          showDialog(context: ctx, builder: (_) => UpdateDialog(service: widget.updates, info: info));
        }
      }
    }
  }

  Route<dynamic>? _route(RouteSettings route) {
    final args = (route.arguments is Map) ? route.arguments as Map : const {};
    Widget page;
    switch (route.name) {
      case '/rank':
        page = RankDetailPage(
          id: (args['id'] as num?)?.toInt() ?? 0,
          name: (args['name'] ?? '').toString(),
          cover: (args['cover'] ?? '').toString(),
          update: (args['update'] ?? '').toString(),
        );
      case '/artist':
        page = ArtistPage(id: (args['id'] as num?)?.toInt() ?? 0, name: (args['name'] ?? '').toString());
      case '/album':
        page = AlbumPage(id: (args['id'] as num?)?.toInt() ?? 0, name: (args['name'] ?? '').toString());
      case '/playlist':
        page = PlaylistPage(id: (args['id'] as num?)?.toInt() ?? 0, name: (args['name'] ?? '').toString());
      case '/search':
        page = SearchPage(initialQuery: (args['q'] ?? '').toString());
      case '/charts':
        page = const ChartsPage();
      case '/settings':
        page = const SettingsPage();
      case '/about':
        page = const AboutPage();
      case '/favorites':
        page = const LibraryPage(initialTab: 0, standalone: true);
      case '/history':
        page = const LibraryPage(initialTab: 1, standalone: true);
      case '/downloads':
        page = const LibraryPage(initialTab: 2, standalone: true);
      case '/library_playlists':
        page = const LibraryPage(initialTab: 3, standalone: true);
      case '/library_local':
        page = const LibraryPage(initialTab: 4, standalone: true);
      case '/sound':
        page = const SoundPage();
      case '/comments':
        page = CommentsPage(song: args['song'] as Song?);
      case '/player':
        page = const PlayerPage();
      case '/car':
        page = const CarPage();
      default:
        return null;
    }
    return PageRouteBuilder(
      settings: route,
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (_, animation, __) => page,
      transitionsBuilder: (_, animation, __, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.025), end: Offset.zero).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('APP BUILD');
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: widget.settings),
        ChangeNotifierProvider.value(value: widget.library),
        ChangeNotifierProvider.value(value: widget.player),
        ChangeNotifierProvider.value(value: widget.downloads),
        ChangeNotifierProvider.value(value: widget.updates),
        Provider.value(value: widget.api),
        Provider.value(value: widget.cache),
      ],
      child: AnimatedBuilder(
        animation: widget.settings,
        builder: (context, _) {
          final brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
          return MaterialApp(
            title: '爽听',
            debugShowCheckedModeBanner: false,
            navigatorKey: appNavigatorKey,
            scaffoldMessengerKey: appMessengerKey,
            theme: AppTheme.build(widget.settings, brightness),
            locale: const Locale('zh', 'CN'),
            supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            onGenerateRoute: _route,
            home: widget.settings.onboarded ? const Shell() : const OnboardingPage(),
            builder: (context, child) {
              final media = MediaQuery.of(context);
              return MediaQuery(
                data: media.copyWith(
                  textScaler: media.textScaler.clamp(minScaleFactor: 0.9, maxScaleFactor: 1.2),
                ),
                child: child ?? const SizedBox.shrink(),
              );
            },
          );
        },
      ),
    );
  }
}
