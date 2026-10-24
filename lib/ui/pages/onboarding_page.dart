import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../data/store.dart';
import '../widgets/common.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _page = PageController();
  int _index = 0;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  void _finish() {
    context.read<SettingsModel>().onboarded = true;
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('ONBOARD BUILD');
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF0A0C12), const Color(0xFF131828), const Color(0xFF0A0C12)]
                : [const Color(0xFFF6F1E9), const Color(0xFFFFE9E4), const Color(0xFFF6F1E9)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 16, 0),
                child: Row(
                  children: [
                    const BrandMark(size: 19),
                    const Spacer(),
                    if (_index < 2)
                      TextButton(
                        onPressed: _finish,
                        child: Text('跳过',
                            style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.45))),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _page,
                  onPageChanged: (i) => setState(() => _index = i),
                  children: [
                    _IntroSlide(index: _index),
                    const _FeatureSlide(),
                    _PreferenceSlide(onFinish: _finish),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Row(
                  children: [
                    for (var i = 0; i < 3; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 240),
                        margin: const EdgeInsets.only(right: 6),
                        width: i == _index ? 26 : 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: i == _index
                              ? scheme.primary
                              : scheme.onSurface.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(100),
                        ),
                      ),
                    const Spacer(),
                    if (_index < 2)
                      FilledButton.icon(
                        onPressed: () => _page.nextPage(
                            duration: const Duration(milliseconds: 360),
                            curve: Curves.easeOutCubic),
                        icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                        label: const Text('继续'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                        ),
                      )
                    else
                      FilledButton.icon(
                        onPressed: _finish,
                        icon: const Icon(Icons.music_note_rounded, size: 18),
                        label: const Text('开始听歌'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IntroSlide extends StatelessWidget {
  final int index;
  const _IntroSlide({required this.index});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 250,
            height: 250,
            child: Stack(
              alignment: Alignment.center,
              children: [
                for (var i = 3; i > 0; i--)
                  Container(
                    width: 140.0 + i * 34,
                    height: 140.0 + i * 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: scheme.primary.withValues(alpha: 0.08 + i * 0.03), width: 1),
                    ),
                  ),
                Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [scheme.primary, AppTheme.mint],
                    ),
                    boxShadow: [
                      BoxShadow(
                          color: scheme.primary.withValues(alpha: 0.35),
                          blurRadius: 50,
                          offset: const Offset(0, 20)),
                    ],
                  ),
                  child: const Icon(Icons.graphic_eq_rounded, size: 66, color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(height: 42),
          Text('听见，更自由',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.5,
                    height: 1.1,
                  )),
          const SizedBox(height: 14),
          Text(
            '爽听把搜索、推荐、收藏与播放重新编排，\n让每一次打开都像翻开一张新唱片。',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 13.5, height: 1.7, color: scheme.onSurface.withValues(alpha: 0.5)),
          ),
        ],
      ),
    );
  }
}

class _FeatureSlide extends StatelessWidget {
  const _FeatureSlide();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final features = [
      (Icons.offline_bolt_rounded, '离线缓存', '听过的歌自动留在本地，地铁与飞机上也能继续。', const Color(0xFF7B5CFF)),
      (Icons.lyrics_rounded, '逐字歌词', 'KRC 逐字时间轴，跟唱时每一句都亮起来。', AppTheme.mint),
      (Icons.directions_car_rounded, '横屏车机', '大按钮、强对比，横屏自动进入车机界面。', const Color(0xFFFFA62B)),
      (Icons.auto_awesome_rounded, '每日推荐', '实时榜单与场景歌单，今天的好音乐不用找。', const Color(0xFFFF4D6D)),
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          Text('为每一种听歌场景\n重新设计',
              style: Theme.of(context)
                  .textTheme
                  .headlineLarge
                  ?.copyWith(fontWeight: FontWeight.w900, height: 1.16, letterSpacing: -1)),
          const SizedBox(height: 12),
          Text('不是换皮，而是把体验重新做了一遍。',
              style: TextStyle(fontSize: 12.5, color: scheme.onSurface.withValues(alpha: 0.45))),
          const SizedBox(height: 28),
          for (final f in features) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scheme.surface.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: scheme.outline.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: f.$4.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(f.$1, color: f.$4, size: 23),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(f.$2,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 3),
                        Text(f.$3,
                            style: TextStyle(
                                fontSize: 11.5,
                                height: 1.45,
                                color: scheme.onSurface.withValues(alpha: 0.45))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _PreferenceSlide extends StatelessWidget {
  final VoidCallback onFinish;
  const _PreferenceSlide({required this.onFinish});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsModel>();
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 30, 28, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('把爽听调成\n你的样子',
              style: Theme.of(context)
                  .textTheme
                  .headlineLarge
                  ?.copyWith(fontWeight: FontWeight.w900, height: 1.16, letterSpacing: -1)),
          const SizedBox(height: 24),
          const Text('主题色', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              for (final entry in accentChoices.entries)
                GestureDetector(
                  onTap: () => settings.accent = entry.key,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: entry.value,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: settings.accent == entry.key
                            ? scheme.onSurface
                            : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                    child: settings.accent == entry.key
                        ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
                        : null,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 28),
          const Text('外观', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final m in const [
                ('dark', '深色'),
                ('light', '浅色'),
                ('system', '跟随系统'),
                ('black', '纯黑'),
              ])
                ChoiceChip(
                  label: Text(m.$2),
                  selected: settings.themeMode == m.$1,
                  showCheckmark: false,
                  selectedColor: scheme.primary,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: settings.themeMode == m.$1
                        ? scheme.onPrimary
                        : scheme.onSurface.withValues(alpha: 0.6),
                  ),
                  onSelected: (_) => settings.themeMode = m.$1,
                ),
            ],
          ),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.surface.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: scheme.outline.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.verified_rounded, color: scheme.primary, size: 20),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('启动后自动完成每日签到，连续签到天数会记录在「我的」页面。',
                      style: TextStyle(fontSize: 11.5, height: 1.5)),
                ),
                Switch(
                  value: settings.autoSignIn,
                  onChanged: (v) => settings.autoSignIn = v,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
