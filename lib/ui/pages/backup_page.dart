import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' hide Text;
import '../widgets/l10n_text.dart';

import '../../core/backup_service.dart';
import '../../core/library_store.dart';
import '../../core/settings.dart';
import '../../core/theme.dart';
import '../dialogs.dart';
import '../widgets/common.dart';

class BackupPage extends StatefulWidget {
  const BackupPage({super.key});

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  late final TextEditingController _url;
  late final TextEditingController _user;
  late final TextEditingController _pass;
  bool _busy = false;
  String? _lastBackup;

  @override
  void initState() {
    super.initState();
    final s = Settings.instance;
    _url = TextEditingController(text: s.get<String>('webdavUrl'));
    _user = TextEditingController(text: s.get<String>('webdavUsername'));
    _pass = TextEditingController(text: s.get<String>('webdavPassword'));
    _lastBackup = PrefStore.instance.getString('lastBackupAt');
  }

  @override
  void dispose() {
    _url.dispose();
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _saveWebdav() async {
    await Settings.instance.setMany({
      'webdavUrl': _url.text.trim(),
      'webdavUsername': _user.text.trim(),
      'webdavPassword': _pass.text,
    });
  }

  Future<void> _run(Future<void> Function() action, String label, {String? success}) async {
    if (_busy) return;
    setState(() => _busy = true);
    await _saveWebdav();
    if (mounted) {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => Center(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(strokeWidth: 2.4),
                  const SizedBox(height: 14),
                  Text(label, style: const TextStyle(fontSize: 12)),
                ],
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
      Navigator.of(context, rootNavigator: true).pop();
      if (error != null) {
        showToast(context, error);
      } else if (success != null) {
        showToast(context, success);
      }
      setState(() => _busy = false);
    }
  }

  Future<void> _upload() async {
    await _run(() async {
      await BackupService.instance.uploadToWebdav();
      final now = DateTime.now().toString().substring(0, 19);
      await PrefStore.instance.setString('lastBackupAt', now);
      if (mounted) setState(() => _lastBackup = now);
    }, '正在备份到 WebDAV', success: '备份完成');
  }

  Future<void> _download() async {
    if (!await confirmDialog(context, '从 WebDAV 恢复备份？', content: '当前歌单、设置与插件将被备份内容覆盖。')) return;
    await _run(() async {
      await BackupService.instance.downloadFromWebdav();
    }, '正在从 WebDAV 恢复', success: '恢复完成，建议重启应用');
  }

  Future<void> _exportLocal() async {
    await _run(() async {
      final data = await BackupService.instance.buildBackup();
      final bytes = Uint8List.fromList(utf8.encode(BackupService.instance.encodeBackup(data)));
      await FilePicker.saveFile(
        dialogTitle: '导出备份',
        fileName: BackupService.fileName,
        bytes: bytes,
      );
    }, '正在导出', success: '已导出备份');
  }

  Future<void> _importLocal() async {
    try {
      final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['json']);
      if (file == null) return;
      if (!await confirmDialog(context, '导入本地备份？', content: '当前数据将被覆盖。')) return;
      await _run(() async {
        if (file.path != null) {
          await BackupService.instance.importFromPath(file.path!);
        }
      }, '正在导入', success: '导入完成');
    } catch (e) {
      if (mounted) showToast(context, '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('备份与恢复')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          const SectionTitle('WebDAV'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                TextField(
                  controller: _url,
                  decoration: const InputDecoration(labelText: '服务器地址', hintText: 'https://dav.example.com/remote.php/dav/files/user/'),
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _user,
                  decoration: const InputDecoration(labelText: '用户名'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _pass,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: '密码 / 应用密码'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () async {
                            await _saveWebdav();
                            final ok = await BackupService.instance.testConnection();
                            if (mounted) showToast(context, ok ? '连接成功' : '连接失败，请检查地址与账号');
                          },
                    child: const Tr('测试连接'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: _busy ? null : _upload,
                    child: const Tr('备份到 WebDAV'),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(onPressed: _busy ? null : _download, child: const Tr('从 WebDAV 恢复')),
            ),
          ),
          if (_lastBackup != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Text('上次备份：$_lastBackup', style: TextStyle(fontSize: 11, color: AppPalette.muted(context))),
            ),
          const SectionTitle('本地备份'),
          ListTile(
            leading: const Icon(Icons.upload_file_rounded),
            title: const Tr('导出本地备份'),
            subtitle: Text('设置、歌单、历史、歌词关联、插件', style: TextStyle(fontSize: 11, color: AppPalette.muted(context))),
            onTap: _busy ? null : _exportLocal,
          ),
          ListTile(
            leading: const Icon(Icons.file_download_outlined),
            title: const Tr('导入本地备份'),
            onTap: _busy ? null : _importLocal,
          ),
          const SectionTitle('数据'),
          ListTile(
            leading: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent),
            title: const Text('清空播放历史', style: TextStyle(color: Colors.redAccent)),
            onTap: () async {
              if (await confirmDialog(context, '清空播放历史？')) {
                await LibraryStore.instance.clearHistory();
              }
            },
          ),
        ],
      ),
    );
  }
}
