import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/kg_api.dart';
import '../../data/store.dart';

/// 酷狗扫码登录：生成二维码 → 2s 轮询 → 成功后写入 Cookie。
/// Cookie 手工导入保留为高级选项。
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  Timer? _timer;
  int _gen = 0;
  KgQrSession? _session;
  String _status = '正在生成二维码…';
  int _kind = 0; // 0 生成中 1 等待扫码 2 已扫码 3 失效/出错 4 成功
  bool _pollBusy = false;
  final _cookieCtrl = TextEditingController();

  SettingsModel get _settings => context.read<SettingsModel>();
  KgApi get _api => context.read<KgApi>();

  @override
  void initState() {
    super.initState();
    _newSession();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cookieCtrl.dispose();
    super.dispose();
  }

  Future<void> _newSession() async {
    _gen++;
    final gen = _gen;
    _timer?.cancel();
    setState(() {
      _session = null;
      _status = '正在生成二维码…';
      _kind = 0;
    });
    try {
      final s = await _api.qrCreate();
      if (gen != _gen || !mounted) return;
      setState(() {
        _session = s;
        _status = '打开手机酷狗音乐 App 扫一扫';
        _kind = 1;
      });
      _timer = Timer.periodic(const Duration(seconds: 2), (_) => _poll(gen));
    } catch (e) {
      if (gen != _gen || !mounted) return;
      setState(() {
        _status = e is KgException ? e.message : '二维码生成失败，请刷新重试';
        _kind = 3;
      });
    }
  }

  Future<void> _poll(int gen) async {
    final s = _session;
    if (s == null || _pollBusy) return;
    _pollBusy = true;
    try {
      final r = await _api.qrCheck(s.key);
      if (gen != _gen || !mounted) return;
      if (r.status == 4) {
        _timer?.cancel();
        _settings.cookie = r.cookie;
        _api.cookie = r.cookie;
        if (r.nickname.isNotEmpty) _settings.nickname = r.nickname;
        setState(() {
          _status = '登录成功${r.nickname.isEmpty ? '' : ' · ${r.nickname}'}';
          _kind = 4;
        });
        await Future<void>.delayed(const Duration(milliseconds: 700));
        if (mounted) Navigator.of(context).pop(true);
        return;
      }
      setState(() {
        if (r.status == 2) {
          _status = '已扫码 · 请在手机上点「确认登录」';
          _kind = 2;
        } else if (r.status == 1) {
          _status = '等待扫码…';
          _kind = 1;
        } else {
          _timer?.cancel();
          _status = '二维码已失效，请点击刷新';
          _kind = 3;
        }
      });
    } catch (_) {
      if (gen != _gen || !mounted) return;
      setState(() {
        _status = '网络波动，正在重试…';
        _kind = 3;
      });
    } finally {
      _pollBusy = false;
    }
  }

  Future<void> _saveManual() async {
    final v = _cookieCtrl.text.trim();
    if (v.isEmpty) return;
    _settings.cookie = v;
    _api.cookie = v;
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Cookie 已保存')));
  }

  void _unbind() {
    _settings.cookie = '';
    _api.cookie = '';
    _cookieCtrl.clear();
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('已解除账号绑定')));
  }

  Color _dotColor(ColorScheme scheme) => switch (_kind) {
        1 => scheme.primary,
        2 => scheme.tertiary,
        4 => const Color(0xFF35D6A4),
        3 => scheme.error,
        _ => scheme.onSurface.withValues(alpha: 0.4),
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final settings = context.watch<SettingsModel>();
    final bound = settings.cookie.trim().isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text('登录酷狗账号')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Center(
          child: Column(
            children: [
              const SizedBox(height: 8),
              // 二维码卡片
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                      color: scheme.outline.withValues(alpha: 0.2)),
                ),
                child: SizedBox(
                  width: 208,
                  height: 208,
                  child: _session != null && _session!.image.isNotEmpty
                      ? Image.memory(_session!.image, fit: BoxFit.contain)
                      : _kind == 3
                          ? const Icon(Icons.qr_code_rounded,
                              size: 64, color: Color(0xFF666666))
                          : const Center(
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.4)),
                ),
              ),
              const SizedBox(height: 18),
              // 状态条
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: scheme.surface.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(999),
                  border:
                      Border.all(color: scheme.outline.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                          color: _dotColor(scheme), shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 9),
                    Text(_status,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton.icon(
                    onPressed: _kind == 0 ? null : _newSession,
                    icon: const Icon(Icons.refresh_rounded, size: 19),
                    label: const Text('刷新二维码'),
                  ),
                  const SizedBox(width: 4),
                  Text('无需手工复制 Cookie',
                      style: TextStyle(
                          fontSize: 11.5,
                          color: scheme.onSurface.withValues(alpha: 0.45))),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Text(
                  '已扫码后还需要在手机上点击「确认登录」，登录状态会同步用于签到与 VIP 音源。',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 11.5,
                      height: 1.5,
                      color: scheme.onSurface.withValues(alpha: 0.5)),
                ),
              ),
              const SizedBox(height: 8),
              Theme(
                data: Theme.of(context)
                    .copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 8),
                  childrenPadding:
                      const EdgeInsets.fromLTRB(8, 0, 8, 12),
                  title: const Text('高级 · 手工导入 Cookie',
                      style: TextStyle(fontSize: 13)),
                  subtitle: Text(bound ? '当前已绑定' : '当前未绑定',
                      style: const TextStyle(fontSize: 11)),
                  children: [
                    TextField(
                      controller: _cookieCtrl,
                      maxLines: 4,
                      decoration: const InputDecoration(
                          hintText: 'token=...; userid=...;'),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        FilledButton.tonal(
                            onPressed: _saveManual,
                            child: const Text('保存 Cookie')),
                        const SizedBox(width: 10),
                        if (bound)
                          OutlinedButton(
                              onPressed: _unbind,
                              child: const Text('解除绑定')),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
