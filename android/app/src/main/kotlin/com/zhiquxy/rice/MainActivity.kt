package com.zhiquxy.rice

import android.content.Context
import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

class MainActivity : FlutterActivity() {

    companion object {
        const val METHOD_CHANNEL = "com.zhiquxy.rice/live_update"
        const val COURSE_TABLE_WIDGET_CHANNEL =
            "com.superhut.rice.superhut/coursetable_widget"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        NotificationHelper.createChannel(this)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startClassLiveUpdate" -> {
                        val className  = call.argument<String>("className")  ?: "课程"
                        val location   = call.argument<String>("location")   ?: "未知地点"
                        val startTimeMs = call.argument<Long>("startTimeMs") ?: System.currentTimeMillis()
                        val endTimeMs   = call.argument<Long>("endTimeMs")   ?: (System.currentTimeMillis() + 3600_000L)
                        
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            NotificationHelper.showClassNotification(
                                this, className, location, startTimeMs, endTimeMs
                            )
                        }
                        result.success(null)
                    }
                    "stopClassLiveUpdate" -> {
                        NotificationHelper.cancelNotification(this)
                        result.success(null)
                    }
                    "syncSchedule" -> {
                        val classes = call.argument<List<Map<String, Any>>>("classes") ?: emptyList()
                        
                        // Convert to JSON String for persistence
                        val jsonArray = JSONArray()
                        for (c in classes) {
                            val obj = JSONObject()
                            obj.put("className", c["className"])
                            obj.put("location", c["location"])
                            obj.put("startTimeMs", c["startTimeMs"])
                            obj.put("endTimeMs", c["endTimeMs"])
                            jsonArray.put(obj)
                        }
                        
                        ClassScheduleManager.saveSchedule(this, jsonArray.toString())
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            COURSE_TABLE_WIDGET_CHANNEL
        ).setMethodCallHandler { call, result ->
            if (call.method == "refreshCourseTableWidget") {
                val refreshIntent = Intent(this, CourseTableWidgetProvider::class.java).apply {
                    action = CourseTableWidgetProvider.ACTION_REFRESH
                }
                sendBroadcast(refreshIntent)
                result.success(true)
            } else {
                result.notImplemented()
            }
        }
    }
}
