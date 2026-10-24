import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/kg_api.dart';
import '../../data/store.dart';
import 'web_login_page.dart';

/// 酷狗登录：网页登录（推荐，官方页全方式）/ 扫码 / 手机验证码 / 账号密码。
/// 验证码与密码链路按参考项目协议实现；上游 2026 年起对第三方客户端启用
/// SSA 反爬（错误码 20006），失败时给出明确引导文案。
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 4, vsync: this);
  Timer? _timer;
  int _gen = 0;
  KgQrSession? _session;
  String _status = '正在生成二维码…';
  int _kind = 0; // 0 生成中 1 等待扫码 2 已扫码 3 失效/出错 4 成功
  bool _pollBusy = false;
  final _cookieCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _accountCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();
  bool _smsBusy = false;
  bool _pwdBusy = false;
  int _resendIn = 0;
  Timer? _resendTimer;

  SettingsModel get _settings => context.read<SettingsModel>();
  KgApi get _api => context.read<KgApi>();

  @override
  void initState() {
    super.initState();
    _tab.addListener(() {
      if (_tab.indexIsChanging) return;
      // 离开扫码页时暂停轮询，省流量
      if (_tab.index != 1) _timer?.cancel();
    });
    _newSession();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _resendTimer?.cancel();
    _tab.dispose();
    _cookieCtrl.dispose();
    _mobileCtrl.dispose();
    _codeCtrl.dispose();
    _accountCtrl.dispose();
    _pwdCtrl.dispose();
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
        await _applyLogin(r.cookie, r.nickname);
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

  Future<void> _applyLogin(String cookie, String nickname) async {
    _settings.cookie = cookie;
    _api.cookie = cookie;
    if (nickname.isNotEmpty) _settings.nickname = nickname;
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _sendSms() async {
    if (_smsBusy) return;
    FocusScope.of(context).unfocus();
    setState(() => _smsBusy = true);
    try {
      await _api.sendSmsCode(_mobileCtrl.text);
      _toast('验证码已发送');
      setState(() => _resendIn = 60);
      _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return t.cancel();
        setState(() => _resendIn--);
        if (_resendIn <= 0) t.cancel();
      });
    } on KgException catch (e) {
      _toast(KgApi.isUpstreamRejected(e)
          ? '${e.message}（上游风控拦截，可改用扫码登录）'
          : e.message);
    } finally {
      if (mounted) setState(() => _smsBusy = false);
    }
  }

  Future<void> _smsLogin() async {
    if (_smsBusy) return;
    FocusScope.of(context).unfocus();
    setState(() => _smsBusy = true);
    try {
      final r = await _api.smsLogin(_mobileCtrl.text, _codeCtrl.text);
      await _applyLogin(r.cookie, r.nickname);
      _toast('登录成功${r.nickname.isEmpty ? '' : ' · ${r.nickname}'}');
      if (mounted) Navigator.of(context).pop(true);
    } on KgException catch (e) {
      _toast(KgApi.isUpstreamRejected(e)
          ? '${e.message}（上游风控拦截，可改用扫码登录）'
          : e.message);
    } finally {
      if (mounted) setState(() => _smsBusy = false);
    }
  }

  Future<void> _pwdLogin() async {
    if (_pwdBusy) return;
    FocusScope.of(context).unfocus();
    setState(() => _pwdBusy = true);
    try {
      final r = await _api.passwordLogin(_accountCtrl.text, _pwdCtrl.text);
      await _applyLogin(r.cookie, r.nickname);
      _toast('登录成功${r.nickname.isEmpty ? '' : ' · ${r.nickname}'}');
      if (mounted) Navigator.of(context).pop(true);
    } on KgException catch (e) {
      _toast(KgApi.isUpstreamRejected(e)
          ? '${e.message}（上游风控拦截，可改用扫码登录）'
          : e.message);
    } finally {
      if (mounted) setState(() => _pwdBusy = false);
    }
  }

  Future<void> _saveManual() async {
    final v = _cookieCtrl.text.trim();
    if (v.isEmpty) return;
    _settings.cookie = v;
    _api.cookie = v;
    _toast('Cookie 已保存');
  }

  void _unbind() {
    _settings.cookie = '';
    _api.cookie = '';
    _cookieCtrl.clear();
    _toast('已解除账号绑定');
  }

  Future<void> _openWebLogin() async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const WebLoginPage()),
    );
    if (ok == true && mounted) Navigator.of(context).pop(true);
  }

  Color _dotColor(ColorScheme scheme) => switch (_kind) {
        1 => scheme.primary,
        2 => scheme.tertiary,
        4 => const Color(0xFF35D6A4),
        3 => scheme.error,
        _ => scheme.onSurface.withValues(alpha: 0.4),
      };

  Widget _qrTab(ColorScheme scheme, bool bound) {
    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: scheme.outline.withValues(alpha: 0.2)),
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
                        child:
                            CircularProgressIndicator(strokeWidth: 2.4)),
          ),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: scheme.outline.withValues(alpha: 0.2)),
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
        Padding(
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
        _manualCookieSection(scheme, bound),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _manualCookieSection(ColorScheme scheme, bool bound) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: _openWebLogin,
          style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48)),
          icon: const Icon(Icons.language_rounded),
          label: const Text('网页登录（推荐 · 官方页自动绑定）'),
        ),
        const SizedBox(height: 6),
        Text(
          bound ? '当前已绑定账号' : '登录成功后自动获取并保存 Cookie，无需手工绑定',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 11,
              color: scheme.onSurface.withValues(alpha: 0.45)),
        ),
        const SizedBox(height: 8),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 8),
            childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
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
                      onPressed: _saveManual, child: const Text('保存 Cookie')),
                  const SizedBox(width: 10),
                  if (bound)
                    OutlinedButton(
                        onPressed: _unbind, child: const Text('解除绑定')),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _webTab(ColorScheme scheme) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 24),
      children: [
        Icon(Icons.language_rounded, size: 56, color: scheme.primary),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _openWebLogin,
          style:
              FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          child: const Text('打开酷狗官方登录页'),
        ),
        const SizedBox(height: 16),
        Text(
          '内置浏览器打开酷狗官方统一登录页，官方提供扫码、手机验证码、账号密码等全部登录方式。\n\n'
          '登录成功后「爽听」会自动获取并保存绑定 Cookie，无需任何手工复制。该方式由酷狗官方页面直接处理，成功率最高。',
          style: TextStyle(
              fontSize: 12.5,
              height: 1.7,
              color: scheme.onSurface.withValues(alpha: 0.65)),
        ),
        const SizedBox(height: 16),
        _manualCookieSection(scheme, false),
      ],
    );
  }

  Widget _smsTab(ColorScheme scheme) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 24),
      children: [
        TextField(
          controller: _mobileCtrl,
          keyboardType: TextInputType.phone,
          maxLength: 11,
          decoration: const InputDecoration(
            labelText: '手机号',
            prefixText: '+86 ',
            counterText: '',
          ),
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _codeCtrl,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                    labelText: '验证码', counterText: ''),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.tonal(
              onPressed: (_smsBusy || _resendIn > 0) ? null : _sendSms,
              child: Text(_resendIn > 0 ? '重发($_resendIn s)' : '发送验证码'),
            ),
          ],
        ),
        const SizedBox(height: 22),
        FilledButton(
          onPressed: _smsBusy ? null : _smsLogin,
          style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48)),
          child: _smsBusy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('登录'),
        ),
        const SizedBox(height: 14),
        Text(
          '推荐使用「扫码登录」；验证码登录走酷狗手机端协议，若上游风控拦截（20006）请改用扫码。',
          style: TextStyle(
              fontSize: 11.5,
              height: 1.5,
              color: scheme.onSurface.withValues(alpha: 0.5)),
        ),
      ],
    );
  }

  Widget _pwdTab(ColorScheme scheme) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 24),
      children: [
        TextField(
          controller: _accountCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: '手机号 / 邮箱'),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _pwdCtrl,
          obscureText: true,
          decoration: const InputDecoration(labelText: '密码'),
        ),
        const SizedBox(height: 22),
        FilledButton(
          onPressed: _pwdBusy ? null : _pwdLogin,
          style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48)),
          child: _pwdBusy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('登录'),
        ),
        const SizedBox(height: 14),
        Text(
          '推荐使用「扫码登录」；密码登录走酷狗手机端协议，若上游风控拦截（20006）请改用扫码。',
          style: TextStyle(
              fontSize: 11.5,
              height: 1.5,
              color: scheme.onSurface.withValues(alpha: 0.5)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final settings = context.watch<SettingsModel>();
    final bound = settings.cookie.trim().isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        title: const Text('登录酷狗账号'),
        bottom: TabBar(
          controller: _tab,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: '网页登录'),
            Tab(text: '扫码'),
            Tab(text: '验证码'),
            Tab(text: '密码'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _webTab(scheme),
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Center(
                child: _qrTab(scheme, bound)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _smsTab(scheme),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _pwdTab(scheme),
          ),
        ],
      ),
    );
  }
}
