import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' hide Text;
import '../widgets/l10n_text.dart';
import 'package:path/path.dart' as p;

import '../../core/settings.dart';
import '../../core/theme.dart';
import '../widgets/common.dart';

class ThemePage extends StatelessWidget {
  const ThemePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Settings.instance,
      builder: (context, _) {
        final s = Settings.instance;
        final mode = s.get<String>('themeMode');
        final seed = s.get<int>('themeSeed');
        final bg = s.get<String>('backgroundPath');
        final opacity = s.get<double>('backgroundOpacity');
        final blur = s.get<double>('backgroundBlur');
        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(title: const Tr('主题')),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 40),
            children: [
              const SectionTitle('外观模式'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'system', label: Tr('跟随系统'), icon: Icon(Icons.brightness_auto_rounded)),
                    ButtonSegment(value: 'light', label: Tr('浅色'), icon: Icon(Icons.light_mode_rounded)),
                    ButtonSegment(value: 'dark', label: Tr('深色'), icon: Icon(Icons.dark_mode_rounded)),
                  ],
                  selected: {mode},
                  onSelectionChanged: (v) async {
                    await s.set('themeMode', v.first);
                    ThemeController.instance.refresh();
                  },
                ),
              ),
              const SectionTitle('强调色'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: [
                    for (var i = 0; i < AppPalette.presets.length; i++)
                      GestureDetector(
                        onTap: () async {
                          await s.set('themeSeed', AppPalette.presets[i]);
                          ThemeController.instance.refresh();
                        },
                        child: Column(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: Color(AppPalette.presets[i]),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: seed == AppPalette.presets[i] ? Colors.white : Colors.transparent,
                                  width: 3,
                                ),
                                boxShadow: [
                                  if (seed == AppPalette.presets[i])
                                    BoxShadow(color: Color(AppPalette.presets[i]).withValues(alpha: 0.55), blurRadius: 16, spreadRadius: 2),
                                ],
                              ),
                              child: seed == AppPalette.presets[i]
                                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 22)
                                  : null,
                            ),
                            const SizedBox(height: 6),
                            Text(AppPalette.presetNames[i], style: const TextStyle(fontSize: 10)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SectionTitle('自定义背景'),
              ListTile(
                leading: const Icon(Icons.image_outlined),
                title: const Text('选择背景图片'),
                subtitle: Text(
                  bg.isEmpty ? '未设置' : p.basename(bg),
                  style: TextStyle(fontSize: 11, color: AppPalette.muted(context)),
                ),
                trailing: bg.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () async {
                          await s.set('backgroundPath', '');
                          ThemeController.instance.refresh();
                        },
                        icon: const Icon(Icons.close_rounded, size: 18),
                      ),
                onTap: () async {
                  final file = await FilePicker.pickFile(type: FileType.image);
                  if (file?.path == null) return;
                  final ext = p.extension(file!.path!);
                  final target = p.join(AppPaths.docs.path, 'background$ext');
                  await File(file.path!).copy(target);
                  await s.set('backgroundPath', target);
                  ThemeController.instance.refresh();
                },
              ),
              ListTile(
                title: const Text('背景透明度'),
                subtitle: Slider(
                  value: opacity.clamp(0.0, 1.0),
                  min: 0.05,
                  max: 0.8,
                  divisions: 15,
                  label: '${(opacity * 100).round()}%',
                  onChanged: (v) async {
                    await s.set('backgroundOpacity', v);
                    ThemeController.instance.refresh();
                  },
                ),
              ),
              ListTile(
                title: const Text('背景模糊'),
                subtitle: Slider(
                  value: blur.clamp(0.0, 40.0),
                  min: 0,
                  max: 40,
                  divisions: 20,
                  label: blur.round().toString(),
                  onChanged: (v) async {
                    await s.set('backgroundBlur', v);
                    ThemeController.instance.refresh();
                  },
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GlassPanel(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          gradient: AppPalette.brandGradient(context),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.graphic_eq_rounded, color: Colors.white),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('爽听', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                            SizedBox(height: 4),
                            Text('听见爽 · 主题预览', style: TextStyle(fontSize: 11)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
