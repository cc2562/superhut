package com.superhut.rice.superhut;

import android.app.PendingIntent;
import android.appwidget.AppWidgetManager;
import android.appwidget.AppWidgetProvider;
import android.content.Context;
import android.content.Intent;
import android.content.ComponentName;
import android.os.Build;
import android.util.Log;
import android.widget.RemoteViews;

/**
 * 快捷功能桌面小组件提供者
 * 实现4个快捷按钮：宿舍喝水、洗澡、电费充值、成绩查询
 */
public class QuickActionWidgetProvider extends AppWidgetProvider {

    public static final String ACTION_DRINK = "com.superhut.rice.superhut.ACTION_DRINK";
    public static final String ACTION_BATH = "com.superhut.rice.superhut.ACTION_BATH";
    public static final String ACTION_ELECTRICITY = "com.superhut.rice.superhut.ACTION_ELECTRICITY";
    public static final String ACTION_SCORE = "com.superhut.rice.superhut.ACTION_SCORE";
    
    private static final String TAG = "QuickActionWidgetProv";
    
    // 为快捷功能小组件使用不同的requestCode基数，避免与课程表小组件冲突
    private static final int QUICK_ACTION_BASE_REQUEST_CODE = 10000;

    @Override
    public void onUpdate(Context context, AppWidgetManager appWidgetManager, int[] appWidgetIds) {
        Log.d(TAG, "onUpdate 被调用，更新快捷按钮小组件");
        for (int appWidgetId : appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId);
        }
    }

    @Override
    public void onEnabled(Context context) {
        super.onEnabled(context);
        Log.d(TAG, "onEnabled 被调用，第一次添加快捷按钮小组件");
    }

    @Override
    public void onDisabled(Context context) {
        super.onDisabled(context);
        Log.d(TAG, "onDisabled 被调用，移除所有快捷按钮小组件");
    }

    @Override
    public void onReceive(Context context, Intent intent) {
        super.onReceive(context, intent);

        String action = intent.getAction();
        Log.d(TAG, "接收到广播: " + action);

        // 处理按钮点击事件
        if (ACTION_DRINK.equals(action) || ACTION_BATH.equals(action) || 
            ACTION_ELECTRICITY.equals(action) || ACTION_SCORE.equals(action)) {
            
            // 打开应用并传递相应的参数
            openAppWithAction(context, action);
        }
    }

    /**
     * 打开应用并传递动作参数
     */
    private void openAppWithAction(Context context, String action) {
        Intent launchIntent = context.getPackageManager().getLaunchIntentForPackage(context.getPackageName());
        if (launchIntent != null) {
            launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP);
            launchIntent.putExtra("widget_action", action);
            
            try {
                context.startActivity(launchIntent);
                Log.d(TAG, "启动应用，动作: " + action);
            } catch (Exception e) {
                Log.e(TAG, "启动应用失败: " + e.getMessage());
            }
        }
    }

    /**
     * 更新小组件的方法
     */
    static void updateAppWidget(Context context, AppWidgetManager appWidgetManager, int appWidgetId) {
        Log.d(TAG, "更新快捷按钮小组件 ID: " + appWidgetId);
        
        try {
            // 创建视图
            RemoteViews views = new RemoteViews(context.getPackageName(), R.layout.quick_action_widget);

            // 设置各个按钮的点击事件，使用不同的requestCode
            setupButtonClickEvent(context, views, R.id.btn_drink, ACTION_DRINK, QUICK_ACTION_BASE_REQUEST_CODE + 1);
            setupButtonClickEvent(context, views, R.id.btn_bath, ACTION_BATH, QUICK_ACTION_BASE_REQUEST_CODE + 2);
            setupButtonClickEvent(context, views, R.id.btn_electricity, ACTION_ELECTRICITY, QUICK_ACTION_BASE_REQUEST_CODE + 3);
            setupButtonClickEvent(context, views, R.id.btn_score, ACTION_SCORE, QUICK_ACTION_BASE_REQUEST_CODE + 4);

            // 设置标题点击打开应用
            Intent openAppIntent = context.getPackageManager().getLaunchIntentForPackage(context.getPackageName());
            if (openAppIntent != null) {
                PendingIntent openAppPendingIntent = createPendingIntent(context, openAppIntent, QUICK_ACTION_BASE_REQUEST_CODE, false);
                views.setOnClickPendingIntent(R.id.widget_title, openAppPendingIntent);
            }

            // 更新小组件
            appWidgetManager.updateAppWidget(appWidgetId, views);
            Log.d(TAG, "快捷按钮小组件更新完成");
        } catch (Exception e) {
            Log.e(TAG, "更新快捷按钮小组件视图时出错: " + e.getMessage(), e);
        }
    }

    /**
     * 设置按钮点击事件
     */
    private static void setupButtonClickEvent(Context context, RemoteViews views, int buttonId, String action, int requestCode) {
        Intent intent = new Intent(context, QuickActionWidgetProvider.class);
        intent.setAction(action);
        // 添加额外的数据确保Intent的唯一性
        intent.putExtra("button_id", buttonId);
        intent.putExtra("timestamp", System.currentTimeMillis());
        
        PendingIntent pendingIntent = createPendingIntent(context, intent, requestCode, true);
        views.setOnClickPendingIntent(buttonId, pendingIntent);
    }

    /**
     * 创建PendingIntent的统一方法，处理不同Android版本的兼容性
     */
    private static PendingIntent createPendingIntent(Context context, Intent intent, int requestCode, boolean isBroadcast) {
        int flags = PendingIntent.FLAG_UPDATE_CURRENT;
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            flags |= PendingIntent.FLAG_IMMUTABLE;
        }

        if (isBroadcast) {
            return PendingIntent.getBroadcast(context, requestCode, intent, flags);
        } else {
            return PendingIntent.getActivity(context, requestCode, intent, flags);
        }
    }
} 