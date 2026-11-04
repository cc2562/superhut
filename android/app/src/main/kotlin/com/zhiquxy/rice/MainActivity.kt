package com.zhiquxy.rice

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {

    companion object {
        const val METHOD_CHANNEL = "com.zhiquxy.rice/live_update"
        const val COURSE_TABLE_WIDGET_CHANNEL =
            "com.superhut.rice.superhut/coursetable_widget"
        const val CALENDAR_SYNC_CHANNEL =
            "com.superhut.rice.superhut/calendar_sync"
        private const val CALENDAR_PERMISSION_REQUEST = 4301
    }

    private val calendarBridge by lazy { CalendarSyncBridge(this) }

    /** 日历读写可能一次性处理上百条事件，放到单线程队列里避免卡 UI。 */
    private val calendarExecutor = Executors.newSingleThreadExecutor()
    private var pendingCalendarPermission: MethodChannel.Result? = null

    override fun onDestroy() {
        calendarExecutor.shutdown()
        super.onDestroy()
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != CALENDAR_PERMISSION_REQUEST) return
        val granted = grantResults.isNotEmpty() &&
            grantResults.all { it == PackageManager.PERMISSION_GRANTED }
        pendingCalendarPermission?.success(granted)
        pendingCalendarPermission = null
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

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CALENDAR_SYNC_CHANNEL
        ).setMethodCallHandler { call, result ->
            val args = call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()
            when (call.method) {
                "hasPermission" -> result.success(calendarBridge.hasPermission())
                "requestPermission" -> {
                    if (calendarBridge.hasPermission()) {
                        result.success(true)
                    } else {
                        pendingCalendarPermission = result
                        ActivityCompat.requestPermissions(
                            this,
                            CalendarSyncBridge.PERMISSIONS,
                            CALENDAR_PERMISSION_REQUEST
                        )
                    }
                }
                "ensureCalendar" -> runCalendarTask(result) {
                    val name = args["name"] as? String ?: "超级包菜课表"
                    val color = (args["color"] as? Number)?.toInt() ?: 0xFF3F51B5.toInt()
                    calendarBridge.ensureCalendar(name, color).takeIf { it > 0 }
                }
                "writeEvents" -> runCalendarTask(result) {
                    val calendarId = (args["calendarId"] as? String)?.toLongOrNull()
                    if (calendarId == null) {
                        null
                    } else {
                        val rawEvents = args["events"] as? List<*> ?: emptyList<Any>()
                        rawEvents.map { raw ->
                            (raw as? Map<*, *>)?.let {
                                calendarBridge.writeEvent(calendarId, it)?.toString()
                            }
                        }
                    }
                }
                "deleteEvents" -> runCalendarTask(result) {
                    val ids = (args["eventIds"] as? List<*>)
                        ?.mapNotNull { it?.toString() } ?: emptyList()
                    calendarBridge.deleteEvents(ids)
                }
                "deleteCalendar" -> runCalendarTask(result) {
                    val calendarId = (args["calendarId"] as? String)?.toLongOrNull()
                    if (calendarId == null) false else calendarBridge.deleteCalendar(calendarId)
                }
                else -> result.notImplemented()
            }
        }
    }

    /**
     * 在单线程队列里执行日历操作，结果回到主线程。
     *
     * 日历写入涉及上百条 ContentResolver 调用，放主线程会明显卡顿；
     * 异常统一转成 `calendar_error`，不向外抛。
     */
    private fun runCalendarTask(
        result: MethodChannel.Result,
        block: () -> Any?,
    ) {
        calendarExecutor.execute {
            try {
                val value = block()
                runOnUiThread { result.success(value) }
            } catch (error: Exception) {
                android.util.Log.e("CalendarSync", "calendar task failed", error)
                runOnUiThread { result.error("calendar_error", error.message, null) }
            }
        }
    }
}
