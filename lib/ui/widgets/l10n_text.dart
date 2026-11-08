import 'package:flutter/widgets.dart' as w;

import '../../core/settings.dart';

/// 全局自动翻译的 [w.Text] 替身。
///
/// 项目里所有 `Text('中文')` 都会经过 [L10n.t]：先整串查表，查不到再做词块替换
/// 与数量单位处理。这样新增页面不必逐个包 `Tr()`，中英切换是全局生效的。
class Text extends w.StatelessWidget {
  const Text(
    this.data, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  });

  final String data;
  final w.TextStyle? style;
  final w.StrutStyle? strutStyle;
  final w.TextAlign? textAlign;
  final w.TextDirection? textDirection;
  final w.Locale? locale;
  final bool? softWrap;
  final w.TextOverflow? overflow;
  final w.TextScaler? textScaler;
  final int? maxLines;
  final String? semanticsLabel;
  final w.TextWidthBasis? textWidthBasis;
  final w.TextHeightBehavior? textHeightBehavior;
  final w.Color? selectionColor;

  @override
  w.Widget build(w.BuildContext context) => w.Text(
        L10n.instance.t(data),
        style: style,
        strutStyle: strutStyle,
        textAlign: textAlign,
        textDirection: textDirection,
        locale: locale,
        softWrap: softWrap,
        overflow: overflow,
        textScaler: textScaler,
        maxLines: maxLines,
        semanticsLabel: semanticsLabel,
        textWidthBasis: textWidthBasis,
        textHeightBehavior: textHeightBehavior,
        selectionColor: selectionColor,
      );

  /// 富文本不走词表，保持原样。
  static w.Widget rich(
    w.InlineSpan span, {
    w.Key? key,
    w.TextStyle? style,
    w.StrutStyle? strutStyle,
    w.TextAlign? textAlign,
    w.TextDirection? textDirection,
    w.Locale? locale,
    bool? softWrap,
    w.TextOverflow? overflow,
    w.TextScaler? textScaler,
    int? maxLines,
    String? semanticsLabel,
    w.TextWidthBasis? textWidthBasis,
    w.TextHeightBehavior? textHeightBehavior,
    w.Color? selectionColor,
  }) =>
      w.Text.rich(
        span,
        key: key,
        style: style,
        strutStyle: strutStyle,
        textAlign: textAlign,
        textDirection: textDirection,
        locale: locale,
        softWrap: softWrap,
        overflow: overflow,
        textScaler: textScaler,
        maxLines: maxLines,
        semanticsLabel: semanticsLabel,
        textWidthBasis: textWidthBasis,
        textHeightBehavior: textHeightBehavior,
        selectionColor: selectionColor,
      );
}
