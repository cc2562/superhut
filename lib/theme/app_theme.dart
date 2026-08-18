import 'package:dynamic_color/dynamic_color.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

enum AppThemePreset { indigo, blue, teal, purple, orange, rose }

extension AppThemePresetData on AppThemePreset {
  String get label => switch (this) {
    AppThemePreset.indigo => '靛蓝',
    AppThemePreset.blue => '蓝色',
    AppThemePreset.teal => '青绿',
    AppThemePreset.purple => '紫色',
    AppThemePreset.orange => '橙色',
    AppThemePreset.rose => '玫红',
  };

  Color get seedColor => switch (this) {
    AppThemePreset.indigo => const Color(0xFF3F51B5),
    AppThemePreset.blue => const Color(0xFF1565C0),
    AppThemePreset.teal => const Color(0xFF00796B),
    AppThemePreset.purple => const Color(0xFF7B1FA2),
    AppThemePreset.orange => const Color(0xFFE65100),
    AppThemePreset.rose => const Color(0xFFC2185B),
  };
}

@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  final Color success;
  final Color onSuccess;
  final Color successContainer;
  final Color onSuccessContainer;
  final Color warning;
  final Color onWarning;
  final Color warningContainer;
  final Color onWarningContainer;
  final Color info;
  final Color onInfo;
  final Color infoContainer;
  final Color onInfoContainer;

  const AppSemanticColors({
    required this.success,
    required this.onSuccess,
    required this.successContainer,
    required this.onSuccessContainer,
    required this.warning,
    required this.onWarning,
    required this.warningContainer,
    required this.onWarningContainer,
    required this.info,
    required this.onInfo,
    required this.infoContainer,
    required this.onInfoContainer,
  });

  factory AppSemanticColors.from(ColorScheme scheme) {
    ColorScheme custom(Color seed) => ColorScheme.fromSeed(
      seedColor: seed.harmonizeWith(scheme.primary),
      brightness: scheme.brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
    );

    final successScheme = custom(const Color(0xFF386A20));
    final warningScheme = custom(const Color(0xFF825500));
    final infoScheme = custom(const Color(0xFF0061A4));
    return AppSemanticColors(
      success: successScheme.primary,
      onSuccess: successScheme.onPrimary,
      successContainer: successScheme.primaryContainer,
      onSuccessContainer: successScheme.onPrimaryContainer,
      warning: warningScheme.primary,
      onWarning: warningScheme.onPrimary,
      warningContainer: warningScheme.primaryContainer,
      onWarningContainer: warningScheme.onPrimaryContainer,
      info: infoScheme.primary,
      onInfo: infoScheme.onPrimary,
      infoContainer: infoScheme.primaryContainer,
      onInfoContainer: infoScheme.onPrimaryContainer,
    );
  }

  @override
  AppSemanticColors copyWith({
    Color? success,
    Color? onSuccess,
    Color? successContainer,
    Color? onSuccessContainer,
    Color? warning,
    Color? onWarning,
    Color? warningContainer,
    Color? onWarningContainer,
    Color? info,
    Color? onInfo,
    Color? infoContainer,
    Color? onInfoContainer,
  }) {
    return AppSemanticColors(
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      successContainer: successContainer ?? this.successContainer,
      onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      warningContainer: warningContainer ?? this.warningContainer,
      onWarningContainer: onWarningContainer ?? this.onWarningContainer,
      info: info ?? this.info,
      onInfo: onInfo ?? this.onInfo,
      infoContainer: infoContainer ?? this.infoContainer,
      onInfoContainer: onInfoContainer ?? this.onInfoContainer,
    );
  }

  @override
  AppSemanticColors lerp(covariant AppSemanticColors? other, double t) {
    if (other == null) return this;
    return AppSemanticColors(
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      successContainer:
          Color.lerp(successContainer, other.successContainer, t)!,
      onSuccessContainer:
          Color.lerp(onSuccessContainer, other.onSuccessContainer, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      warningContainer:
          Color.lerp(warningContainer, other.warningContainer, t)!,
      onWarningContainer:
          Color.lerp(onWarningContainer, other.onWarningContainer, t)!,
      info: Color.lerp(info, other.info, t)!,
      onInfo: Color.lerp(onInfo, other.onInfo, t)!,
      infoContainer: Color.lerp(infoContainer, other.infoContainer, t)!,
      onInfoContainer: Color.lerp(onInfoContainer, other.onInfoContainer, t)!,
    );
  }
}

abstract final class AppTheme {
  static const FlexSubThemesData _subThemes = FlexSubThemesData(
    interactionEffects: true,
    tintedDisabledControls: true,
    blendOnLevel: 0,
    useM2StyleDividerInM3: false,
    inputDecoratorIsFilled: true,
    inputDecoratorUnfocusedHasBorder: false,
    inputDecoratorRadius: 12,
    segmentedButtonSchemeColor: SchemeColor.primary,
    popupMenuRadius: 12,
    dialogRadius: 28,
    bottomSheetRadius: 28,
    snackBarRadius: 12,
    navigationBarIndicatorSchemeColor: SchemeColor.primaryContainer,
  );

  static ColorScheme presetScheme(
    AppThemePreset preset,
    Brightness brightness,
  ) {
    return ColorScheme.fromSeed(
      seedColor: preset.seedColor,
      brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
    );
  }

  static ThemeData fromScheme(ColorScheme scheme) {
    final isDark = scheme.brightness == Brightness.dark;
    final theme =
        isDark
            ? FlexThemeData.dark(
              colorScheme: scheme,
              blendLevel: 0,
              subThemesData: _subThemes,
              visualDensity: FlexColorScheme.comfortablePlatformDensity,
              cupertinoOverrideTheme: const CupertinoThemeData(
                applyThemeToAll: true,
              ),
            )
            : FlexThemeData.light(
              colorScheme: scheme,
              blendLevel: 0,
              subThemesData: _subThemes,
              visualDensity: FlexColorScheme.comfortablePlatformDensity,
              cupertinoOverrideTheme: const CupertinoThemeData(
                applyThemeToAll: true,
              ),
            );

    return theme.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      extensions: <ThemeExtension<dynamic>>[AppSemanticColors.from(scheme)],
      appBarTheme: theme.appBarTheme.copyWith(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: scheme.surfaceTint,
      ),
      cardTheme: theme.cardTheme.copyWith(
        elevation: 0,
        clipBehavior: Clip.antiAlias,
      ),
      snackBarTheme: theme.snackBarTheme.copyWith(
        behavior: SnackBarBehavior.floating,
        showCloseIcon: true,
      ),
    );
  }
}

extension AppThemeContext on BuildContext {
  AppSemanticColors get semanticColors =>
      Theme.of(this).extension<AppSemanticColors>()!;
}
