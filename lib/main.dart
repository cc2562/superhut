import 'package:dynamic_color/dynamic_color.dart';
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
import 'theme/theme_controller.dart';

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
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
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
  static const platform = MethodChannel(
    'com.superhut.rice.superhut/widget_actions',
  );
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  final ThemeController themeController = Get.put(ThemeController());

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
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (context) => targetPage!));
        }
      }
    });
  }

  Future<void> _checkFirstOpen() async {
    final prefs = await SharedPreferences.getInstance();
    await themeController.load();
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
      return MaterialApp(
        theme: themeController.lightTheme,
        home: const Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        themeController.configureDynamicSchemes(lightDynamic, darkDynamic);
        return Obx(
          () => GetMaterialApp(
            navigatorKey: navigatorKey,
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
            locale: const Locale('zh', 'CN'),
            title: '超级包菜',
            theme: themeController.lightTheme,
            darkTheme: themeController.darkTheme,
            themeMode: themeController.themeMode.value,
            home: _isFirstOpen ? WelcomepagePage() : const HomeviewPage(),
            builder: (context, child) {
              final theme = Theme.of(context);
              final isDark = theme.brightness == Brightness.dark;
              final overlayStyle = SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness:
                    isDark ? Brightness.light : Brightness.dark,
                systemNavigationBarColor: theme.colorScheme.surface,
                systemNavigationBarIconBrightness:
                    isDark ? Brightness.light : Brightness.dark,
              );
              return AnnotatedRegion<SystemUiOverlayStyle>(
                value: overlayStyle,
                child: ResponsiveBreakpoints.builder(
                  breakpoints: const [
                    Breakpoint(start: 0, end: 800, name: MOBILE),
                    Breakpoint(start: 801, end: 1920, name: DESKTOP),
                    Breakpoint(start: 1921, end: double.infinity, name: '4K'),
                  ],
                  child: child ?? const SizedBox.shrink(),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
