package com.zhiquxy.rice

import android.Manifest
import android.content.ContentResolver
import android.content.ContentUris
import android.content.ContentValues
import android.content.Context
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.CalendarContract
import androidx.core.content.ContextCompat
import java.util.TimeZone

/**
 * 系统日历读写桥（只写不读）。
 *
 * 除本 App 自己创建的日历与事件外，不读取任何日历内容；日历 App 里新建或修改的
 * 安排不会回流到超级包菜。
 */
class CalendarSyncBridge(private val context: Context) {

    companion object {
        private const val TAG = "CalendarSync"
        private const val ACCOUNT_NAME = "超级包菜"

        val PERMISSIONS = arrayOf(
            Manifest.permission.READ_CALENDAR,
            Manifest.permission.WRITE_CALENDAR,
        )
    }

    private val resolver: ContentResolver
        get() = context.contentResolver

    fun hasPermission(): Boolean = PERMISSIONS.all {
        ContextCompat.checkSelfPermission(context, it) == PackageManager.PERMISSION_GRANTED
    }

    /**
     * 按显示名查找本 App 的本地日历；不存在就创建。
     *
     * @return 日历 `_ID`，失败返回 -1。
     */
    fun ensureCalendar(displayName: String, color: Int): Long {
        val projection = arrayOf(CalendarContract.Calendars._ID)
        val selection =
            "${CalendarContract.Calendars.CALENDAR_DISPLAY_NAME} = ? AND " +
                "${CalendarContract.Calendars.DELETED} = 0"

        resolver.query(
            CalendarContract.Calendars.CONTENT_URI,
            projection,
            selection,
            arrayOf(displayName),
            null,
        )?.use { cursor ->
            if (cursor.moveToFirst()) return cursor.getLong(0)
        }

        val values = ContentValues().apply {
            put(CalendarContract.Calendars.ACCOUNT_NAME, ACCOUNT_NAME)
            put(CalendarContract.Calendars.ACCOUNT_TYPE, CalendarContract.ACCOUNT_TYPE_LOCAL)
            put(CalendarContract.Calendars.NAME, displayName)
            put(CalendarContract.Calendars.CALENDAR_DISPLAY_NAME, displayName)
            put(CalendarContract.Calendars.CALENDAR_COLOR, color)
            put(CalendarContract.Calendars.CALENDAR_ACCESS_LEVEL, CalendarContract.Calendars.CAL_ACCESS_OWNER)
            put(CalendarContract.Calendars.OWNER_ACCOUNT, ACCOUNT_NAME)
            put(CalendarContract.Calendars.CALENDAR_TIME_ZONE, TimeZone.getDefault().id)
            put(CalendarContract.Calendars.SYNC_EVENTS, 1)
            put(CalendarContract.Calendars.VISIBLE, 1)
        }

        val uri = resolver.insert(calendarsAsSyncAdapterUri(), values) ?: return -1L
        return try {
            ContentUris.parseId(uri)
        } catch (error: Exception) {
            android.util.Log.w(TAG, "create calendar returned unexpected uri", error)
            -1L
        }
    }

    /**
     * 写入单条事件：带 `eventId` 且仍存在时更新，否则插入。
     *
     * @return 事件 `_ID`，失败返回 null（Dart 侧会保留旧记录并在下次同步重试）。
     */
    fun writeEvent(calendarId: Long, raw: Map<*, *>): Long? {
        val title = raw["title"] as? String ?: ""
        val location = raw["location"] as? String ?: ""
        val description = raw["description"] as? String ?: ""
        val start = (raw["startMillis"] as? Number)?.toLong() ?: return null
        val end = (raw["endMillis"] as? Number)?.toLong() ?: return null
        val reminderMinutes = (raw["reminderMinutes"] as? Number)?.toInt() ?: 0
        val existingId = (raw["eventId"] as? String)?.toLongOrNull()

        val values = ContentValues().apply {
            put(CalendarContract.Events.CALENDAR_ID, calendarId)
            put(CalendarContract.Events.TITLE, title)
            put(CalendarContract.Events.DESCRIPTION, description)
            put(CalendarContract.Events.EVENT_LOCATION, location)
            put(CalendarContract.Events.DTSTART, start)
            put(CalendarContract.Events.DTEND, end)
            put(CalendarContract.Events.EVENT_TIMEZONE, TimeZone.getDefault().id)
            put(CalendarContract.Events.HAS_ALARM, if (reminderMinutes > 0) 1 else 0)
        }

        val eventId: Long = if (existingId != null && eventExists(existingId)) {
            resolver.update(
                ContentUris.withAppendedId(CalendarContract.Events.CONTENT_URI, existingId),
                values,
                null,
                null,
            )
            existingId
        } else {
            val uri = resolver.insert(CalendarContract.Events.CONTENT_URI, values) ?: return null
            ContentUris.parseId(uri)
        }

        // 提醒写入失败不能连累事件本身：事件已经在日历里了，必须把 id 交回 Dart，
        // 否则下一轮同步会再插一条，重复提醒反而更多。
        try {
            updateReminder(eventId, reminderMinutes)
        } catch (error: Exception) {
            android.util.Log.w(TAG, "update reminder failed: $eventId", error)
        }
        return eventId
    }

    /** 删除事件，返回成功删除的条数。 */
    fun deleteEvents(eventIds: List<String>): Int {
        var deleted = 0
        for (raw in eventIds) {
            val id = raw.toLongOrNull() ?: continue
            try {
                val rows = resolver.delete(
                    ContentUris.withAppendedId(CalendarContract.Events.CONTENT_URI, id),
                    null,
                    null,
                )
                // 删除是幂等的：事件本来就不在了也算处理成功，否则 Dart 侧会一直
                // 保留这条簿记，每次同步都重试一遍却永远删不完。
                deleted += if (rows > 0 || !eventExists(id)) 1 else 0
            } catch (error: Exception) {
                android.util.Log.w(TAG, "delete event failed: $id", error)
            }
        }
        return deleted
    }

    /** 删除本 App 创建的专属日历（连同其中事件）。 */
    fun deleteCalendar(calendarId: Long): Boolean {
        return try {
            val uri = ContentUris.withAppendedId(calendarsAsSyncAdapterUri(), calendarId)
            resolver.delete(uri, null, null) > 0
        } catch (error: Exception) {
            android.util.Log.w(TAG, "delete calendar failed: $calendarId", error)
            false
        }
    }

    private fun eventExists(eventId: Long): Boolean {
        val projection = arrayOf(CalendarContract.Events._ID)
        resolver.query(
            ContentUris.withAppendedId(CalendarContract.Events.CONTENT_URI, eventId),
            projection,
            null,
            null,
            null,
        )?.use { cursor ->
            if (cursor.moveToFirst()) return true
        }
        return false
    }

    private fun updateReminder(eventId: Long, minutes: Int) {
        resolver.delete(
            CalendarContract.Reminders.CONTENT_URI,
            "${CalendarContract.Reminders.EVENT_ID} = ?",
            arrayOf(eventId.toString()),
        )
        if (minutes <= 0) return

        val values = ContentValues().apply {
            put(CalendarContract.Reminders.EVENT_ID, eventId)
            put(CalendarContract.Reminders.MINUTES, minutes)
            put(CalendarContract.Reminders.METHOD, CalendarContract.Reminders.METHOD_ALERT)
        }
        resolver.insert(CalendarContract.Reminders.CONTENT_URI, values)
    }

    private fun calendarsAsSyncAdapterUri(): Uri =
        CalendarContract.Calendars.CONTENT_URI.buildUpon()
            .appendQueryParameter(CalendarContract.CALLER_IS_SYNCADAPTER, "true")
            .appendQueryParameter(CalendarContract.Calendars.ACCOUNT_NAME, ACCOUNT_NAME)
            .appendQueryParameter(CalendarContract.Calendars.ACCOUNT_TYPE, CalendarContract.ACCOUNT_TYPE_LOCAL)
            .build()
}
