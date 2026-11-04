## 2.3.7

### Features
- 新增鸿蒙（HarmonyOS）平台原生适配支持

## 2.3.6

### Features
- 指标统计优化

## 2.3.5

### Features
- 上报策略优化

## 2.3.4

### Features
- 后台指标统计优化

## 2.3.3

### Features
- 插件及Android Demo工程适配flutter_3.29

## 2.3.2

### Features
- Android依赖原生SDK更新

## 2.3.1

### Features
- 支持网络分析日志采集

## 2.2.1

### Features
- 增加Flutter Boost插件使用日志标识

## 2.2.0

### Features
- 双端（iOS、Android）支持Flutter Boost插件
- 增加设置运行环境

## 2.1.4

### Fixes
- 修复CoverCalculate.findValidChild方法异常 （Null check operator used on a null value）

## 2.1.3

### Enhancements
- 优化增加UMID打印提示，用于后台采样白名单功能

## 2.1.2

### Fixes
- 修复PageFpsRecorder模块变量double类型不匹配问题 

## 2.1.1

### Fixes
- 修复route remove previousRoute对象返回为null，空检查运算符异常问题

## 2.1.0

### Features
- 支持页面性能FP、FCP、TTI等指标采集。
- 支持页面初始化、滚动等状态下帧率采集。
- 初始化入参增加`enableTrackingPageFps` 开启监测页面帧率设置（默认关闭）
    - 详见文档4.2.1部分
- 初始化入参增加`enableTrackingPagePerf` 开启监测页面性能（默认关闭）
    - 详见文档4.2.1部分
- 提供`ApmScrollController` 滚动控制器用于监听fps滚动行为的判别。
    - 详见文档4.2.3部分

### Enhancements
- 优化初始化提示，检测配套的Native APM SDK版本。


## 2.1.0-rc.1

### Features
- 支持页面性能FP、FCP、TTI等指标采集。
- 支持页面初始化、滚动等状态下帧率采集。
- 初始化入参增加`enableTrackingPageFps` 开启监测页面帧率设置（默认关闭）
    - 详见文档4.2.1部分
- 初始化入参增加`enableTrackingPagePerf` 开启监测页面性能（默认关闭）
    - 详见文档4.2.1部分
- 提供`ApmScrollController` 滚动控制器用于监听fps滚动行为的判别。
    - 详见文档4.2.3部分

### Enhancements
- 优化初始化提示，检测配套的Native APM SDK版本。

## 2.0.1

### Enhancements
- 优化SDK初始化提示文案，并提供集成过程中常见错误链接。

### Fixes
- 修复FlutterError.onError异常捕获的错误被归类为自定义异常问题。

## 2.0.0 线下提供 （2023.8.15）

### Features
- 支持双端iOS、Android Dart异常、异常分类分级、PV自动采集.
- 重新封装提供`ExceptionTrace.captureException`方法进行自定义异常主动上报方法.
- 提供可供路由注册监听器 `ApmNavigatorObserver`.
- 提供`ErrorFilter`入参黑白名单设置.
- 提供可供监听上下文异常`UmengApmSdk`初始化类.

## 1.1.0
- 支持iOS 自定义异常上传

## 1.0.0
- 支持Android 自定义异常上传

## 0.0.1
- 初始提交
