package com.superhut.rice.superhut;

import android.app.AlarmManager;
import android.app.PendingIntent;
import android.appwidget.AppWidgetManager;
import android.appwidget.AppWidgetProvider;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.net.Uri;
import android.os.Build;
import android.util.Log;
import android.widget.RemoteViews;
import android.widget.Toast;
import android.view.View;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileReader;
import java.io.IOException;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Calendar;
import java.util.Date;
import java.util.List;
import java.util.Locale;

/**
 * 课程表桌面小组件提供者
 * 实现每日课程的显示功能
 */
public class CourseTableWidgetProvider extends AppWidgetProvider {

    public static final String ACTION_REFRESH = "com.superhut.rice.superhut.ACTION_REFRESH";
    public static final String ACTION_AUTO_UPDATE = "com.superhut.rice.superhut.ACTION_AUTO_UPDATE_WIDGET";
    private static final String TODAY_FORMAT = "yyyy-MM-dd";
    private static final String TAG = "CourseTableWidgetProv";
    
    // 为课程表小组件使用专用的requestCode基数，避免与快捷功能小组件冲突
    private static final int COURSE_TABLE_BASE_REQUEST_CODE = 20000;

    // 定时刷新间隔（毫秒）- 默认为30分钟
    private static final long UPDATE_INTERVAL_MS = 30 * 60 * 1000;

    @Override
    public void onUpdate(Context context, AppWidgetManager appWidgetManager, int[] appWidgetIds) {
        Log.d(TAG, "onUpdate 被调用，更新小组件");
        for (int appWidgetId : appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId);
        }

        // 设置定时刷新
        setupPeriodicUpdate(context);
    }

    @Override
    public void onEnabled(Context context) {
        super.onEnabled(context);
        Log.d(TAG, "onEnabled 被调用，第一次添加小组件");

        // 当添加第一个小组件时，设置定时刷新
        setupPeriodicUpdate(context);
    }

    @Override
    public void onDisabled(Context context) {
        super.onDisabled(context);
        Log.d(TAG, "onDisabled 被调用，移除所有小组件");

        // 当移除最后一个小组件时，取消定时刷新
        cancelPeriodicUpdate(context);
    }

    @Override
    public void onReceive(Context context, Intent intent) {
        super.onReceive(context, intent);

        String action = intent.getAction();
        Log.d(TAG, "接收到广播: " + action);

        if (ACTION_REFRESH.equals(action) || ACTION_AUTO_UPDATE.equals(action)) {
            // 获取所有小组件ID
            AppWidgetManager appWidgetManager = AppWidgetManager.getInstance(context);
            ComponentName thisWidget = new ComponentName(context, CourseTableWidgetProvider.class);
            int[] appWidgetIds = appWidgetManager.getAppWidgetIds(thisWidget);

            // 更新所有小组件
            for (int appWidgetId : appWidgetIds) {
                updateAppWidget(context, appWidgetManager, appWidgetId);
            }

            if (ACTION_AUTO_UPDATE.equals(action)) {
                // 如果是自动更新，记录日志
                Log.d(TAG, "执行定时自动刷新");
            }
        } else if (Intent.ACTION_BOOT_COMPLETED.equals(action)) {
            // 系统重启后设置定时刷新
            Log.d(TAG, "系统启动完成，设置定时刷新");
            setupPeriodicUpdate(context);
        }
    }

    // 更新小组件的方法
    static void updateAppWidget(Context context, AppWidgetManager appWidgetManager, int appWidgetId) {
        Log.d(TAG, "更新小组件 ID: " + appWidgetId);
        try {
            // 创建视图
            RemoteViews views = new RemoteViews(context.getPackageName(), R.layout.coursetable_widget);

            // 设置日期
            String todayDate = new SimpleDateFormat(TODAY_FORMAT, Locale.getDefault()).format(new Date());
            Log.d(TAG, "今日日期: " + todayDate);

            // 读取本地JSON数据
            List<CourseInfo> todayCourses = getTodayCourses(context, todayDate);
            Log.d(TAG, "今日课程数量: " + todayCourses.size());

            // 设置标题点击刷新的Intent
            Intent refreshIntent = new Intent(context, CourseTableWidgetProvider.class);
            refreshIntent.setAction(ACTION_REFRESH);
            // 添加额外数据确保Intent唯一性
            refreshIntent.putExtra("widget_id", appWidgetId);
            refreshIntent.putExtra("timestamp", System.currentTimeMillis());
            PendingIntent refreshPendingIntent = createPendingIntent(context, refreshIntent, COURSE_TABLE_BASE_REQUEST_CODE + 1, true);

            views.setOnClickPendingIntent(R.id.widget_title, refreshPendingIntent);

            // 设置点击打开应用的Intent
            Intent openAppIntent = context.getPackageManager().getLaunchIntentForPackage(context.getPackageName());
            if (openAppIntent != null) {
                PendingIntent openAppPendingIntent = createPendingIntent(context, openAppIntent, COURSE_TABLE_BASE_REQUEST_CODE + 2, false);

                // 为空视图设置点击事件
                views.setOnClickPendingIntent(R.id.widget_empty_view, openAppPendingIntent);
            }

            // 处理课程列表
            if (todayCourses.isEmpty()) {
                // 如果今天没有课程
                Log.d(TAG, "今日无课程，显示空视图");
                views.setViewVisibility(R.id.widget_course_list, View.GONE);
                views.setViewVisibility(R.id.widget_empty_view, View.VISIBLE);

                // 首先更新小组件
                appWidgetManager.updateAppWidget(appWidgetId, views);
            } else {
                Log.d(TAG, "今日有课程，显示列表视图");
                views.setViewVisibility(R.id.widget_course_list, View.VISIBLE);
                views.setViewVisibility(R.id.widget_empty_view, View.GONE);

                // 设置ListView的适配器
                Intent serviceIntent = new Intent(context, CourseTableWidgetService.class);
                serviceIntent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId);
                serviceIntent.putExtra("today_date", todayDate);
                // 确保intent是唯一的
                serviceIntent.setData(Uri.parse("content://widget/" + appWidgetId + "/" + System.currentTimeMillis()));

                views.setRemoteAdapter(R.id.widget_course_list, serviceIntent);

                // 设置列表项点击事件模板
                Intent clickIntent = new Intent(context, MainActivity.class);
                clickIntent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId);
                PendingIntent clickPendingIntent = createPendingIntent(context, clickIntent, COURSE_TABLE_BASE_REQUEST_CODE + 3, false);

                views.setPendingIntentTemplate(R.id.widget_course_list, clickPendingIntent);

                // 设置空视图
                views.setEmptyView(R.id.widget_course_list, R.id.widget_empty_view);

                // 首先更新小组件
                appWidgetManager.updateAppWidget(appWidgetId, views);

                // 然后通知数据变化
                appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.widget_course_list);
            }

            Log.d(TAG, "小组件更新完成");
        } catch (Exception e) {
            Log.e(TAG, "更新小组件视图时出错: " + e.getMessage(), e);
        }
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

    /**
     * 获取今日课程
     * @param context 上下文
     * @param todayDate 今日日期字符串 (yyyy-MM-dd)
     * @return 课程列表
     */
    private static List<CourseInfo> getTodayCourses(Context context, String todayDate) {
        List<CourseInfo> courses = new ArrayList<>();

        try {
            // 获取应用文档目录
            File appDir = context.getFilesDir().getParentFile();
            Log.d(TAG, "appDir: " + (appDir != null ? appDir.getAbsolutePath() : "null"));

            if (appDir != null) {
                // 尝试从 app_flutter 目录读取
                File jsonFile = new File(appDir, "app_flutter/course_data.json");
                Log.d(TAG, "jsonFile path: " + jsonFile.getAbsolutePath());
                Log.d(TAG, "jsonFile exists: " + jsonFile.exists());

                if (!jsonFile.exists()) {
                    // 如果 app_flutter 目录下没有文件，尝试从应用文档目录读取
                    jsonFile = new File(appDir, "files/course_data.json");
                    Log.d(TAG, "尝试备选路径: " + jsonFile.getAbsolutePath());
                    Log.d(TAG, "备选文件存在: " + jsonFile.exists());
                }

                if (jsonFile.exists()) {
                    // 读取JSON文件
                    StringBuilder stringBuilder = new StringBuilder();
                    BufferedReader reader = new BufferedReader(new FileReader(jsonFile));
                    String line;
                    while ((line = reader.readLine()) != null) {
                        stringBuilder.append(line);
                    }
                    reader.close();

                    String jsonContent = stringBuilder.toString();
                    Log.d(TAG, "JSON内容长度: " + jsonContent.length());

                    if (jsonContent.length() > 0) {
                        // 解析JSON
                        JSONObject jsonObject = new JSONObject(jsonContent);
                        Log.d(TAG, "JSON解析成功，键: " + jsonObject.keys());

                        // 获取今日课程
                        if (jsonObject.has(todayDate)) {
                            JSONArray coursesArray = jsonObject.getJSONArray(todayDate);
                            Log.d(TAG, "找到今日课程: " + todayDate);
                            Log.d(TAG, "今日课程数量: " + coursesArray.length());

                            for (int i = 0; i < coursesArray.length(); i++) {
                                JSONObject courseObject = coursesArray.getJSONObject(i);

                                CourseInfo course = new CourseInfo();
                                course.name = courseObject.getString("name");
                                course.location = courseObject.getString("location");
                                course.startSection = courseObject.getInt("startSection");
                                course.duration = courseObject.getInt("duration");

                                // 设置课程时间
                                course.timeStart = getSectionStartTime(course.startSection);
                                course.sectionText = course.startSection + "-" + (course.startSection + course.duration - 1) + "节";

                                courses.add(course);
                                Log.d(TAG, "添加课程: " + course.name + " 在 " + course.location);
                            }
                        } else {
                            Log.d(TAG, "今日无课程: " + todayDate);
                        }
                    } else {
                        Log.e(TAG, "JSON内容为空");
                    }
                } else {
                    Log.e(TAG, "课程数据文件不存在");
                }
            } else {
                Log.e(TAG, "无法获取应用目录");
            }
        } catch (IOException | JSONException e) {
            Log.e(TAG, "读取JSON出错: " + e.getMessage(), e);
        }

        return courses;
    }

    /**
     * 根据节数获取开始时间
     * @param section 节数
     * @return 时间字符串
     */
    public static String getSectionStartTime(int section) {
        switch (section) {
            case 1: return "08:00";
            case 2: return "08:55";
            case 3: return "10:00";
            case 4: return "10:55";
            case 5: return "14:00";
            case 6: return "14:55";
            case 7: return "16:00";
            case 8: return "16:55";
            case 9: return "19:00";
            case 10: return "19:55";
            case 11: return "21:00";
            default: return "00:00";
        }
    }

    /**
     * 课程信息类
     */
    public static class CourseInfo {
        public String name;
        public String location;
        public int startSection;
        public int duration;
        public String timeStart;
        public String sectionText;
    }

    /**
     * 设置定时刷新任务
     */
    private void setupPeriodicUpdate(Context context) {
        Log.d(TAG, "设置定时刷新任务，间隔: " + (UPDATE_INTERVAL_MS / 1000 / 60) + "分钟");
        AlarmManager alarmManager = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
        if (alarmManager == null) {
            Log.e(TAG, "获取AlarmManager失败");
            return;
        }

        Intent intent = new Intent(context, CourseTableWidgetProvider.class);
        intent.setAction(ACTION_AUTO_UPDATE);
        // 添加额外数据确保Intent唯一性
        intent.putExtra("alarm_type", "auto_update");

        PendingIntent pendingIntent = createPendingIntent(context, intent, COURSE_TABLE_BASE_REQUEST_CODE + 4, true);

        // 取消可能已存在的任务
        alarmManager.cancel(pendingIntent);

        // 设置新的定时任务
        long firstTrigger = System.currentTimeMillis() + UPDATE_INTERVAL_MS;
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            // 对于Android 6.0及以上版本，使用省电的方式
            alarmManager.setAndAllowWhileIdle(AlarmManager.RTC, firstTrigger, pendingIntent);
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
            // 对于Android 4.4及以上版本
            alarmManager.setExact(AlarmManager.RTC, firstTrigger, pendingIntent);
        } else {
            // 对于旧版本Android（基本不会遇到）
            alarmManager.set(AlarmManager.RTC, firstTrigger, pendingIntent);
        }

        Log.d(TAG, "定时刷新任务设置完成");
    }

    /**
     * 取消定时刷新任务
     */
    private void cancelPeriodicUpdate(Context context) {
        Log.d(TAG, "取消定时刷新任务");
        AlarmManager alarmManager = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
        if (alarmManager == null) {
            return;
        }

        Intent intent = new Intent(context, CourseTableWidgetProvider.class);
        intent.setAction(ACTION_AUTO_UPDATE);
        // 添加额外数据确保Intent唯一性（与设置时保持一致）
        intent.putExtra("alarm_type", "auto_update");

        PendingIntent pendingIntent = createPendingIntent(context, intent, COURSE_TABLE_BASE_REQUEST_CODE + 4, true);

        alarmManager.cancel(pendingIntent);
        Log.d(TAG, "定时刷新任务已取消");
    }
}