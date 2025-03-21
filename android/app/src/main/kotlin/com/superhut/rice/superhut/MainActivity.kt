package com.superhut.rice.superhut

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.superhut.rice.superhut.CourseTableWidgetProvider

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.superhut.rice.superhut/coursetable_widget"
    private val TAG = "MainActivity"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
            call, result ->
            Log.d(TAG, "收到方法调用: ${call.method}")
            if (call.method == "refreshCourseTableWidget") {
                val success = refreshWidget()
                Log.d(TAG, "刷新小组件结果: $success")
                result.success(success)
            } else {
                result.notImplemented()
            }
        }
    }

    private fun refreshWidget(): Boolean {
        try {
            Log.d(TAG, "开始刷新小组件")
            
            // 发送刷新广播到小组件
            val intent = Intent(this, CourseTableWidgetProvider::class.java)
            intent.action = CourseTableWidgetProvider.ACTION_REFRESH
            sendBroadcast(intent)
            Log.d(TAG, "已发送刷新广播")

            // 通知所有小组件更新
            val appWidgetManager = AppWidgetManager.getInstance(this)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(
                ComponentName(this, CourseTableWidgetProvider::class.java)
            )
            
            Log.d(TAG, "找到 ${appWidgetIds.size} 个小组件")
            
            if (appWidgetIds.isNotEmpty()) {
                // 更新所有小组件
                val updateIntent = Intent(AppWidgetManager.ACTION_APPWIDGET_UPDATE)
                updateIntent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, appWidgetIds)
                sendBroadcast(updateIntent)
                Log.d(TAG, "已发送更新广播")
                
                // 直接调用更新方法
                appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetIds, com.superhut.rice.superhut.R.id.widget_course_list)
                Log.d(TAG, "已通知数据变化")
            }
            
            return true
        } catch (e: Exception) {
            Log.e(TAG, "刷新小组件时出错: ${e.message}", e)
            return false
        }
    }
}