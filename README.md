# 爽听 ShuangTing

> 当前版本 **v1.1.1** 

插件化音乐播放器。

Flutter 实现，支持 **Android / Windows**，默认简体中文，可切换 English。

## 下载与更新

- 发布构建物：<https://github.com/leey1994/shuangting/releases>
- App 内置「检查更新」（关于页 / 设置页），启动时默认静默检查一次，更新包直接取自 GitHub Releases。
- Android 使用分 ABI 拆分包：优先下载 `arm64-v8a`，老设备用 `armeabi-v7a`。

## 功能

- **插件音源**：QuickJS 运行 MusicFree CommonJS 插件；内置 `axios / cheerio / crypto-js / dayjs / qs / he / big-integer / cookies` 兼容模块。
- **搜索**：单曲、专辑、作者、歌单、歌词，多插件聚合。
- **播放**：队列、顺序 / 列表循环 / 单曲循环 / 随机、倍速、定时关闭、失败自动换源、远程音频本地代理（补 Referer / UA / Cookie）。
- **详情页**：专辑、作者作品、歌单 / 榜单，分页加载。
- **发现**：推荐歌单、标签筛选、各插件榜单、**全音源榜单聚合与全源热歌**。
- **Android 媒体通知**：常驻播放通知、封面、进度、上一首 / 播放暂停 / 下一首与锁屏控制。
- **音乐库**：我喜欢、最近播放、自建歌单、歌单排序 / 重命名 / 删除。
- **导入**：歌单导入（插件 `importMusicSheet`）、单曲导入、插件订阅链接。
- **歌词**：逐行同步、字号调节、歌词搜索、**跨音源自动匹配歌词**、歌词关联到其他歌曲。
- **蓝牙歌词**：可将当前歌词行写入 Android 蓝牙媒体信息（专辑/副标题字段），便于车机显示。
- **车机横屏**：宽屏自动切换侧边导航，播放页双栏布局。
- **Windows 托盘**：托盘图标、显示主窗口、播放/暂停、下一首、退出；关闭窗口默认最小化到托盘。
- **本地音乐**：文件夹扫描、ID3 元数据与内嵌封面读取。
- **下载管理**：并发数、进度、取消、断点文件、下载目录。
- **个性化**：6 套主题色、明暗/跟随系统、背景图 + 透明度 + 模糊、语言切换。
- **数据**：WebDAV 备份 / 恢复、本地 JSON 导出 / 导入。
- **插件管理**：URL / 文件安装、启用停用、排序、变量配置、远程更新、卸载。

## 运行

```bash
flutter pub get
flutter run -d windows     # 或 android
flutter build windows --release
# 按 ABI 拆分，体积远小于通用包
flutter build apk --release --split-per-abi \
  --split-debug-info=build/symbols/android --obfuscate
```

要求 Flutter 3.47+ / Dart 3.13+。Windows 构建已为 `quickjs_engine` 加上 `/utf-8`，避免 MSVC 在中文代码页下的 C4819 报错。

Android Release 的 `applicationId` 已设为 `com.kugou.android`，便于部分车机按酷狗音乐识别媒体应用；若手机已安装官方酷狗音乐，会因包名相同发生安装/数据冲突，测试前请先确认。

## 插件

1. 打开「我的 → 插件管理」。
2. 从 URL 安装（支持单插件或订阅 JSON），或选择本地 `.js` 文件。
3. 启用插件后，「发现 / 搜索」会自动使用。

插件需导出 MusicFree 协议字段：`platform/version/author/srcUrl/supportedSearchType/primaryKey/userVariables`，以及按需的方法：

`search` `getMediaSource` `getLyric` `getAlbumInfo` `getMusicSheetInfo` `getTopLists` `getTopListDetail` `getArtistWorks` `getRecommendSheetTags` `getRecommendSheetsByTag` `importMusicSheet` `importMusicItem` `getMusicInfo` `getMusicComments`

## 目录

```
lib/
  core/
    models.dart            插件协议数据模型
    settings.dart          配置 / 路径 / i18n
    theme.dart             配色与 ThemeData
    plugin/                插件运行时与管理器
    player/                播放服务与本地媒体代理
    music_audio_handler.dart  Android 媒体通知/锁屏控制
    library_store.dart     歌单 / 历史
    media_cache.dart       歌词 / 本地路径 / 关联
    download_service.dart  下载队列
    local_library.dart     本地扫描
    backup_service.dart    WebDAV / 本地备份
  ui/
    shell.dart             四 Tab + 迷你播放器
    pages/                 发现 / 搜索 / 音乐库 / 我的 / 播放 / 详情 / 设置…
    widgets/               通用组件
assets/js/
  prelude.js               插件运行时前置（fetch / 定时器 / CommonJS）
  modules/                 第三方 JS 依赖
```

## 数据目录

- Windows：`%LOCALAPPDATA%\ShuangTingData`（若不可写则回退到程序目录 `userdata/`）
- Android：应用私有目录（`getApplicationSupportDirectory()`）

其中 `plugins/` 放插件，`downloads/` 放下载，`covers/` 放封面，`preferences.json` 存全部配置与歌单。

## 说明

本项目仅用于学习与研究：不内置任何音源，所有内容来自用户自行安装的第三方插件；请遵守当地法律与各平台服务条款。

## 主页与发布

- 静态主页源码在 `docs/`，推送到 GitHub 后开启 Pages（Source: `main` / `/docs`）即可访问 <https://leey1994.github.io/shuangting/>。
- 发布新版本：

```bash
flutter build apk --release --split-per-abi --split-debug-info=build/symbols/android --obfuscate
flutter build windows --release
gh release create v1.1.0 dist/android/app-arm64-v8a-release.apk   dist/android/app-armeabi-v7a-release.apk dist/android/app-x86_64-release.apk   --title "爽听 v1.1.0" --notes-file notes.md
```

App 的自动更新读取 `releases/latest`，因此发布时请把三个 APK 都作为 asset 上传，名称保留 `arm64` / `armeabi` / `x86_64` 字样以便自动选择。



仅供个人学习与研究使用。
