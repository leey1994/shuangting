import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class AppPaths {
  static late Directory docs;
  static late Directory plugins;
  static late Directory downloads;
  static late Directory cache;
  static late Directory covers;
  static bool _initialised = false;

  static Future<void> init() async {
    final local = Platform.environment['LOCALAPPDATA'];
    String? support;
    if (!Platform.isWindows) {
      try {
        support = (await getApplicationSupportDirectory()).path;
      } catch (_) {}
    }
    final userdata = p.join(Directory.current.path, 'userdata');
    final candidates = <String>[
      // 便携版优先：工作目录里已有数据时继续用它，避免新旧两套数据分裂。
      if (Platform.isWindows && File(p.join(userdata, 'preferences.json')).existsSync()) userdata,
      if (Platform.isWindows && local != null && local.isNotEmpty) p.join(local, 'ShuangTingData'),
      ?support,
      userdata,
    ];

    for (final path in candidates) {
      final candidate = Directory(path);
      try {
        await candidate.create(recursive: true);
        final marker = File(p.join(path, '.write-test'));
        await marker.writeAsString('ok');
        await marker.delete();
        docs = candidate;
        _initialised = true;
        debugPrint('[paths] chosen: $path');
        break;
      } catch (e) {
        debugPrint('[paths] rejected: $path ($e)');
      }
    }
    if (!_initialised) throw FileSystemException('没有可写的应用数据目录');

    plugins = Directory(p.join(docs.path, 'plugins'));
    downloads = Directory(p.join(docs.path, 'downloads'));
    cache = Directory(p.join(docs.path, 'cache'));
    covers = Directory(p.join(docs.path, 'covers'));
    for (final d in [plugins, downloads, cache, covers]) {
      await d.create(recursive: true);
    }
  }
}

/// 轻量键值存储：直接写 AppPaths.docs/preferences.json。
/// 不依赖平台插件，受限桌面/移动端行为一致。
class PrefStore {
  PrefStore._();
  static final PrefStore instance = PrefStore._();

  static const _fileName = 'preferences.json';
  final Map<String, dynamic> _data = {};
  bool _loaded = false;
  Future<void> _tail = Future.value();

  File get _file => File(p.join(AppPaths.docs.path, _fileName));

  Future<void> ensure() async {
    if (_loaded) return;
    _loaded = true;
    try {
      if (await _file.exists()) {
        final decoded = jsonDecode(await _file.readAsString());
        if (decoded is Map) {
          _data
            ..clear()
            ..addAll(decoded.map((k, v) => MapEntry(k.toString(), v)));
        }
      }
    } catch (_) {}
  }

  String? getString(String key) => _data[key]?.toString();
  bool? getBool(String key) => _data[key] is bool ? _data[key] as bool : null;
  int? getInt(String key) => _data[key] is int ? _data[key] as int : null;
  double? getDouble(String key) {
    final v = _data[key];
    return v is num ? v.toDouble() : null;
  }

  Future<void> setString(String key, String value) => _put(key, value);
  Future<void> setBool(String key, bool value) => _put(key, value);
  Future<void> setInt(String key, int value) => _put(key, value);
  Future<void> setDouble(String key, double value) => _put(key, value);
  Future<void> remove(String key) => _put(key, null);

  Map<String, dynamic> getJson(String key) {
    final text = getString(key);
    if (text == null || text.isEmpty) return {};
    try {
      final decoded = jsonDecode(text);
      return decoded is Map ? decoded.map((k, v) => MapEntry(k.toString(), v)) : {};
    } catch (_) {
      return {};
    }
  }

  List<dynamic> getJsonList(String key) {
    final text = getString(key);
    if (text == null || text.isEmpty) return [];
    try {
      final decoded = jsonDecode(text);
      return decoded is List ? decoded : [];
    } catch (_) {
      return [];
    }
  }

  Future<void> setJson(String key, Object? value) => _put(key, jsonEncode(value));

  Future<void> _put(String key, Object? value) {
    if (value == null) {
      _data.remove(key);
    } else {
      _data[key] = value;
    }
    _tail = _tail.then((_) async {
      try {
        await _file.parent.create(recursive: true);
        await _file.writeAsString(jsonEncode(_data));
      } catch (_) {}
    });
    return _tail;
  }
}

class Settings extends ChangeNotifier {
  Settings._();
  static final Settings instance = Settings._();

  final Map<String, dynamic> _values = {};

  static const defaults = <String, dynamic>{
    'defaultQuality': 'standard',
    'downloadQuality': 'standard',
    'tryChangeSource': true,
    'autoStopWhenError': false,
    'autoPlayOnStart': false,
    'useCelluarNetworkPlay': true,
    'useCelluarNetworkDownload': true,
    'maxDownload': 2,
    'downloadPath': '',
    'maxHistoryLen': 100,
    'themeMode': 'system',
    'themeSeed': 0xFFFF6B5B,
    'backgroundPath': '',
    'backgroundOpacity': 0.18,
    'backgroundBlur': 0.0,
    'language': 'zh',
    'autoUpdatePlugin': false,
    'subscribeUrl': '',
    'webdavUrl': '',
    'webdavUsername': '',
    'webdavPassword': '',
    'musicDetailDefault': 'album',
    'bluetoothLyric': true,
    'lyricFontSize': 18.0,
    'playSpeed': 1.0,
    'playQualityOrder': 'desc',
    'downloadQualityOrder': 'desc',
    'clickMusicInSearch': 'playMusic',
    'clickMusicInAlbum': 'playAlbum',
    'tempRemoteDuck': 'pause',
    'maxCacheSize': 512,
    'autoCheckUpdate': true,
    'skipUpdateVersion': '',
  };

  Future<void> load() async {
    await PrefStore.instance.ensure();
    final stored = PrefStore.instance.getJson('settings');
    _values
      ..clear()
      ..addAll(defaults)
      ..addAll(stored);
  }

  T get<T>(String key, [T? fallback]) {
    final v = _values[key];
    if (v is T) return v;
    if (v != null) {
      if (T == double && v is num) return v.toDouble() as T;
      if (T == int && v is num) return v.toInt() as T;
      if (T == String) return v.toString() as T;
      if (T == bool && v is String) return (v == 'true') as T;
    }
    if (fallback != null) return fallback;
    final d = defaults[key];
    if (d is T) return d;
    if (d is num && T == double) return d.toDouble() as T;
    if (d is num && T == int) return d.toInt() as T;
    throw StateError('Missing setting $key');
  }

  Future<void> set(String key, dynamic value) async {
    _values[key] = value;
    notifyListeners();
    await PrefStore.instance.setJson('settings', _values);
  }

  Future<void> setMany(Map<String, dynamic> values) async {
    _values.addAll(values);
    notifyListeners();
    await PrefStore.instance.setJson('settings', _values);
  }

  Map<String, dynamic> exportAll() => Map<String, dynamic>.from(_values);

  Future<void> importAll(Map<String, dynamic> values) async {
    _values
      ..clear()
      ..addAll(defaults)
      ..addAll(values);
    notifyListeners();
    await PrefStore.instance.setJson('settings', _values);
  }

  bool get isEnglish => get<String>('language') == 'en';
}

/// 极简 i18n：中文原文直接作为 key，英文查表；缺失时回落中文。
class L10n {
  static final L10n instance = L10n._();
  L10n._();

  bool get en => Settings.instance.isEnglish;

  final Map<String, String> _cache = {};

  static final List<MapEntry<String, String>> _chunks = (() {
    final list = _en.entries.where((e) => e.key.length >= 2).toList();
    list.sort((a, b) => b.key.length.compareTo(a.key.length));
    return list;
  })();

  static final RegExp _numUnit = RegExp(r'(\d+)\s*(个已安装|首|个|分钟|秒|粉丝|作品|变量)');

  String t(String zh) {
    if (!en) return zh;
    final cached = _cache[zh];
    if (cached != null) return cached;
    String out;
    final exact = _en[zh];
    if (exact != null) {
      out = exact;
    } else {
      out = zh.replaceAllMapped(_numUnit, (m) {
        final n = m[1]!;
        switch (m[2]) {
          case '个已安装':
            return '$n installed';
          case '首':
            return '$n ${n == '1' ? 'song' : 'songs'}';
          case '个':
            return n;
          case '分钟':
            return '$n min';
          case '秒':
            return '${n}s';
          case '粉丝':
            return '$n ${n == '1' ? 'fan' : 'fans'}';
          case '作品':
            return '$n ${n == '1' ? 'work' : 'works'}';
          case '变量':
            return '$n vars';
        }
        return m[0]!;
      });
      for (final e in _chunks) {
        if (out.contains(e.key)) out = out.replaceAll(e.key, e.value);
      }
      out = out
          .replaceAll('「', '"')
          .replaceAll('」', '"')
          .replaceAll('，', ', ')
          .replaceAll('。', '. ')
          .replaceAll('：', ': ')
          .replaceAll('？', '?')
          .replaceAll('！', '!');
      out = out.replaceAll(RegExp(r'\s+'), ' ').trim();
    }
    if (_cache.length < 3000) _cache[zh] = out;
    return out;
  }

  static const _en = <String, String>{
    '发现': 'Discover',
    '搜索': 'Search',
    '音乐库': 'Library',
    '我的': 'Me',
    '播放全部': 'Play all',
    '随机播放': 'Shuffle',
    '收藏': 'Favorite',
    '已收藏': 'Favorited',
    '下载': 'Download',
    '更多': 'More',
    '暂无内容': 'Nothing here yet',
    '加载中': 'Loading',
    '加载更多': 'Load more',
    '没有更多了': 'No more',
    '重试': 'Retry',
    '取消': 'Cancel',
    '确定': 'OK',
    '保存': 'Save',
    '删除': 'Delete',
    '清空': 'Clear',
    '设置': 'Settings',
    '插件': 'Plugins',
    '主题': 'Theme',
    '备份': 'Backup',
    '关于': 'About',
    '本地音乐': 'Local music',
    '最近播放': 'Recently played',
    '我的歌单': 'My playlists',
    '我喜欢': 'Favorites',
    '播放列表': 'Queue',
    '歌词': 'Lyrics',
    '单曲': 'Songs',
    '专辑': 'Albums',
    '作者': 'Artists',
    '歌单': 'Playlists',
    '音质': 'Quality',
    '标准': 'Standard',
    '高': 'High',
    '超高': 'Super',
    '低': 'Low',
    '未知歌手': 'Unknown artist',
    '未知专辑': 'Unknown album',
    '搜索歌曲、歌手、专辑': 'Search songs, artists, albums',
    '安装插件': 'Install plugins',
    '没有插件': 'No plugins installed',
    '从网络安装': 'Install from URL',
    '从文件安装': 'Install from file',
    '已启用': 'Enabled',
    '已停用': 'Disabled',
    '自动换源': 'Auto switch source',
    '播放失败自动下一首': 'Skip on error',
    '浅色': 'Light',
    '深色': 'Dark',
    '跟随系统': 'System',
    '背景图': 'Background image',
    '透明度': 'Opacity',
    '模糊': 'Blur',
    '语言': 'Language',
    '清除缓存': 'Clear cache',
    '定时关闭': 'Sleep timer',
    '播放速度': 'Playback speed',
    '添加到歌单': 'Add to playlist',
    '下一首播放': 'Play next',
    '歌曲信息': 'Song info',
    '关联歌词': 'Associate lyrics',
    '搜索歌词': 'Search lyrics',
    '下载中': 'Downloading',
    '已完成': 'Completed',
    '等待中': 'Waiting',
    '失败': 'Failed',
    '暂停': 'Pause',
    '继续': 'Resume',
    '新建歌单': 'New playlist',
    '歌单名称': 'Playlist name',
    '导入歌单': 'Import playlist',
    '导入单曲': 'Import song',
    '远程更新': 'Update from URL',
    '订阅链接': 'Subscription URL',
    '备份到 WebDAV': 'Back up to WebDAV',
    '从 WebDAV 恢复': 'Restore from WebDAV',
    '导出本地备份': 'Export local backup',
    '导入本地备份': 'Import local backup',
    '网页': 'WebDAV',
    '用户名': 'Username',
    '密码': 'Password',
    '地址': 'URL',
    '测试连接': 'Test connection',
    '全部': 'All',
    '完成': 'Done',
    '聚合榜单': 'Aggregated charts',
    '全源热歌': 'Trending across sources',
    '暂无可聚合的榜单\n安装或启用插件后下拉刷新': 'No aggregated charts yet\nInstall or enable plugins, then pull to refresh',
    '正在聚合各音源榜单': 'Aggregating charts from all sources',
    '正在获取推荐': 'Loading recommendations',
    '这个插件还没有推荐内容\n试试搜索，或者换一个插件': 'No recommendations for this plugin\nTry searching or another plugin',
    '还没有下载任务\n在歌曲菜单里点「下载」即可离线保存': 'No downloads yet\nTap “Download” in a song menu to save it offline',
    '还没有播放记录': 'No listening history yet',
    '还没有本地音乐\n添加一个文件夹，扫描手机或电脑里的音频': 'No local music yet\nAdd a folder to scan audio files',
    '这里还没有歌曲': 'No songs here',
    '还没有正在播放的歌曲': 'Nothing is playing',
    '播放列表是空的': 'The queue is empty',
    '没有可用的搜索插件': 'No searchable plugins available',
    '没有找到相关结果': 'No matching results',
    '正在搜索': 'Searching',
    '还没有插件\n爽听不内置音源，安装 MusicFree 插件后就能搜索和播放': 'No plugins installed\nShuangTing does not include sources. Install a MusicFree plugin to search and play.',
    '正在获取歌词': 'Loading lyrics',
    '正在搜索歌词': 'Searching lyrics',
    '暂无歌词\n可以去歌曲菜单里搜索或粘贴歌词': 'No lyrics yet\nSearch or paste lyrics from the song menu',
    '外观模式': 'Appearance',
    '强调色': 'Accent color',
    '自定义背景': 'Custom background',
    '主题与背景': 'Theme and background',
    '插件管理': 'Plugin manager',
    '备份与恢复': 'Backup and restore',
    '删除插件': 'Delete plugin',
    '删除后此音源将从搜索和榜单中移除。': 'This source will be removed from search and charts.',
    '正在删除插件': 'Deleting plugin',
    '已删除': 'Deleted',
    '变量设置': 'Variables',
    '检查更新': 'Check for updates',
    '正在安装插件': 'Installing plugins',
    '关闭': 'Close',
    '蓝牙歌词': 'Bluetooth lyrics',
    '将当前歌词行写入蓝牙媒体信息': 'Send the current lyric line to Bluetooth media metadata',
    '默认音质': 'Default quality',
    '下载音质': 'Download quality',
    '播放失败时自动换源': 'Switch source on playback failure',
    '启动时自动播放': 'Resume playback at startup',
    '同时下载数量': 'Concurrent downloads',
    '默认播放速度': 'Default playback speed',
    '歌词字号': 'Lyric font size',
    '启动时自动检查插件更新': 'Check plugin updates at startup',
    '清除搜索与音源缓存': 'Clear search and source cache',
    '清除歌词缓存': 'Clear lyric cache',
    '清空所有歌单与历史': 'Clear playlists and history',
    '清空所有歌单与历史？': 'Clear all playlists and history?',
    '「我喜欢」中的歌曲也会被清空，此操作不可恢复。': 'Favorites will also be cleared. This cannot be undone.',
    'WebDAV / 本地': 'WebDAV / local',
    '语言 / Language': 'Language',
    '首': 'songs',
    '个': 'items',
    '项': 'items',
    '条': 'results',
    '没有结果': 'No results',
    '搜点什么吧': 'Start a search',
    '应用': 'Apply',
    '应用歌词': 'Apply lyrics',
    '简体中文': '简体中文',
    'English': 'English',
    '下载管理': 'Downloads',
    '正在更新': 'Updating',
    '变量已保存，插件已重载': 'Variables saved and plugin reloaded',
    '显示主窗口': 'Show window',
    '听见爽': 'Pure listening',
    '今天想听点什么？': 'What should we play today?',
    '继续听': 'Continue listening',
    '下一首': 'Next track',
    '上一首': 'Previous track',
    '正在播放': 'Now playing',
    '来自': 'Source',
    '封面': 'Cover',
    '歌词偏移': 'Lyric offset',
    '顺序播放': 'Sequential',
    '列表循环': 'Repeat list',
    '单曲循环': 'Repeat one',
    '退出': 'Exit',
    '· 本地': '· Local',
    'GitHub 仓库': 'GitHub repository',
    'plugins.json 订阅地址': 'plugins.json subscription URL',
    '下午好': 'Good afternoon',
    '下载并安装': 'Download and install',
    '下载更新': 'Download update',
    '个性化': 'Personalization',
    '仅用于个人学习与研究': 'For personal study and research only',
    '从 GitHub Releases 获取最新版本': 'Get the latest version from GitHub Releases',
    '从 WebDAV 恢复备份？': 'Restore backup from WebDAV?',
    '从播放列表移除': 'Remove from queue',
    '从歌单移除': 'Remove from playlist',
    '从网络安装插件': 'Install plugin from URL',
    '优化：插件较多时不再长时间白屏': 'Improved: no long white screen with many plugins',
    '保存为歌单': 'Save as playlist',
    '修复：浅色模式下部分配色对比度不足': 'Fixed: low contrast in light mode',
    '修复：语言切换后部分界面不刷新': 'Fixed: some screens did not refresh after language switch',
    '关闭定时': 'Turn off timer',
    '准备下载…': 'Preparing download…',
    '删除歌单': 'Delete playlist',
    '前往下载页': 'Go to download page',
    '包含问题修复与体验优化。': 'Bug fixes and improvements.',
    '发现好歌单': 'Discover playlists',
    '取消收藏': 'Unfavorite',
    '听见爽 · 主题预览': 'Feel the groove · Theme preview',
    '启动时检查更新': 'Check for updates on startup',
    '在当前插件失败后，尝试其他插件搜索同名歌曲': 'If the current plugin fails, try other plugins for the same song',
    '备份完成': 'Backup complete',
    '夜深了': 'Late night',
    '安装插件，连接你的音乐世界': 'Install plugins to connect your music world',
    '密码 / 应用密码': 'Password / app password',
    '导入完成': 'Import complete',
    '导入本地备份？': 'Import local backup?',
    '导出备份': 'Export backup',
    '已加入下一首': 'Added to play next',
    '已加入下载队列': 'Added to download queue',
    '已取消': 'Canceled',
    '已取消收藏': 'Removed from favorites',
    '已导出备份': 'Backup exported',
    '已清空': 'Cleared',
    '开源许可': 'Open-source licenses',
    '当前': 'Current',
    '当前数据将被覆盖。': 'Current data will be overwritten.',
    '当前歌单、设置与插件将被备份内容覆盖。': 'Current playlists, settings, and plugins will be replaced by the backup.',
    '恢复完成，建议重启应用': 'Restore complete. Restart the app to apply.',
    '把喜欢的歌，听到爽': 'Play the songs you love',
    '排行榜': 'Charts',
    '推荐': 'Recommended',
    '插件 .js / .json / 订阅链接': 'Plugin .js / .json / subscription URL',
    '插件不可用': 'Plugin unavailable',
    '搜索历史': 'Search history',
    '播放': 'Play',
    '播放页默认显示歌词': 'Show lyrics by default on the player',
    '支持 LRC 时间戳，也支持纯文本': 'Supports LRC timestamps and plain text',
    '数据': 'Data',
    '新增：关于页与作者信息': 'Added: About page and author info',
    '新增：应用内在线更新（GitHub Releases）': 'Added: in-app updates via GitHub Releases',
    '新增：项目静态主页': 'Added: static project homepage',
    '新建': 'New',
    '早上好': 'Good morning',
    '时长': 'Duration',
    '晚上好': 'Good evening',
    '更新': 'Update',
    '服务器地址': 'Server URL',
    '未知曲目': 'Unknown track',
    '未设置': 'Not set',
    '本地备份': 'Local backup',
    '本地文件': 'Local file',
    '本地路径': 'Local path',
    '来源': 'Source',
    '标题': 'Title',
    '榜单': 'Charts',
    '歌手': 'Artist',
    '歌曲名 / 歌手': 'Song / artist',
    '歌词已保存': 'Lyrics saved',
    '歌词已应用': 'Lyrics applied',
    '歌词缓存已清除': 'Lyric cache cleared',
    '正在从 WebDAV 恢复': 'Restoring from WebDAV',
    '正在同步订阅': 'Syncing subscription',
    '正在备份到 WebDAV': 'Backing up to WebDAV',
    '正在导入': 'Importing',
    '正在导出': 'Exporting',
    '正在检查更新…': 'Checking for updates…',
    '没有导入到歌曲': 'No songs imported',
    '没有找到歌词': 'No lyrics found',
    '没有插件支持导入单曲': 'No plugin supports importing songs',
    '没有插件支持导入歌单': 'No plugin supports importing playlists',
    '没有获取到专辑': 'No albums found',
    '没有获取到作品': 'No works found',
    '添加文件夹': 'Add folder',
    '清空播放列表？': 'Clear queue?',
    '清空播放历史': 'Clear play history',
    '清空播放历史？': 'Clear play history?',
    '清空歌单？': 'Clear playlist?',
    '清除已完成的下载记录？': 'Clear completed downloads?',
    '爽听': 'ShuangTing',
    '爽听本身不内置任何音源。\\n安装 MusicFree 插件后，搜索、播放、歌单、歌词都能用了。': 'ShuangTing ships with no music sources.\\nInstall MusicFree plugins to enable search, playback, playlists, and lyrics.',
    '爽听用户': 'ShuangTing user',
    '版本日志': 'Changelog',
    '移除该文件夹并重新扫描？': 'Remove this folder and rescan?',
    '稍后': 'Later',
    '管理插件': 'Manage plugins',
    '粘贴': 'Paste',
    '粘贴歌单链接 / ID': 'Paste playlist link / ID',
    '粘贴歌曲链接 / ID': 'Paste song link / ID',
    '粘贴歌词': 'Paste lyrics',
    '给歌单起个名字': 'Name your playlist',
    '缓存已清除': 'Cache cleared',
    '背景模糊': 'Background blur',
    '背景透明度': 'Background opacity',
    '获取失败': 'Failed to load',
    '设置、歌单、历史、歌词关联、插件': 'Settings, playlists, history, lyric links, plugins',
    '该插件不支持歌词搜索': 'This plugin does not support lyric search',
    '该插件没有自定义变量': 'This plugin has no custom variables',
    '该结果没有歌词内容': 'No lyrics in this result',
    '请先播放一首歌': 'Play a song first',
    '跳过此版本': 'Skip this version',
    '输入关键词搜索歌词': 'Enter keywords to search lyrics',
    '还没有安装插件': 'No plugins installed yet',
    '还没有自建歌单，点右上角新建一个吧': 'No playlists yet. Tap New in the top right.',
    '连接失败，请检查地址与账号': 'Connection failed. Check the URL and account.',
    '连接成功': 'Connected',
    '选择导入单曲的插件': 'Choose a plugin to import songs',
    '选择导入歌单的插件': 'Choose a plugin to import playlists',
    '选择背景图片': 'Choose background image',
    '选择音乐文件夹': 'Choose music folder',
    '邮箱': 'Email',
    '重命名': 'Rename',
    '重命名歌单': 'Rename playlist',
    '链接': 'Link',
    '问题反馈': 'Issues',
    '项目主页': 'Homepage',
    '首个公开版本：插件音源、聚合榜单、播放与歌词、下载、本地扫描、备份': 'First public release: plugins, aggregated charts, playback and lyrics, downloads, local scan, backup',
    '个已安装': ' installed',
    '戴上耳机，世界安静': 'put on your headphones and let the world go quiet',
    '插件化音乐播放器，界面完全重绘': 'plugin-based music player with a fully custom UI',
    '更新来自 GitHub Releases': 'Updates from GitHub Releases',
    '当前版本': 'Current version',
    '发现新版本': 'New version found',
    '已是最新版本': 'You are up to date',
    '上次备份：': 'Last backup: ',
    '导入失败：': 'Import failed: ',
    '已复制': 'Copied ',
    '选择文件夹失败：': 'Failed to pick folder: ',
    '删除歌单「': 'Delete playlist "',
    '已保存「': 'Saved "',
    '已添加': 'Added ',
    '到「': ' to "',
    '已应用到「': 'Applied to "',
    '将这首歌的歌词应用到「': 'Apply this song\'s lyrics to "',
    '已找到': 'Found ',
    '扫描完成，共': 'Scan complete, ',
    '订阅完成，安装': 'Subscription done, installed ',
    '已更新到': 'Updated to ',
    '暂未设置': 'Not set',
    '珊瑚': 'Coral',
    '海蓝': 'Ocean blue',
    '森林': 'Forest',
    '紫罗兰': 'Violet',
    '琥珀': 'Amber',
    '桃粉': 'Peach',
    '推荐歌单': 'Recommended playlists',
    '纯粹地听歌': 'Pure listening',
    '官方榜': 'Official charts',
    '风格': 'Style',
    '语种': 'Language',
    '流派': 'Genre',
  };
}
