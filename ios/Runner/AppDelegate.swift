import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  /// 必须持有引用：方法通道的 handler 由它注册，释放后回调就断了。
  private var liveActivityBridge: LiveActivityBridge?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    if let controller = window?.rootViewController as? FlutterViewController {
      liveActivityBridge = LiveActivityBridge(messenger: controller.binaryMessenger)
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
