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
import com.superhut.rice.superhut.QuickActionWidgetProvider

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.superhut.rice.superhut/coursetable_widget"
    private val WIDGET_CHANNEL = "com.superhut.rice.superhut/widget_actions"
    private val TAG = "MainActivity"
    private var widgetMethodChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // 课程表小组件通道
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

        // 快捷按钮小组件通道
        widgetMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WIDGET_CHANNEL)
        
        // 检查是否由小组件启动
        checkWidgetAction()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        checkWidgetAction()
    }

    private fun checkWidgetAction() {
        val widgetAction = intent.getStringExtra("widget_action")
        if (widgetAction != null) {
            Log.d(TAG, "检测到小组件操作: $widgetAction")
            handleWidgetAction(widgetAction)
        }
    }

    private fun handleWidgetAction(action: String) {
        val actionType = when (action) {
            QuickActionWidgetProvider.ACTION_DRINK -> "drink"
            QuickActionWidgetProvider.ACTION_BATH -> "bath"
            QuickActionWidgetProvider.ACTION_ELECTRICITY -> "electricity"
            QuickActionWidgetProvider.ACTION_SCORE -> "score"
            else -> return
        }
        
        Log.d(TAG, "处理小组件动作: $actionType")
        
        // 通知Flutter端处理相应的动作
        widgetMethodChannel?.invokeMethod("navigateToFunction", actionType)
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