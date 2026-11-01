import 'dart:io';

import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import '../../home/coursetable/style/course_card_surface.dart';
import '../../home/coursetable/style/course_table_background.dart';
import '../../home/coursetable/style/course_table_style.dart';
import '../../home/coursetable/style/course_table_style_controller.dart';
import '../../theme/glass/glass_overlays.dart';
import '../../theme/glass/glass_scaffold.dart';
import '../../theme/glass/glass_segmented.dart';
import '../../theme/glass/glass_theme.dart';

/// 「课表外观」设置页：背景色、背景图（不透明度 / 模糊 / 明暗）、
/// 课程块不透明度 / 彩色开关 / 材质 / 毛玻璃模糊 / 文字颜色，
/// 全部即时生效并持久化。
class CourseTableStylePage extends StatefulWidget {
  const CourseTableStylePage({super.key});

  @override
  State<CourseTableStylePage> createState() => _CourseTableStylePageState();
}

class _CourseTableStylePageState extends State<CourseTableStylePage> {
  CourseTableStyleController get _controller =>
      CourseTableStyleController.instance;

  /// 拖动滑杆 / 取色过程中的临时值。
  ///
  /// 只在预览与控件上生效，松手才写进控制器——课表页在设置页下方仍然挂载，
  /// 逐帧提交会让它跟着重建一遍课程块（含玻璃与模糊），代价没有必要。
  CourseTableStyle? _draft;

  bool _colorExpanded = false;

  CourseTableStyle get _style => _draft ?? _controller.value;

  void _preview(CourseTableStyle next) {
    setState(() => _draft = next);
  }

  Future<void> _commit(Future<void> Function() action) async {
    await action();
    if (mounted) setState(() => _draft = null);
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      title: '课表外观',
      body: Obx(() {
        final CourseTableStyle style = _draft ?? _controller.style.value;
        final AppGlassTheme glass = context.glassTheme;
        return ListView(
          padding: EdgeInsets.fromLTRB(16, 8 + glassTopInset(context), 16, 40),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildPreview(context, style),
                    const SizedBox(height: 24),
                    _sectionTitle(context, '背景'),
                    const SizedBox(height: 8),
                    _buildColorCard(context, style),
                    const SizedBox(height: 8),
                    _buildImageCard(context, style, glass),
                    const SizedBox(height: 24),
                    _sectionTitle(context, '课程块'),
                    const SizedBox(height: 8),
                    _buildCardStyleCard(context, style, glass),
                    const SizedBox(height: 24),
                    _buildResetCard(context),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: Text(title, style: Theme.of(context).textTheme.titleMedium),
  );

  // ── 实时预览 ────────────────────────────────────────────────────────────

  Widget _buildPreview(BuildContext context, CourseTableStyle style) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color estimate = style.estimatedPageColor(scheme);
    final Color onBackground =
        estimate.computeLuminance() > 0.45
            ? const Color(0xFF1B1B1F)
            : Colors.white;

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: 184,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CourseTableBackground(style: style, scheme: scheme),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '第 8 周',
                            style: TextStyle(
                              color: onBackground,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '10月12日 – 10月18日',
                            style: TextStyle(
                              color: onBackground.withValues(alpha: 0.75),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.onSurface.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '预览',
                          style: TextStyle(
                            color: onBackground.withValues(alpha: 0.9),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Row(
                      children: [
                        _previewCard(
                          context,
                          style,
                          accent: const Color(0xFF4C5BD4),
                          name: '高等数学',
                          location: '崇学楼 305',
                          teacher: '李老师',
                        ),
                        const SizedBox(width: 8),
                        _previewCard(
                          context,
                          style,
                          accent: const Color(0xFF1E8E6A),
                          name: '大学物理',
                          location: '工科楼 112',
                          teacher: '王老师',
                        ),
                        const SizedBox(width: 8),
                        _previewCard(
                          context,
                          style,
                          accent: const Color(0xFFB25E1F),
                          name: '程序设计',
                          location: '信息楼 401',
                          teacher: '张老师',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _previewCard(
    BuildContext context,
    CourseTableStyle style, {
    required Color accent,
    required String name,
    required String location,
    required String teacher,
  }) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color foreground = style.courseForeground(
      accent,
      pageEstimate: style.estimatedPageColor(scheme),
    );
    final Color muted = foreground.withValues(alpha: 0.82);

    return Expanded(
      child: CourseCardSurface(
        accent: accent,
        style: style,
        borderRadius: 10,
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: foreground,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
              const Spacer(),
              Text(
                location,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: muted, fontSize: 9),
              ),
              Text(
                teacher,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: muted, fontSize: 9),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 背景颜色 ────────────────────────────────────────────────────────────

  Widget _buildColorCard(BuildContext context, CourseTableStyle style) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color current = style.backgroundColor ?? scheme.surface;

    return Card.outlined(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          ListTile(
            leading: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: current,
                shape: BoxShape.circle,
                border: Border.all(color: scheme.outlineVariant),
              ),
            ),
            title: const Text('背景颜色'),
            subtitle: Text(
              style.backgroundColor == null
                  ? '跟随主题'
                  : _hexOf(style.backgroundColor!),
            ),
            trailing: Icon(
              _colorExpanded ? Icons.expand_less : Icons.expand_more,
            ),
            onTap: () => setState(() => _colorExpanded = !_colorExpanded),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            child:
                _colorExpanded
                    ? Column(
                      children: [
                        Divider(
                          height: 1,
                          color: scheme.outlineVariant.withValues(alpha: 0.6),
                        ),
                        _buildColorSwatches(context, style),
                        ColorPicker(
                          color: current,
                          pickersEnabled: const <ColorPickerType, bool>{
                            ColorPickerType.primary: true,
                            ColorPickerType.wheel: true,
                          },
                          pickerTypeLabels: const <ColorPickerType, String>{
                            ColorPickerType.primary: '色板',
                            ColorPickerType.wheel: '色轮',
                          },
                          enableOpacity: false,
                          enableShadesSelection: false,
                          showColorCode: true,
                          showRecentColors: true,
                          maxRecentColors: 6,
                          heading: null,
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                          wheelDiameter: 200,
                          onColorChanged:
                              (color) => _preview(
                                _style.copyWith(backgroundColor: color),
                              ),
                          onColorChangeEnd:
                              (color) => _commit(
                                () => _controller.setBackgroundColor(color),
                              ),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                            child: TextButton.icon(
                              onPressed:
                                  () => _commit(
                                    () => _controller.setBackgroundColor(null),
                                  ),
                              icon: const Icon(
                                Icons.format_color_reset,
                                size: 18,
                              ),
                              label: const Text('跟随主题'),
                            ),
                          ),
                        ),
                      ],
                    )
                    : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  /// 常用底色：点一下即生效，省得在色轮里慢慢找。
  static const List<Color> _presetColors = <Color>[
    Color(0xFFFDFBFF),
    Color(0xFFF0F3FA),
    Color(0xFFE3ECFA),
    Color(0xFFF3E8F8),
    Color(0xFFFCEEDD),
    Color(0xFF23443A),
    Color(0xFF2E3A59),
    Color(0xFF1B1B1F),
  ];

  Widget _buildColorSwatches(BuildContext context, CourseTableStyle style) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final Color color in _presetColors)
            _ColorSwatch(
              color: color,
              selected: style.backgroundColor?.toARGB32() == color.toARGB32(),
              onTap: () => _commit(() => _controller.setBackgroundColor(color)),
            ),
        ],
      ),
    );
  }

  // ── 背景图片 ────────────────────────────────────────────────────────────

  Widget _buildImageCard(
    BuildContext context,
    CourseTableStyle style,
    AppGlassTheme glass,
  ) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool hasImage = style.hasImage;

    return Card.outlined(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Row(
              children: [
                _ImageThumb(style: style),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '背景图片',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasImage ? '已选择，可继续调整不透明度、模糊与明暗' : '从相册选一张图，铺满整个课表页',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (hasImage)
                  TextButton(
                    onPressed:
                        () => _commit(() => _controller.clearBackgroundImage()),
                    child: const Text('移除'),
                  ),
                const SizedBox(width: 4),
                FilledButton.tonalIcon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                  label: Text(hasImage ? '更换图片' : '选择图片'),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: scheme.outlineVariant.withValues(alpha: 0.6),
          ),
          Opacity(
            opacity: hasImage ? 1 : 0.45,
            child: IgnorePointer(
              ignoring: !hasImage,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6, 6, 14, 10),
                child: Column(
                  children: [
                    _SliderRow(
                      icon: Icons.opacity,
                      value: style.imageOpacity,
                      min: 0,
                      max: 1,
                      valueLabel: '${(style.imageOpacity * 100).round()}%',
                      glassEnabled: glass.enabled,
                      onLive:
                          (value) =>
                              _preview(_style.copyWith(imageOpacity: value)),
                      onCommit:
                          (value) =>
                              _commit(() => _controller.setImageOpacity(value)),
                    ),
                    _SliderRow(
                      icon: Icons.blur_off,
                      endIcon: Icons.blur_on,
                      value: style.imageBlur,
                      min: 0,
                      max: CourseTableStyle.maxImageBlur,
                      valueLabel: '${style.imageBlur.round()}',
                      glassEnabled: glass.enabled,
                      onLive:
                          (value) =>
                              _preview(_style.copyWith(imageBlur: value)),
                      onCommit:
                          (value) =>
                              _commit(() => _controller.setImageBlur(value)),
                    ),
                    _SliderRow(
                      icon: Icons.dark_mode_outlined,
                      endIcon: Icons.light_mode_outlined,
                      value: style.imageBrightness,
                      min: -1,
                      max: 1,
                      valueLabel: _brightnessLabel(style.imageBrightness),
                      glassEnabled: glass.enabled,
                      onLive:
                          (value) =>
                              _preview(_style.copyWith(imageBrightness: value)),
                      onCommit:
                          (value) => _commit(
                            () => _controller.setImageBrightness(value),
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage() async {
    final messenger = ScaffoldMessenger.of(context);
    final bool picked = await _controller.pickBackgroundImage();
    if (!mounted) return;
    if (!picked) {
      messenger.showSnackBar(
        const SnackBar(content: Text('未选择图片，可再试一次或在系统设置里允许访问照片')),
      );
    }
  }

  // ── 课程块样式 ──────────────────────────────────────────────────────────

  Widget _buildCardStyleCard(
    BuildContext context,
    CourseTableStyle style,
    AppGlassTheme glass,
  ) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool liquidGlassHint =
        style.material == CourseCardMaterial.liquidGlass && !glass.enabled;
    // 液态玻璃不可用时渲染层会降级成毛玻璃，模糊滑杆要跟着出现，
    // 否则用户选完液态玻璃会发现「模糊设置没了」。
    final bool frostedActive =
        style.material == CourseCardMaterial.frosted || liquidGlassHint;

    return Card.outlined(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 8, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SliderRow(
              icon: Icons.circle_outlined,
              endIcon: Icons.circle,
              value: style.cardOpacity,
              min: 0,
              max: 1,
              valueLabel: '${(style.cardOpacity * 100).round()}%',
              glassEnabled: glass.enabled,
              onLive: (value) => _preview(_style.copyWith(cardOpacity: value)),
              onCommit:
                  (value) => _commit(() => _controller.setCardOpacity(value)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 0, 14),
              child: Text(
                _cardOpacityHint(style),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
            ListTile(
              contentPadding: const EdgeInsets.fromLTRB(10, 0, 0, 0),
              leading: Icon(
                Icons.palette_outlined,
                size: 20,
                color: scheme.onSurfaceVariant,
              ),
              title: const Text('课程块彩色'),
              subtitle: Text(
                style.colorful
                    ? '按课程区分颜色'
                    : '已关闭：课程块不再区分颜色，只铺一层白/黑蒙版',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              trailing: _GlassSwitch(
                enabled: glass.enabled,
                value: style.colorful,
                onChanged:
                    (value) =>
                        _commit(() => _controller.setColorful(value)),
              ),
              onTap:
                  () => _commit(
                    () => _controller.setColorful(!style.colorful),
                  ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 0, 8),
              child: Text(
                '材质',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 10),
              child: GlassSegmented<CourseCardMaterial>(
                expand: true,
                height: 40,
                pillHighlight: true,
                segments: [
                  for (final material in CourseCardMaterial.values)
                    GlassSegment(value: material, label: material.label),
                ],
                selected: style.material,
                onChanged:
                    (material) =>
                        _commit(() => _controller.setMaterial(material)),
              ),
            ),
            if (liquidGlassHint)
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 0, 0),
                child: Text(
                  '液态玻璃外观未开启（或在当前平台不可用），课程块暂按毛玻璃显示。'
                  '可在「外观与主题」里打开。',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: scheme.error),
                ),
              ),
            // 只有真的会渲染成毛玻璃时才出现：纯色 / 可用液态玻璃下没有模糊可调。
            if (frostedActive) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 12, 0, 6),
                child: Text(
                  '毛玻璃模糊',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: _SliderRow(
                  icon: Icons.blur_off,
                  endIcon: Icons.blur_on,
                  value: style.cardBlur,
                  min: 0,
                  max: CourseTableStyle.maxCardBlur,
                  valueLabel: '${style.cardBlur.round()}',
                  glassEnabled: glass.enabled,
                  onLive:
                      (value) => _preview(_style.copyWith(cardBlur: value)),
                  onCommit:
                      (value) => _commit(() => _controller.setCardBlur(value)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 4, 0, 0),
                child: Text(
                  style.cardBlur < 0.5
                      ? '模糊为 0：完全不雾化，课程块只是一层半透明底色'
                      : '雾化身后背景的强度，越大越看不出底下是什么',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 16, 0, 8),
              child: Text(
                '文字颜色',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 10),
              child: GlassSegmented<CourseTextColorMode>(
                expand: true,
                height: 40,
                pillHighlight: true,
                segments: [
                  for (final mode in CourseTextColorMode.values)
                    GlassSegment(value: mode, label: mode.label),
                ],
                selected: style.textColor,
                onChanged:
                    (mode) => _commit(() => _controller.setTextColor(mode)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 0, 0),
              child: Text(
                style.textColor.description,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 恢复默认 ────────────────────────────────────────────────────────────

  Widget _buildResetCard(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Card.outlined(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: Icon(Icons.restart_alt, color: scheme.error),
        title: Text(
          '恢复默认设置',
          style: TextStyle(color: scheme.error, fontWeight: FontWeight.w600),
        ),
        subtitle: const Text('清空背景色、背景图与课程块外观'),
        onTap: _confirmReset,
      ),
    );
  }

  Future<void> _confirmReset() async {
    final bool? confirmed = await showGlassDialog<bool>(
      context: context,
      title: const Text('恢复默认？'),
      content: const Text('将清空背景色、背景图片与课程块外观设置，课表页回到出厂观感。'),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('恢复'),
        ),
      ],
    );
    if (confirmed ?? false) {
      await _controller.reset();
      if (mounted) setState(() => _draft = null);
    }
  }

  // ── 工具 ────────────────────────────────────────────────────────────────

  /// 不透明度滑杆的说明：开着彩色时是课程色浓度，关掉后变成白/黑蒙版浓度。
  static String _cardOpacityHint(CourseTableStyle style) {
    if (!style.colorful) {
      return style.cardOpacity <= 0
          ? '蒙版完全透明：课程块只剩文字，看不到任何底色'
          : '无色蒙版浓度：拉满时课程块整体变白（深色页面变黑）';
    }
    return style.material == CourseCardMaterial.solid && style.cardOpacity <= 0
        ? '不透明度为 0：课程块不显示任何底色，只保留文字'
        : '课程块底色不透明度';
  }

  static String _brightnessLabel(double value) {
    final int percent = (value * 100).round();
    if (percent == 0) return '0';
    return percent > 0 ? '+$percent' : '$percent';
  }

  static String _hexOf(Color color) {
    final int argb = color.toARGB32();
    final String rgb = (argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0');
    return '#${rgb.toUpperCase()}';
  }
}

/// 一枚预设底色：选中时套一圈主题色描边并打勾。
class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool light = color.computeLuminance() > 0.55;
    return Semantics(
      button: true,
      selected: selected,
      child: InkResponse(
        onTap: onTap,
        radius: 22,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color:
                  selected
                      ? scheme.primary
                      : scheme.outlineVariant.withValues(alpha: 0.9),
              width: selected ? 2.5 : 1,
            ),
          ),
          child:
              selected
                  ? Icon(
                    Icons.check,
                    size: 16,
                    color: light ? scheme.primary : Colors.white,
                  )
                  : null,
        ),
      ),
    );
  }
}

/// 图片缩略图：没有图片时给一个虚线占位框。
class _ImageThumb extends StatelessWidget {
  const _ImageThumb({required this.style});

  final CourseTableStyle style;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Widget placeholder = DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Icon(
        Icons.image_outlined,
        size: 20,
        color: scheme.onSurfaceVariant,
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 72,
        height: 48,
        child:
            style.hasImage
                ? Image.file(
                  File(style.backgroundImagePath!),
                  fit: BoxFit.cover,
                  cacheWidth: 216,
                  errorBuilder: (_, _, _) => placeholder,
                )
                : placeholder,
      ),
    );
  }
}

/// 一行滑杆：左图标 + 滑杆 + 右数值，玻璃开启时用玻璃滑块。
///
/// 拖动过程只回调 [onLive]（预览用），手势结束才回调 [onCommit]（落盘 +
/// 通知课表页），避免逐帧写 prefs 与重建课程块。
class _SliderRow extends StatefulWidget {
  const _SliderRow({
    required this.icon,
    required this.value,
    required this.min,
    required this.max,
    required this.valueLabel,
    required this.glassEnabled,
    required this.onLive,
    required this.onCommit,
    this.endIcon,
  });

  final IconData icon;
  final IconData? endIcon;
  final double value;
  final double min;
  final double max;
  final String valueLabel;
  final bool glassEnabled;
  final ValueChanged<double> onLive;
  final ValueChanged<double> onCommit;

  @override
  State<_SliderRow> createState() => _SliderRowState();
}

class _SliderRowState extends State<_SliderRow> {
  late double _value = widget.value;

  @override
  void didUpdateWidget(covariant _SliderRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) _value = widget.value;
  }

  void _handleChanged(double value) {
    setState(() => _value = value);
    widget.onLive(value);
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    final Widget slider =
        widget.glassEnabled
            ? SizedBox(
              height: 40,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final double width =
                      constraints.maxWidth.isFinite
                          ? constraints.maxWidth
                          : 220;
                  return LiquidGlassSlider(
                    value: _value.clamp(widget.min, widget.max),
                    width: width,
                    minimumValue: widget.min,
                    maximumValue: widget.max,
                    // 拖动中逐帧回调做预览，松手才把最终值提交给控制器。
                    isContinuous: true,
                    onChanged: _handleChanged,
                    onChangeEnd: widget.onCommit,
                    activeColor: scheme.primary,
                    inactiveColor: scheme.onSurface.withValues(alpha: 0.10),
                    thumbColor: Colors.white,
                  );
                },
              ),
            )
            : Slider(
              value: _value.clamp(widget.min, widget.max),
              min: widget.min,
              max: widget.max,
              onChanged: _handleChanged,
              onChangeEnd: widget.onCommit,
            );

    return Row(
      children: [
        const SizedBox(width: 4),
        Icon(widget.icon, size: 18, color: scheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Expanded(child: slider),
        const SizedBox(width: 6),
        if (widget.endIcon != null)
          Icon(widget.endIcon, size: 18, color: scheme.onSurfaceVariant)
        else
          const SizedBox(width: 18),
        const SizedBox(width: 8),
        SizedBox(
          width: 44,
          child: Text(
            widget.valueLabel,
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}

/// 设置页里的玻璃开关：玻璃开启时是玻璃旋钮，回退后是普通 M3 开关。
///
/// 与 `theme_settings_page.dart` 里的同名部件保持一致；那边是私有类，
/// 这里另存一份而不是提升成公共组件，避免为一个开关牵动主题设置页。
class _GlassSwitch extends StatelessWidget {
  const _GlassSwitch({
    required this.enabled,
    required this.value,
    required this.onChanged,
  });

  final bool enabled;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return Switch(value: value, onChanged: onChanged);
    }
    return LiquidGlassSwitch(
      value: value,
      onChanged: onChanged,
      activeColor: Theme.of(context).colorScheme.primary,
    );
  }
}
