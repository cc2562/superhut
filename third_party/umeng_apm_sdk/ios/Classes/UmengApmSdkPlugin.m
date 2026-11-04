#import "UmengApmSdkPlugin.h"
#import <UMAPM/UMCrashConfigure.h>

@interface UMFlutter : NSObject

+ (NSDictionary *)getCloudConfig;
+ (NSDictionary *)getNativeParams;
+ (BOOL)putLongValue:(long)value forKey:(NSString *)key;
+ (long)getLongValueForKey:(NSString *)key;

@end

@implementation UmengApmSdkPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  FlutterMethodChannel* channel = [FlutterMethodChannel
      methodChannelWithName:@"umeng_apm_sdk"
            binaryMessenger:[registrar messenger]];
  UmengApmSdkPlugin* instance = [[UmengApmSdkPlugin alloc] init];
  [registrar addMethodCallDelegate:instance channel:channel];
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
  if ([@"getPlatformVersion" isEqualToString:call.method]) {
    result([@"iOS " stringByAppendingString:[[UIDevice currentDevice] systemVersion]]);
  } else {
    //result(FlutterMethodNotImplemented);
  }
  BOOL resultCode = [self handleCall:call result:result];
  if (resultCode) return;

  result(FlutterMethodNotImplemented);
}

- (BOOL)handleCall:(FlutterMethodCall*)call result:(FlutterResult)result{
    BOOL resultCode = YES;
    NSArray* arguments = (NSArray *)call.arguments;
    if ([@"postException" isEqualToString:call.method]){
        NSString* error = arguments[0];
        NSString* stack = arguments[1];
        NSArray *stackArr = [stack componentsSeparatedByString:@"#"];
        if (stackArr.count > 0) {
            [UMCrashConfigure reportExceptionWithName:@"flutter_dart" reason:error stackTrace:stackArr];
        }
    }
    else if ([@"getPlatformVersion" isEqualToString:call.method]){
        result([@"iOS " stringByAppendingString:[[UIDevice currentDevice] systemVersion]]);
    }else if ([@"getNativeParams" isEqualToString:call.method]){
        NSDictionary *nativeParmas = [UMFlutter getNativeParams];
        result(nativeParmas);
    }else if ([@"getCloudConfig" isEqualToString:call.method]){
        NSDictionary *cloudConfig = [UMFlutter getCloudConfig];
        result(cloudConfig);
    }else if ([@"putIntValue" isEqualToString:call.method]){
        NSDictionary *params = (NSDictionary *)call.arguments;
        NSString *key = [params valueForKey:@"key"];
        NSNumber *value = [params valueForKey:@"value"];
        BOOL optResult = [UMFlutter putLongValue:value.longValue forKey:key];
        result(@(optResult));
    }else if ([@"getIntValue" isEqualToString:call.method]){
        NSString *key = (NSString *)call.arguments;
        long resultValue = 0;
        if(key!=nil && [key isKindOfClass:[NSString class]]){
            resultValue = [UMFlutter getLongValueForKey:key];
        }
        result(@(resultValue));
    }else if ([@"getSdkVersion" isEqualToString:call.method]){
        NSString *sdkVersion = [UMCrashConfigure getVersion];
        result(sdkVersion);
    }else if ([@"getNativeFPS" isEqualToString:call.method]){
        NSInteger fps = UIScreen.mainScreen.maximumFramesPerSecond;
        result(@(fps));
    }else{
        resultCode = NO;
    }
    return resultCode;
}

@end
