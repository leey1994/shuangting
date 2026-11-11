import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' hide Text;
import '../widgets/l10n_text.dart';

import '../../core/models.dart';
import '../../core/plugin/plugin_manager.dart';
import '../../core/settings.dart';
import '../../core/theme.dart';
import '../dialogs.dart';
import '../first_run_guide.dart';
import '../widgets/common.dart';

class PluginPage extends StatefulWidget {
  const PluginPage({super.key});

  @override
  State<PluginPage> createState() => _PluginPageState();
}

class _PluginPageState extends State<PluginPage> {
  bool _working = false;

  Future<void> _run(Future<void> Function() action, {String? title}) async {
    if (_working) return;
    setState(() => _working = true);
    if (mounted) {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => PopScope(
          canPop: true,
          child: Center(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(strokeWidth: 2.4),
                    if (title != null) ...[
                      const SizedBox(height: 14),
                      Text(title, style: const TextStyle(fontSize: 12)),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    String? error;
    try {
      await action();
    } catch (e) {
      error = '$e';
    }
    if (mounted) {
      Navigator.of(context, rootNavigator: true).maybePop();
      if (error != null) showToast(context, error);
      setState(() => _working = false);
    }
  }

  Future<void> _installFromUrl() async {
    final url = await promptText(context, title: '从网络安装插件', hint: '插件 .js / .json / 订阅链接');
    if (url == null || url.trim().isEmpty) return;
    await _run(
      () async {
        final installed = await PluginManager.instance.installFromUrl(url.trim());
        if (mounted) showToast(context, '已安装 ${installed.length} 个插件');
      },
      title: '正在安装插件',
    );
  }

  Future<void> _installFromFile() async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['js', 'json'],
      );
      if (file == null) return;
      final text = file.path != null ? await File(file.path!).readAsString() : utf8.decode(await file.readAsBytes());
      await _run(
        () async {
          final installed = await PluginManager.instance.installPayload(text);
          if (mounted) showToast(context, '已安装 ${installed.length} 个插件');
        },
        title: '正在安装插件',
      );
    } catch (e) {
      if (mounted) showToast(context, '$e');
    }
  }

  Future<void> _subscribe() async {
    final url = await promptText(
      context,
      title: '订阅链接',
      hint: 'plugins.json 订阅地址',
      initial: Settings.instance.get<String>('subscribeUrl'),
    );
    if (url == null || url.trim().isEmpty) return;
    await Settings.instance.set('subscribeUrl', url.trim());
    await _run(
      () async {
        final installed = await PluginManager.instance.installFromUrl(url.trim());
        if (mounted) showToast(context, '订阅完成，安装 ${installed.length} 个插件');
      },
      title: '正在同步订阅',
    );
  }

  Future<void> _editVariables(PluginRecord record) async {
    final runtime = await PluginManager.instance.runtimeFor(record);
    final vars = runtime?.metadata.userVariables ?? const <UserVariable>[];
    if (vars.isEmpty) {
      showToast(context, '该插件没有自定义变量');
      return;
    }
    final controllers = {
      for (final v in vars) v.key: TextEditingController(text: record.variables[v.key] ?? ''),
    };
    if (!mounted) return;
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${record.platform} 变量'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final v in vars)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextField(
                      controller: controllers[v.key],
                      decoration: InputDecoration(
                        labelText: v.name ?? v.key,
                        hintText: v.hint ?? v.key,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Tr('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Tr('保存')),
        ],
      ),
    );
    if (save == true) {
      await PluginManager.instance.setVariables(record, {
        for (final e in controllers.entries) e.key: e.value.text,
      });
      if (mounted) showToast(context, '变量已保存，插件已重载');
    }
    for (final c in controllers.values) {
      c.dispose();
    }
  }

  Future<void> _update(PluginRecord record) async {
    await _run(
      () async {
        await PluginManager.instance.updatePlugin(record);
        if (mounted) showToast(context, '已更新到 ${record.displayVersion}');
      },
      title: '正在更新',
    );
  }

  Future<void> _uninstall(PluginRecord record) async {
    final ok = await confirmDialog(
      context,
      t('删除插件'),
      content: t('删除后此音源将从搜索和榜单中移除。'),
      okLabel: '删除',
    );
    if (!ok) return;
    await _run(
      () => PluginManager.instance.uninstall(record),
      title: '正在删除插件',
    );
  }

  Future<void> _showDetail(PluginRecord record) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.extension_rounded),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(record.platform, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        Text('v${record.displayVersion}${record.author.isEmpty ? '' : ' · ${record.author}'}', style: TextStyle(fontSize: 11, color: AppPalette.muted(context))),
                      ],
                    ),
                  ),
                ],
              ),
              if (record.description.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(record.description, style: const TextStyle(fontSize: 12, height: 1.6)),
              ],
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final m in record.methods.toList()..sort())
                    Chip(label: Text(m, style: const TextStyle(fontSize: 10)), visualDensity: VisualDensity.compact),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  if (record.srcUrl.isNotEmpty)
                    Expanded(
                      child: FilledButton.tonal(
                        onPressed: () {
                          Navigator.pop(context);
                          _update(record);
                        },
                        child: const Tr('检查更新'),
                      ),
                    ),
                  if (record.srcUrl.isNotEmpty) const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: () {
                        Navigator.pop(context);
                        _editVariables(record);
                      },
                      child: const Tr('变量设置'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent),
                  onPressed: () {
                    Navigator.pop(context);
                    _uninstall(record);
                  },
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Tr('删除插件'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: PluginManager.instance,
      builder: (context, _) {
        final records = PluginManager.instance.records;
        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: Text('${t('插件')} · ${records.length}'),
            actions: [
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'url') _installFromUrl();
                  if (value == 'file') _installFromFile();
                  if (value == 'sub') _subscribe();
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'url', child: Tr('从网络安装')),
                  PopupMenuItem(value: 'file', child: Tr('从文件安装')),
                  PopupMenuItem(value: 'sub', child: Tr('订阅链接')),
                ],
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          body: records.isEmpty
              ? Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.auto_awesome_rounded, color: Theme.of(context).colorScheme.primary),
                                  const SizedBox(width: 10),
                                  const Expanded(child: Text('推荐音源订阅站', style: TextStyle(fontWeight: FontWeight.w700))),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'https://hebijunge.github.io/musicfree-plugins/\n首次使用建议订阅「常用六平台」，也可打开订阅站选择其它分类。',
                                style: TextStyle(fontSize: 11.5, height: 1.5, color: AppPalette.muted(context)),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () => FirstRunGuide.openSite(context),
                                      child: const Text('打开订阅站'),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: FilledButton(
                                      onPressed: () => FirstRunGuide.subscribeRecommended(context),
                                      child: const Text('订阅常用六平台'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const Expanded(
                      child: EmptyView(
                        icon: Icons.extension_rounded,
                        text: '还没有插件\n爽听不内置音源，安装 MusicFree 插件后就能搜索和播放',
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 30),
                      child: Row(
                        children: [
                          Expanded(child: FilledButton.icon(onPressed: _installFromUrl, icon: const Icon(Icons.link_rounded), label: const Tr('从网络安装'))),
                          const SizedBox(width: 10),
                          Expanded(child: OutlinedButton.icon(onPressed: _installFromFile, icon: const Icon(Icons.file_open_outlined), label: const Text('本地文件'))),
                        ],
                      ),
                    ),
                  ],
                )
              : RefreshIndicator(
                  onRefresh: () => PluginManager.instance.load(),
                  child: ReorderableListView.builder(
                    padding: const EdgeInsets.only(top: 6, bottom: 40),
                    itemCount: records.length,
                    onReorder: PluginManager.instance.reorder,
                    itemBuilder: (context, i) {
                      final record = records[i];
                      return Padding(
                        key: ValueKey(record.file + record.platform),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: ListTile(
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: (record.enabled
                                      ? Theme.of(context).colorScheme.primary
                                      : AppPalette.muted(context))
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: Icon(
                              Icons.extension_rounded,
                              color: record.enabled ? Theme.of(context).colorScheme.primary : AppPalette.muted(context),
                              size: 22,
                            ),
                          ),
                          title: Text(record.platform, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(
                            'v${record.displayVersion}${record.author.isEmpty ? '' : ' · ${record.author}'}',
                            style: TextStyle(fontSize: 11, color: AppPalette.muted(context)),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Switch(
                                value: record.enabled,
                                onChanged: (v) => PluginManager.instance.setEnabled(record, v),
                              ),
                              IconButton(
                                onPressed: () => _showDetail(record),
                                icon: const Icon(Icons.more_horiz_rounded, size: 20),
                              ),
                            ],
                          ),
                          onTap: () => _showDetail(record),
                        ),
                      );
                    },
                  ),
                ),
        );
      },
    );
  }
}
