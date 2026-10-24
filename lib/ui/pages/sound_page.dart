import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../data/store.dart';
import '../../player/player_controller.dart';

class SoundPage extends StatefulWidget {
  const SoundPage({super.key});

  @override
  State<SoundPage> createState() => _SoundPageState();
}

class _SoundPageState extends State<SoundPage> {
  static const presets = <String, List<double>>{
    '默认': [0, 0, 0, 0, 0],
    '流行': [2, 1, 0, 1, 2],
    '摇滚': [3, 2, -1, 2, 3],
    '低音': [5, 4, 1, 0, 0],
    '人声': [-1, 0, 2, 3, 1],
    '电子': [4, 2, -1, 2, 4],
  };

  AndroidEqualizerParameters? _params;
  bool _loading = true;
  bool _unsupported = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final player = context.read<PlayerController>();
    final eq = player.equalizer;
    if (eq == null) {
      setState(() {
        _loading = false;
        _unsupported = true;
      });
      return;
    }
    try {
      final params = await eq.parameters.timeout(const Duration(seconds: 2));
      if (!mounted) return;
      setState(() {
        _params = params;
        _loading = false;
      });
      await eq.setEnabled(context.read<SettingsModel>().eqEnabled);
      _applyPreset(context.read<SettingsModel>().eqPreset, save: false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _unsupported = true;
      });
    }
  }

  Future<void> _applyPreset(String name, {bool save = true}) async {
    final settings = context.read<SettingsModel>();
    final eq = context.read<PlayerController>().equalizer;
    final gains = presets[name] ?? presets['默认']!;
    if (save) {
      settings.eqPreset = name;
      settings.eqEnabled = true;
    }
    if (eq == null) return;
    await eq.setEnabled(true);
    final params = _params;
    if (params == null) return;
    for (var i = 0; i < params.bands.length; i++) {
      final gain = gains[i % gains.length];
      await params.bands[i].setGain(gain.clamp(params.minDecibels, params.maxDecibels));
    }
    if (mounted) setState(() {});
  }

  Future<void> _setBand(int index, double value) async {
    final params = _params;
    if (params == null) return;
    await params.bands[index].setGain(value);
    context.read<SettingsModel>().eqPreset = '自定义';
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsModel>();
    final player = context.read<PlayerController>();
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = AppTheme.coverGradient(3, isDark: isDark);
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [colors.first.withValues(alpha: 0.16), scheme.surface],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const SizedBox(width: 4),
                  const Text('音效实验室',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: scheme.surface.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: scheme.outline.withValues(alpha: 0.22)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.graphic_eq_rounded, color: scheme.primary),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text('十段均衡器',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                        ),
                        Switch(
                          value: settings.eqEnabled,
                          onChanged: (v) async {
                            settings.eqEnabled = v;
                            await player.equalizer?.setEnabled(v);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _unsupported
                          ? '当前平台暂不支持系统级均衡器，播放速度与音质设置仍然可用。'
                          : '预设音效会立即作用于正在播放的歌曲。',
                      style: TextStyle(
                          fontSize: 11.5,
                          height: 1.5,
                          color: scheme.onSurface.withValues(alpha: 0.45)),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final name in presets.keys)
                          ChoiceChip(
                            label: Text(name),
                            selected: settings.eqPreset == name,
                            showCheckmark: false,
                            selectedColor: scheme.primary,
                            labelStyle: TextStyle(
                              color: settings.eqPreset == name
                                  ? scheme.onPrimary
                                  : scheme.onSurface.withValues(alpha: 0.65),
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                            onSelected: (_) => _applyPreset(name),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (_loading)
                      const SizedBox(
                        height: 160,
                        child: Center(
                          child: SizedBox(
                              width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
                        ),
                      )
                    else if (_params != null)
                      SizedBox(
                        height: 220,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            for (var i = 0; i < _params!.bands.length; i++)
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Text('${_params!.bands[i].gain.toStringAsFixed(0)}',
                                        style: TextStyle(
                                            fontSize: 9,
                                            color: scheme.onSurface.withValues(alpha: 0.4))),
                                    SizedBox(
                                      height: 150,
                                      child: RotatedBox(
                                        quarterTurns: 3,
                                        child: Slider(
                                          value: _params!.bands[i].gain.clamp(
                                              _params!.minDecibels, _params!.maxDecibels),
                                          min: _params!.minDecibels,
                                          max: _params!.maxDecibels,
                                          onChanged: (v) => _setBand(i, v),
                                        ),
                                      ),
                                    ),
                                    Text(
                                      _params!.bands[i].centerFrequency >= 1000
                                          ? '${(_params!.bands[i].centerFrequency / 1000).toStringAsFixed(0)}k'
                                          : _params!.bands[i].centerFrequency.toStringAsFixed(0),
                                      style: TextStyle(
                                          fontSize: 8.5,
                                          color: scheme.onSurface.withValues(alpha: 0.35)),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline_rounded,
                                size: 18, color: scheme.onSurface.withValues(alpha: 0.4)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text('播放一首歌后，均衡器频段会自动加载。',
                                  style: TextStyle(
                                      fontSize: 11.5,
                                      color: scheme.onSurface.withValues(alpha: 0.5))),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: scheme.surface.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: scheme.outline.withValues(alpha: 0.22)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('播放速度',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final s in [0.75, 1.0, 1.25, 1.5, 2.0])
                          ChoiceChip(
                            label: Text('${s}x'),
                            selected: settings.speed == s,
                            showCheckmark: false,
                            selectedColor: scheme.primary,
                            labelStyle: TextStyle(
                              color: settings.speed == s
                                  ? scheme.onPrimary
                                  : scheme.onSurface.withValues(alpha: 0.65),
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                            onSelected: (_) async {
                              settings.speed = s;
                              await player.audio.setSpeed(s);
                            },
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: scheme.surface.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: scheme.outline.withValues(alpha: 0.22)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('音质偏好',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text('优先请求更高音质，遇到版权限制会自动降级。',
                        style: TextStyle(
                            fontSize: 11,
                            color: scheme.onSurface.withValues(alpha: 0.45))),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final q in const [
                          ('128', '标准'),
                          ('320', '高质'),
                          ('flac', '无损'),
                          ('hires', 'Hi-Res'),
                        ])
                          ChoiceChip(
                            label: Text(q.$2),
                            selected: settings.quality == q.$1,
                            showCheckmark: false,
                            selectedColor: scheme.primary,
                            labelStyle: TextStyle(
                              color: settings.quality == q.$1
                                  ? scheme.onPrimary
                                  : scheme.onSurface.withValues(alpha: 0.65),
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                            onSelected: (_) => settings.quality = q.$1,
                          ),
                      ],
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
