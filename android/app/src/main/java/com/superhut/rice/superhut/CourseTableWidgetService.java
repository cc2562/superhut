package com.zhiquxy.rice;

import android.annotation.TargetApi;
import android.content.Context;
import android.content.Intent;
import android.os.Build;
import android.os.Bundle;
import android.util.Log;
import android.widget.RemoteViews;
import android.widget.RemoteViewsService;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileReader;
import java.io.IOException;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.List;

/**
 * 课程表小组件服务类
 * 用于提供ListView的数据
 */
@TargetApi(Build.VERSION_CODES.HONEYCOMB)
public class CourseTableWidgetService extends RemoteViewsService {
    private static final String TAG = "WidgetService";

    @Override
    public RemoteViewsFactory onGetViewFactory(Intent intent) {
        Log.d(TAG, "创建RemoteViewsFactory");
        return new CourseTableRemoteViewsFactory(this.getApplicationContext(), intent);
    }

    /**
     * 课程表小组件的工厂类
     * 用于创建RemoteViews列表
     */
    class CourseTableRemoteViewsFactory implements RemoteViewsService.RemoteViewsFactory {

        private final Context context;
        private List<CourseTableWidgetProvider.CourseInfo> courses = new ArrayList<>();
        private final String todayDate;
        private final int appWidgetId;

        public CourseTableRemoteViewsFactory(Context context, Intent intent) {
            this.context = context;
            this.todayDate = intent.getStringExtra("today_date");
            this.appWidgetId = intent.getIntExtra(
                    "appWidgetId", 
                    intent.getIntExtra("appWidgetId", 0));
            Log.d(TAG, "初始化工厂，日期：" + todayDate + ", 小组件ID: " + appWidgetId);
        }

        @Override
        public void onCreate() {
            // 初始化时，暂不加载数据
            Log.d(TAG, "onCreate调用");
        }

        @Override
        public void onDataSetChanged() {
            // 当数据集变化时，重新加载数据
            Log.d(TAG, "onDataSetChanged调用，重新加载数据");
            courses.clear();
            courses.addAll(loadTodayCourses());
            Log.d(TAG, "加载到" + courses.size() + "门课程");
            
            // 按照开始节数排序
            Collections.sort(courses, new Comparator<CourseTableWidgetProvider.CourseInfo>() {
                @Override
                public int compare(CourseTableWidgetProvider.CourseInfo c1, CourseTableWidgetProvider.CourseInfo c2) {
                    return Integer.compare(c1.startSection, c2.startSection);
                }
            });
        }

        @Override
        public void onDestroy() {
            courses.clear();
            Log.d(TAG, "onDestroy调用");
        }

        @Override
        public int getCount() {
            Log.d(TAG, "getCount: " + courses.size());
            return courses.size();
        }

        @Override
        public RemoteViews getViewAt(int position) {
            Log.d(TAG, "getViewAt: " + position);
            if (position < 0 || position >= courses.size()) {
                Log.e(TAG, "位置越界: " + position);
                return null;
            }
            
            try {
                CourseTableWidgetProvider.CourseInfo course = courses.get(position);
                Log.d(TAG, "创建课程视图: " + course.name);
                
                RemoteViews views = new RemoteViews(context.getPackageName(), R.layout.coursetable_widget_item);
                
                // 设置课程数据
                views.setTextViewText(R.id.widget_course_name, course.name);
                views.setTextViewText(R.id.widget_location, course.location);
                views.setTextViewText(R.id.widget_time_start, course.timeStart);
                views.setTextViewText(R.id.widget_section, course.sectionText);
                
                // 设置点击意图
                Intent fillInIntent = new Intent();
                fillInIntent.putExtra("course_name", course.name);
                fillInIntent.putExtra("course_location", course.location);
                
                // 确保点击整个课程项目都能触发事件
                views.setOnClickFillInIntent(R.id.widget_course_item, fillInIntent);
                
                return views;
            } catch (Exception e) {
                Log.e(TAG, "创建视图时出错: " + e.getMessage(), e);
                return new RemoteViews(context.getPackageName(), R.layout.coursetable_widget_item);
            }
        }

        @Override
        public RemoteViews getLoadingView() {
            Log.d(TAG, "getLoadingView调用");
            return null;
        }

        @Override
        public int getViewTypeCount() {
            return 1;
        }

        @Override
        public long getItemId(int position) {
            return position;
        }

        @Override
        public boolean hasStableIds() {
            return true;
        }
        
        /**
         * 加载今日课程
         * @return 课程列表
         */
        private List<CourseTableWidgetProvider.CourseInfo> loadTodayCourses() {
            List<CourseTableWidgetProvider.CourseInfo> result = new ArrayList<>();
            
            try {
                // 获取应用文档目录
                File appDir = context.getFilesDir().getParentFile();
                Log.d(TAG, "应用目录: " + (appDir != null ? appDir.getAbsolutePath() : "null"));
                
                if (appDir != null) {
                    // 尝试从 app_flutter 目录读取
                    File jsonFile = new File(appDir, "app_flutter/course_data.json");
                    Log.d(TAG, "尝试读取文件: " + jsonFile.getAbsolutePath());
                    
                    if (!jsonFile.exists()) {
                        // 如果 app_flutter 目录下没有文件，尝试从应用文档目录读取
                        jsonFile = new File(appDir, "files/course_data.json");
                        Log.d(TAG, "尝试备选路径: " + jsonFile.getAbsolutePath());
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
                        
                        // 解析JSON
                        JSONObject jsonObject = new JSONObject(jsonContent);
                        
                        // 获取今日课程
                        if (jsonObject.has(todayDate)) {
                            JSONArray coursesArray = jsonObject.getJSONArray(todayDate);
                            Log.d(TAG, "今日课程数量: " + coursesArray.length());
                            
                            for (int i = 0; i < coursesArray.length(); i++) {
                                JSONObject courseObject = coursesArray.getJSONObject(i);
                                
                                CourseTableWidgetProvider.CourseInfo course = new CourseTableWidgetProvider.CourseInfo();
                                course.name = courseObject.getString("name");
                                course.location = courseObject.getString("location");
                                course.startSection = courseObject.getInt("startSection");
                                course.duration = courseObject.getInt("duration");
                                
                                // 设置课程时间
                                course.timeStart = CourseTableWidgetProvider.getSectionStartTime(course.startSection);
                                course.sectionText = course.startSection + "-" + (course.startSection + course.duration - 1) + "节";
                                
                                result.add(course);
                                Log.d(TAG, "添加课程: " + course.name + " 在 " + course.location);
                            }
                        } else {
                            Log.d(TAG, "今日无课程: " + todayDate);
                        }
                    } else {
                        Log.e(TAG, "课程数据文件不存在");
                    }
                }
            } catch (IOException | JSONException e) {
                Log.e(TAG, "读取JSON出错: " + e.getMessage(), e);
            }
            
            return result;
        }
    }
}