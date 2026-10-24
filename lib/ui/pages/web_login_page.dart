import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../data/kg_api.dart';
import '../../data/store.dart';

/// 网页登录：App 内 WebView 打开酷狗统一登录页（扫码/验证码/密码由酷狗官方维护），
/// 登录成功后服务端把 token/userid 种进 .kugou.com 域 Cookie，
/// 轮询 WebView CookieManager 命中即自动绑定，无需手工复制。
class WebLoginPage extends StatefulWidget {
  const WebLoginPage({super.key});

  @override
  State<WebLoginPage> createState() => _WebLoginPageState();
}

class _WebLoginPageState extends State<WebLoginPage> {
  late final WebViewController _controller;
  Timer? _timer;
  bool _done = false;

  static const _loginUrl =
      'https://login-user.kugou.com/login?appid=3116&expire_day=30'
      '&redirect_uri=https%3A%2F%2Fwww.kugou.com';

  SettingsModel get _settings => context.read<SettingsModel>();
  KgApi get _api => context.read<KgApi>();

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
          'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Mobile Safari/537.36')
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) => _pollCookie(),
      ))
      ..loadRequest(Uri.parse(_loginUrl));
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _pollCookie());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _pollCookie() async {
    if (_done || !mounted) return;
    try {
      // 用 WebViewCookieManager 读整个 cookie store（含 HttpOnly 的 token cookie），
      // document.cookie 读不到 HttpOnly，这是第一版绑不上的原因。
      final cookies = await WebViewCookieManager()
          .getCookies(domain: Uri.parse('https://kugou.com'));
      final fields = <String, String>{
        for (final c in cookies) c.name: c.value,
      };
      final token = fields['token'] ?? fields['KuGoo'] ?? '';
      final userid = fields['userid'] ?? fields['KugooID'] ?? '';
      if (token.isEmpty || userid.isEmpty || userid == '0') return;
      _done = true;
      _timer?.cancel();
      final vipToken = fields['vip_token'] ?? '';
      final vipType = fields['vip_type'] ?? '0';
      final bound = [
        'token=$token',
        'userid=$userid',
        if (vipToken.isNotEmpty) 'vip_token=$vipToken',
        'vip_type=$vipType',
      ].join('; ');
      _settings.cookie = bound;
      _api.cookie = bound;
      final nickname = fields['nickname'] ?? '';
      if (nickname.isNotEmpty) _settings.nickname = nickname;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('登录成功，已自动绑定账号')));
      Navigator.of(context).pop(true);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('网页登录'),
        actions: [
          IconButton(
              onPressed: () => _controller.reload(),
              icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: scheme.surface.withValues(alpha: 0.6),
            child: Text(
              '在页面中使用酷狗官方提供的扫码 / 验证码 / 密码登录，成功后自动绑定，无需手工复制 Cookie。',
              style: TextStyle(
                  fontSize: 11.5,
                  color: scheme.onSurface.withValues(alpha: 0.55)),
            ),
          ),
          Expanded(child: WebViewWidget(controller: _controller)),
        ],
      ),
    );
  }
}
