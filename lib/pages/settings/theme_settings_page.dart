import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../theme/app_theme.dart';
import '../../theme/theme_controller.dart';

class ThemeSettingsPage extends StatelessWidget {
  const ThemeSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<ThemeController>();
    return Scaffold(
      appBar: AppBar(title: const Text('外观与主题')),
      body: Obx(() {
        final scheme = Theme.of(context).colorScheme;
        final dynamicAvailable = controller.dynamicColorAvailable;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
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
            Text(
              'Material You',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Card.outlined(
              child: SwitchListTile(
                secondary: const Icon(Icons.palette_outlined),
                title: const Text('使用动态配色'),
                subtitle: Text(
                  dynamicAvailable
                      ? '跟随设备壁纸颜色'
                      : '当前设备不支持，正在使用${controller.preset.value.label}主题',
                ),
                value: dynamicAvailable && controller.useDynamicColor.value,
                onChanged: dynamicAvailable ? controller.setDynamicColor : null,
              ),
            ),
            const SizedBox(height: 24),
            Text('明暗模式', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SegmentedButton<ThemeMode>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: ThemeMode.system,
                  icon: Icon(Icons.brightness_auto_outlined),
                  label: Text('系统'),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  icon: Icon(Icons.light_mode_outlined),
                  label: Text('浅色'),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  icon: Icon(Icons.dark_mode_outlined),
                  label: Text('深色'),
                ),
              ],
              selected: {controller.themeMode.value},
              onSelectionChanged:
                  (selection) => controller.setThemeMode(selection.first),
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
