import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superhut/pages/score/jumpToScorePage.dart';
import 'package:superhut/welcomepage/view.dart';
import 'home/homeview/view.dart';
import 'pages/drink/view/view.dart';
import 'pages/water/view.dart';
import 'pages/Electricitybill/electricityPage.dart';
import 'pages/score/scorepage.dart';

abstract final class AppTheme {
  // The defined light theme.
  static ThemeData light = FlexThemeData.light(
    scheme: FlexScheme.indigoM3,
    usedColors: 1,
    surfaceMode: FlexSurfaceMode.highBackgroundLowScaffold,
    blendLevel: 1,
    appBarStyle: FlexAppBarStyle.background,
    subThemesData: const FlexSubThemesData(
      interactionEffects: true,
      tintedDisabledControls: true,
      blendOnLevel: 10,
      useM2StyleDividerInM3: true,
      elevatedButtonSchemeColor: SchemeColor.onPrimaryContainer,
      elevatedButtonSecondarySchemeColor: SchemeColor.primaryContainer,
      segmentedButtonSchemeColor: SchemeColor.primary,
      inputDecoratorSchemeColor: SchemeColor.primary,
      inputDecoratorIsFilled: true,
      inputDecoratorBackgroundAlpha: 21,
      inputDecoratorBorderType: FlexInputBorderType.outline,
      inputDecoratorRadius: 8.0,
      inputDecoratorUnfocusedHasBorder: false,
      inputDecoratorPrefixIconSchemeColor: SchemeColor.primary,
      popupMenuRadius: 6.0,
      popupMenuElevation: 4.0,
      alignedDropdown: true,
      dialogElevation: 3.0,
      dialogRadius: 20.0,
      drawerIndicatorSchemeColor: SchemeColor.primary,
      bottomNavigationBarMutedUnselectedLabel: false,
      bottomNavigationBarMutedUnselectedIcon: false,
      menuRadius: 6.0,
      menuElevation: 4.0,
      menuBarRadius: 0.0,
      menuBarElevation: 1.0,
      searchBarElevation: 2.0,
      searchViewElevation: 2.0,
      searchUseGlobalShape: true,
      navigationBarSelectedLabelSchemeColor: SchemeColor.primary,
      navigationBarSelectedIconSchemeColor: SchemeColor.onPrimary,
      navigationBarIndicatorSchemeColor: SchemeColor.primary,
      navigationBarBackgroundSchemeColor: SchemeColor.surfaceContainer,
      navigationBarElevation: 0.0,
      navigationRailSelectedLabelSchemeColor: SchemeColor.primary,
      navigationRailSelectedIconSchemeColor: SchemeColor.onPrimary,
      navigationRailUseIndicator: true,
      navigationRailIndicatorSchemeColor: SchemeColor.primary,
      navigationRailIndicatorOpacity: 1.00,
      navigationRailLabelType: NavigationRailLabelType.all,
    ),
    keyColors: const FlexKeyColors(
      useSecondary: true,
      useTertiary: true,
      keepPrimary: true,
    ),
    tones: FlexSchemeVariant.oneHue.tones(Brightness.light),
    visualDensity: FlexColorScheme.comfortablePlatformDensity,
    cupertinoOverrideTheme: const CupertinoThemeData(applyThemeToAll: true),
  );

  // The defined dark theme.
  static ThemeData dark = FlexThemeData.dark(
    scheme: FlexScheme.indigoM3,
    usedColors: 1,
    surfaceMode: FlexSurfaceMode.highBackgroundLowScaffold,
    blendLevel: 4,
    appBarStyle: FlexAppBarStyle.background,
    subThemesData: const FlexSubThemesData(
      interactionEffects: true,
      tintedDisabledControls: true,
      blendOnLevel: 10,
      blendOnColors: true,
      useM2StyleDividerInM3: true,
      elevatedButtonSchemeColor: SchemeColor.onPrimaryContainer,
      elevatedButtonSecondarySchemeColor: SchemeColor.primaryContainer,
      segmentedButtonSchemeColor: SchemeColor.primary,
      inputDecoratorSchemeColor: SchemeColor.primary,
      inputDecoratorIsFilled: true,
      inputDecoratorBackgroundAlpha: 43,
      inputDecoratorBorderType: FlexInputBorderType.outline,
      inputDecoratorRadius: 8.0,
      inputDecoratorUnfocusedHasBorder: false,
      inputDecoratorPrefixIconSchemeColor: SchemeColor.primary,
      popupMenuRadius: 6.0,
      popupMenuElevation: 4.0,
      alignedDropdown: true,
      dialogElevation: 3.0,
      dialogRadius: 20.0,
      drawerIndicatorSchemeColor: SchemeColor.primary,
      bottomNavigationBarMutedUnselectedLabel: false,
      bottomNavigationBarMutedUnselectedIcon: false,
      menuRadius: 6.0,
      menuElevation: 4.0,
      menuBarRadius: 0.0,
      menuBarElevation: 1.0,
      searchBarElevation: 2.0,
      searchViewElevation: 2.0,
      searchUseGlobalShape: true,
      navigationBarSelectedLabelSchemeColor: SchemeColor.primary,
      navigationBarSelectedIconSchemeColor: SchemeColor.onPrimary,
      navigationBarIndicatorSchemeColor: SchemeColor.primary,
      navigationBarBackgroundSchemeColor: SchemeColor.surfaceContainer,
      navigationBarElevation: 0.0,
      navigationRailSelectedLabelSchemeColor: SchemeColor.primary,
      navigationRailSelectedIconSchemeColor: SchemeColor.onPrimary,
      navigationRailUseIndicator: true,
      navigationRailIndicatorSchemeColor: SchemeColor.primary,
      navigationRailIndicatorOpacity: 1.00,
      navigationRailLabelType: NavigationRailLabelType.all,
    ),
    keyColors: const FlexKeyColors(useSecondary: true, useTertiary: true),
    tones: FlexSchemeVariant.oneHue.tones(Brightness.dark),
    visualDensity: FlexColorScheme.comfortablePlatformDensity,
    cupertinoOverrideTheme: const CupertinoThemeData(applyThemeToAll: true),
  );
}

WebViewEnvironment? webViewEnvironment;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
    final availableVersion = await WebViewEnvironment.getAvailableVersion();
    assert(
      availableVersion != null,
      'Failed to find an installed WebView2 Runtime or non-stable Microsoft Edge installation.',
    );

    webViewEnvironment = await WebViewEnvironment.create(
      settings: WebViewEnvironmentSettings(userDataFolder: 'YOUR_CUSTOM_PATH'),
    );
  }

  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    await InAppWebViewController.setWebContentsDebuggingEnabled(kDebugMode);
  }
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarColor: Colors.transparent, // 全局状态栏颜色
      statusBarIconBrightness: Brightness.dark, // 图标颜色（根据背景调整）
    ),
  );
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isFirstOpen = true;
  bool _isLoading = true;
  bool _isOldVersion = false;
  static const platform = MethodChannel('com.superhut.rice.superhut/widget_actions');
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _checkFirstOpen();
    _setupWidgetActionHandler();
  }

  void _setupWidgetActionHandler() {
    platform.setMethodCallHandler((call) async {
      if (call.method == 'navigateToFunction') {
        final actionType = call.arguments as String;
        _handleWidgetAction(actionType);
      }
    });
  }

  void _handleWidgetAction(String actionType) {
    // 等待应用完全加载后再导航
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = navigatorKey.currentContext;
      if (context != null) {
        Widget? targetPage;
        
        switch (actionType) {
          case 'drink':
            targetPage = FunctionDrinkPage();
            break;
          case 'bath':
            targetPage = FunctionHotWaterPage();
            break;
          case 'electricity':
            targetPage = ElectricityPage();
            break;
          case 'score':
            targetPage = JumpToScorePage();
            break;
        }
        
        if (targetPage != null) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => targetPage!),
          );
        }
      }
    });
  }

  Future<void> _checkFirstOpen() async {
    final prefs = await SharedPreferences.getInstance();
    // await prefs.setBool('isFirstOpen', true);
    _isFirstOpen = prefs.getBool('isFirstOpen') ?? true;
    if (_isFirstOpen) {
    } else {
      _isOldVersion = prefs.getString('name') == null ? true : false;
    }
    setState(() {
      _isFirstOpen = _isFirstOpen;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const MaterialApp(home: CircularProgressIndicator());
    }

    return GetMaterialApp(
      navigatorKey: navigatorKey,
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: [const Locale('zh', 'CH'), const Locale('en', 'US')],
      locale: Locale('zh'),
      title: '超级包菜',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: _isFirstOpen ? WelcomepagePage() : const HomeviewPage(),
      // home: LoginPage(),
      builder: (context, child) {
        return ResponsiveBreakpoints.builder(
          breakpoints: [
            const Breakpoint(start: 0, end: 800, name: MOBILE),
            const Breakpoint(start: 801, end: 1920, name: DESKTOP),
            const Breakpoint(start: 1921, end: double.infinity, name: '4K'),
          ],
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
