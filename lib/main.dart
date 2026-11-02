import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superhut/pages/score/jumpToScorePage.dart';
import 'package:superhut/welcomepage/view.dart';
import 'agreement/agreement_controller.dart';
import 'agreement/consent_page.dart';
import 'analytics/clarity_service.dart';
import 'home/coursetable/style/course_table_style_controller.dart';
import 'live_activity/class_live_activity_controller.dart';
import 'privacy/privacy_consent_controller.dart';
import 'security/credential_store.dart';
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

  // 预编译液态玻璃着色器：首帧即为玻璃，而不是先显示磨砂再切换。
  // 失败时包内会自动退化为磨砂，不阻塞启动。
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS)) {
    try {
      await LiquidGlassShaders.ensureLoaded();
    } catch (_) {
      // 忽略：无 shader 支持的环境让玻璃自行降级。
    }
  }

  // 把老版本明文存在 SharedPreferences 里的凭据搬进系统安全存储并删掉原键。
  // 幂等且失败不阻塞启动；放在 runApp 之前，后续任何读取都能直接命中新位置。
  await CredentialStore.instance.migrateFromPrefs();

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
  static const platform = MethodChannel(
    'com.superhut.rice.superhut/widget_actions',
  );
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  final ThemeController themeController = Get.put(ThemeController());

  /// 课表外观（背景 / 课程块材质）与主题并列注册，供课表页与设置页共享。
  final CourseTableStyleController courseStyleController = Get.put(
    CourseTableStyleController(),
  );

  /// 协议同意状态：未同意前只显示同意页，且不启动任何统计 SDK。
  final AgreementController agreementController = Get.put(
    AgreementController(),
  );

  /// 行为分析（Clarity）的单独同意状态，与协议同意相互独立。
  late final PrivacyConsentController privacyConsentController = Get.put(
    PrivacyConsentController(agreement: agreementController),
  );

  /// 灵动岛课程提醒（仅 iOS）：注册在 main 里，未打开课表页也能在回到前台时补发。
  final ClassLiveActivityController liveActivityController = Get.put(
    ClassLiveActivityController(),
  );

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
      // 未同意协议时只显示同意页，小组件跳转不能绕过这道门槛。
      if (!agreementController.accepted) return;
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
    await courseStyleController.load();
    await agreementController.load();
    await privacyConsentController.load();
    await liveActivityController.load();
    // await prefs.setBool('isFirstOpen', true);
    _isFirstOpen = prefs.getBool('isFirstOpen') ?? true;
    setState(() {
      _isFirstOpen = _isFirstOpen;
      _isLoading = false;
    });
    // 冷启动时用户此前已经同意过：等首帧渲染完成后再启动采集。
    // 这里必须用 navigatorKey 的 context（在 MaterialApp 之内、带 MediaQuery），
    // MyApp 自身的 context 在 MaterialApp 之上，SDK 会拒绝初始化。
    _scheduleAnalyticsStart();
  }

  /// 已同意时在首帧后幂等启动 Clarity。
  ///
  /// 未同意（包括同意过协议但没勾选行为分析）时什么都不做，
  /// 用户之后仍可在「隐私设置」里手动开启。
  void _scheduleAnalyticsStart() {
    if (!privacyConsentController.analyticsAllowed) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final BuildContext? context = navigatorKey.currentContext;
      if (context == null) return;
      ClarityService.start(context);
    });
  }

  /// 首页三级选择：未同意协议 → 同意页；已同意但未登录 → 欢迎页；否则首页。
  ///
  /// 同意页放在最前面，保证任何登录/课表等业务页面都不会先于同意出现，
  /// 统计 SDK 也就永远不可能在未同意时启动。
  Widget _buildHome() {
    if (!agreementController.accepted) {
      return AgreementConsentPage(onAccept: _handleAgreementAccepted);
    }
    return _isFirstOpen ? WelcomepagePage() : const HomeviewPage();
  }

  Future<void> _handleAgreementAccepted(
    BuildContext consentContext, {
    required bool analyticsConsent,
  }) async {
    await agreementController.accept();
    await privacyConsentController.setAnalyticsConsent(analyticsConsent);
    // 先启动 Clarity 再切页面：这次拿的是同意页的 context（位于 MaterialApp 内、
    // 带 MediaQuery），页面切走后它就会被销毁。
    // 未勾选行为分析时不调用任何 SDK 方法，应用照常可用。
    if (analyticsConsent && consentContext.mounted) {
      ClarityService.start(consentContext);
    }
    if (mounted) setState(() {});
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
            home: _buildHome(),
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
