import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import '../../theme/app_theme.dart';
import '../../theme/glass/glass_scaffold.dart';
import '../../theme/glass/glass_segmented.dart';
import '../../theme/glass/glass_theme.dart';
import '../../theme/theme_controller.dart';

class ThemeSettingsPage extends StatelessWidget {
  const ThemeSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<ThemeController>();
    final glass = context.glassTheme;
    return GlassScaffold(
      title: '外观与主题',
      body: Obx(() {
        final scheme = Theme.of(context).colorScheme;
        final dynamicAvailable = controller.dynamicColorAvailable;
        final glassSupported = controller.liquidGlassSupported;
        return ListView(
          padding: EdgeInsets.fromLTRB(16, 8 + glassTopInset(context), 16, 32),
          children: [
            Card.filled(
              color: scheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '当前外观',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: scheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _ColorDot(color: scheme.primary, size: 44),
                        const SizedBox(width: 10),
                        _ColorDot(color: scheme.secondary, size: 36),
                        const SizedBox(width: 10),
                        _ColorDot(color: scheme.tertiary, size: 30),
                        const Spacer(),
                        Text(
                          controller.useDynamicColor.value && dynamicAvailable
                              ? '动态配色'
                              : controller.preset.value.label,
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(color: scheme.onPrimaryContainer),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('液态玻璃', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Card.outlined(
              child: ListTile(
                leading: const Icon(Icons.blur_on_outlined),
                title: const Text('液态玻璃外观'),
                subtitle: Text(
                  !glassSupported
                      ? '当前平台不支持液态玻璃'
                      : controller.useLiquidGlass.value
                      ? '导航栏、标题栏与弹层使用悬浮玻璃'
                      : '已回退到 Material 3 外观',
                ),
                trailing: _GlassToggle(
                  enabled: glass.enabled,
                  value: controller.useLiquidGlass.value,
                  onChanged: glassSupported ? controller.setLiquidGlass : null,
                ),
                onTap:
                    glassSupported
                        ? () => controller.setLiquidGlass(
                          !controller.useLiquidGlass.value,
                        )
                        : null,
              ),
            ),
            const SizedBox(height: 8),
            _buildGlassTintCard(context, controller, scheme),
            const SizedBox(height: 24),
            Text(
              'Material You',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Card.outlined(
              child:
                  glass.enabled
                      ? ListTile(
                        leading: const Icon(Icons.palette_outlined),
                        title: const Text('使用动态配色'),
                        subtitle: Text(
                          dynamicAvailable
                              ? '跟随设备壁纸颜色'
                              : '当前设备不支持，正在使用${controller.preset.value.label}主题',
                        ),
                        trailing: _GlassToggle(
                          enabled: true,
                          value:
                              dynamicAvailable &&
                              controller.useDynamicColor.value,
                          onChanged:
                              dynamicAvailable
                                  ? controller.setDynamicColor
                                  : null,
                        ),
                        onTap:
                            dynamicAvailable
                                ? () => controller.setDynamicColor(
                                  !controller.useDynamicColor.value,
                                )
                                : null,
                      )
                      : SwitchListTile(
                        secondary: const Icon(Icons.palette_outlined),
                        title: const Text('使用动态配色'),
                        subtitle: Text(
                          dynamicAvailable
                              ? '跟随设备壁纸颜色'
                              : '当前设备不支持，正在使用${controller.preset.value.label}主题',
                        ),
                        value:
                            dynamicAvailable &&
                            controller.useDynamicColor.value,
                        onChanged:
                            dynamicAvailable
                                ? controller.setDynamicColor
                                : null,
                      ),
            ),
            const SizedBox(height: 24),
            Text('明暗模式', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            // 玻璃开启时是一枚等分铺满的分段胶囊，选中项是主题色玻璃滑块；
            // 关闭时回落 Material 分段控件。
            GlassSegmented<ThemeMode>(
              expand: true,
              height: 40,
              pillHighlight: true,
              segments: const [
                GlassSegment(
                  value: ThemeMode.system,
                  label: '系统',
                  icon: Icons.brightness_auto_outlined,
                ),
                GlassSegment(
                  value: ThemeMode.light,
                  label: '浅色',
                  icon: Icons.light_mode_outlined,
                ),
                GlassSegment(
                  value: ThemeMode.dark,
                  label: '深色',
                  icon: Icons.dark_mode_outlined,
                ),
              ],
              selected: controller.themeMode.value,
              onChanged: controller.setThemeMode,
            ),
            const SizedBox(height: 24),
            Text('预设配色', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              '选择预设会关闭动态配色',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            ...AppThemePreset.values.map(
              (preset) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _PresetCard(
                  preset: preset,
                  selected:
                      !controller.useDynamicColor.value &&
                      controller.preset.value == preset,
                  onTap: () => controller.selectPreset(preset),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  /// 玻璃通透度：左「透明」右「色调」，拖动松手后一次性生效。
  Widget _buildGlassTintCard(
    BuildContext context,
    ThemeController controller,
    ColorScheme scheme,
  ) {
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.blur_on_outlined,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _GlassTintSlider(
                    value: controller.glassTint.value,
                    glassEnabled: context.glassTheme.enabled,
                    onChanged: controller.setGlassTint,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(Icons.opacity, size: 18, color: scheme.onSurfaceVariant),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                '“透明” 更通透，“色调” 会增加不透明度，提升内容和控制项的对比度。',
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
}

/// 通透度滑杆：玻璃开启时是带玻璃滑块的 `LiquidGlassSlider`，
/// 关闭时回落 Material `Slider`。
///
/// 拖动期间不提交：`LiquidGlassSlider(isContinuous: false)` 只在手势结束
/// 回调一次，Material 分支用 `onChanged` 只更新本地值、`onChangeEnd` 才提交，
/// 避免逐帧重建 `ThemeData`（`FlexThemeData` 构造成本高）。点按轨道属于
/// 一次性操作，会立即生效。
class _GlassTintSlider extends StatefulWidget {
  const _GlassTintSlider({
    required this.value,
    required this.glassEnabled,
    required this.onChanged,
  });

  final double value;
  final bool glassEnabled;
  final ValueChanged<double> onChanged;

  @override
  State<_GlassTintSlider> createState() => _GlassTintSliderState();
}

class _GlassTintSliderState extends State<_GlassTintSlider> {
  late double _value = widget.value;

  @override
  void didUpdateWidget(covariant _GlassTintSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _value = widget.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (!widget.glassEnabled) {
      return Slider(
        value: _value,
        onChanged: (value) => setState(() => _value = value),
        onChangeEnd: widget.onChanged,
      );
    }

    return SizedBox(
      height: 44,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double width =
              constraints.maxWidth.isFinite ? constraints.maxWidth : 240;
          return LiquidGlassSlider(
            value: _value,
            width: width,
            isContinuous: false,
            onChanged: (value) {
              setState(() => _value = value);
              widget.onChanged(value);
            },
            activeColor: scheme.primary,
            inactiveColor: scheme.onSurface.withValues(alpha: 0.10),
            thumbColor: Colors.white,
          );
        },
      ),
    );
  }
}

class _PresetCard extends StatelessWidget {
  final AppThemePreset preset;
  final bool selected;
  final VoidCallback onTap;

  const _PresetCard({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final scheme = AppTheme.presetScheme(preset, brightness);
    return Card.outlined(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              _ColorDot(color: scheme.primary, size: 34),
              const SizedBox(width: 8),
              _ColorDot(color: scheme.secondary, size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  preset.label,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (selected)
                Icon(
                  Icons.check_circle,
                  color: Theme.of(context).colorScheme.primary,
                )
              else
                const Icon(Icons.circle_outlined),
            ],
          ),
        ),
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  final Color color;
  final double size;

  const _ColorDot({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// 「液态玻璃外观」的开关：玻璃开启时是玻璃旋钮，回退后是普通 M3 开关。
class _GlassToggle extends StatelessWidget {
  const _GlassToggle({
    required this.enabled,
    required this.value,
    this.onChanged,
  });

  final bool enabled;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    if (!enabled || onChanged == null) {
      return Switch(value: value, onChanged: onChanged);
    }
    return LiquidGlassSwitch(
      value: value,
      onChanged: onChanged!,
      activeColor: Theme.of(context).colorScheme.primary,
      // 布局足迹就是轨道本身（默认 63×28），右缘与 M3 开关对齐；
      // 旋钮膨胀约 10px 仍在 Card 的 16px 内边距内，不会被裁，
      // 因此不需要 reserveSwellRoom（它会让轨道整体偏左）。
    );
  }
}
