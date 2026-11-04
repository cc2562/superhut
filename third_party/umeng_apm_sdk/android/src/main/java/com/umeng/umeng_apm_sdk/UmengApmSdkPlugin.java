package com.umeng.umeng_apm_sdk;

import android.content.Context;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;
import android.view.WindowManager;
import androidx.annotation.NonNull;

import com.efs.sdk.fluttersdk.FlutterManager;
import com.umeng.umcrash.UMCrash;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.lang.reflect.Field;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;

/**
 * UmengApmSdkPlugin
 */
public class UmengApmSdkPlugin implements FlutterPlugin, MethodCallHandler {
    /// The MethodChannel that will the communication between Flutter and native Android
    ///
    /// This local reference serves to register the plugin with the Flutter Engine and unregister it
    /// when the Flutter Engine is detached from the Activity
    private MethodChannel channel;

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
        mContext = flutterPluginBinding.getApplicationContext();
        channel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), "umeng_apm_sdk");
        channel.setMethodCallHandler(this);
    }

    private static Context mContext = null;

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
        try {
            switch (call.method) {
                case "getPlatformVersion":
                    result.success("Android " + android.os.Build.VERSION.RELEASE);
                    break;
                case "postException":
                    List args = (List) call.arguments;
                    postException(args);
                    break;
                case "getNativeParams":
                    Map<String, Object> nativeParams = FlutterManager.getNativeParams();
                    executeOnMain(result, nativeParams);
                    break;
                case "getCloudConfig":
                    Map<String, Object> cloudConfig = FlutterManager.getCloudConfig();
                    executeOnMain(result, cloudConfig);
                    break;
                case "putIntValue":{
                    String key = call.argument("key");
                    String value = call.argument("value").toString();
                    boolean optResult = FlutterManager.putLongValue(key, Long.valueOf(value));

                    executeOnMain(result, optResult);
                }
                    break;
                case "getIntValue":{
                    String key = call.arguments();
                    long value = FlutterManager.getLongValue(key);
                    executeOnMain(result, value);
                }
                    break;
                case "getSdkVersion":{
                    String version = "";
                    try {
                        Class<?> umCrashClass = Class.forName("com.umeng.umcrash.UMCrash");
                        if (umCrashClass != null) {
                            Field ver = umCrashClass.getDeclaredField("crashSdkVersion");
                            ver.setAccessible(true);
                            version = (String) ver.get(umCrashClass);
                        }
                    } catch (Throwable e){
                    }finally {
                        executeOnMain(result, version);
                    }
                }
                    break;
                case "getNativeFPS":{
                    if(getContext()!=null){
                        WindowManager windowManager = (WindowManager) getContext().getSystemService(Context.WINDOW_SERVICE);
                        float fps = windowManager.getDefaultDisplay().getRefreshRate();
                        executeOnMain(result, fps);
                    }else{
                        executeOnMain(result, -1);
                    }

                }
                    break;
                default:
                    result.notImplemented();
                    break;
            }
        } catch (Exception e) {
            e.printStackTrace();
            android.util.Log.e("Umeng", "Exception:" + e.getMessage());
        }
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        channel.setMethodCallHandler(null);
    }

    public static void setContext(Context ctx) {
        mContext = ctx;
    }

    public static Context getContext() {
        return mContext;
    }

    private void postException(List args) {
        String error = (String) args.get(0);
        String stack = (String) args.get(1);
        String des = "error:" + error + "\n" + "stack:" + stack;
        UMCrash.generateCustomLog(des, "flutter_dart");
    }

    private final Handler mHandler = new Handler(Looper.getMainLooper());

    private void executeOnMain(final Result result, final Object param) {
        if (Looper.myLooper() == Looper.getMainLooper()) {
            try {
                result.success(param);
            } catch (Throwable throwable) {
                throwable.printStackTrace();
            }
            return;
        }
        mHandler.post(new Runnable() {
            @Override
            public void run() {
                try {
                    result.success(param);
                } catch (Throwable throwable) {
                    throwable.printStackTrace();
                }
            }
        });
    }
}
