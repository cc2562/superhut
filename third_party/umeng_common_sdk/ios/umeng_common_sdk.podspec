#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint umeng_common_sdk.podspec' to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'umeng_common_sdk'
  s.version          = '0.0.1'
  s.summary          = 'A new Flutter plugin.'
  s.description      = <<-DESC
A new Flutter plugin.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'
  s.dependency 'Flutter'
  s.platform = :ios, '8.0'
  s.dependency 'UMCommon'
  s.dependency 'UMDevice'
  s.static_framework = true

  # 与 umeng_apm_sdk 保持一致：只排除模拟器上的 i386，保留 arm64 模拟器。
  # 原写法 VALID_ARCHS 已废弃且把模拟器架构写死成 x86_64，Apple Silicon 上无法编译。
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
end
