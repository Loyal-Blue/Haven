package app.havenlife.haven

import android.Manifest
import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import androidx.core.app.NotificationCompat
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar

class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val reminders = read(context)
        val id = intent.data?.lastPathSegment
        if (id == null) {
            if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
                for (task in reminders) {
                    if (advance(task)) schedule(context, task)
                }
                save(context, reminders.filter { it.getLong("at") > System.currentTimeMillis() })
            }
            return
        }

        val task = reminders.firstOrNull { it.getString("id") == id } ?: return
        if (task.getLong("at") > System.currentTimeMillis() + 1000L) return
        if (Build.VERSION.SDK_INT < 33 ||
            context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
        ) notify(context, task)

        if (advance(task)) {
            schedule(context, task)
            save(context, reminders)
        } else {
            save(context, reminders.filterNot { it == task })
        }
    }

    companion object {
        private const val channel = "haven-task-reminders"

        fun replace(context: Context, tasks: List<Map<String, Any>>) {
            val updated = tasks.map { JSONObject(it) }
            val manager = context.getSystemService(AlarmManager::class.java)
            for (task in read(context)) manager.cancel(alarm(context, task))
            save(context, updated)
            for (task in updated) schedule(context, task)
        }

        private fun preferences(context: Context) = context.getSharedPreferences("haven-reminders", Context.MODE_PRIVATE)

        private fun read(context: Context): List<JSONObject> {
            val list = JSONArray(preferences(context).getString("schedule", "[]"))
            return (0 until list.length()).map { list.getJSONObject(it) }
        }

        private fun save(context: Context, tasks: List<JSONObject>) {
            preferences(context).edit().putString("schedule", JSONArray(tasks).toString()).apply()
        }

        private fun alarm(context: Context, task: JSONObject): PendingIntent {
            val intent = Intent(context, ReminderReceiver::class.java).apply {
                data = Uri.Builder().scheme("haven").authority("reminder")
                    .appendPath(task.getString("id")).build()
            }
            return PendingIntent.getBroadcast(context, 0, intent, PendingIntent.FLAG_IMMUTABLE)
        }

        private fun schedule(context: Context, task: JSONObject) {
            val at = task.getLong("at")
            if (at <= System.currentTimeMillis()) return
            val manager = context.getSystemService(AlarmManager::class.java)
            manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, alarm(context, task))
        }

        private fun advance(task: JSONObject): Boolean {
            val now = System.currentTimeMillis()
            if (task.getLong("at") > now) return true
            val spacing = task.getInt("repeat")
            if (spacing <= 0) return false
            val date = Calendar.getInstance().apply { timeInMillis = task.getLong("at") }
            while (date.timeInMillis <= now) date.add(Calendar.DAY_OF_YEAR, spacing)
            task.put("at", date.timeInMillis)
            return true
        }

        private fun notify(context: Context, task: JSONObject) {
            val manager = context.getSystemService(NotificationManager::class.java)
            if (Build.VERSION.SDK_INT >= 26) {
                manager.createNotificationChannel(NotificationChannel(
                    channel, "Task reminders", NotificationManager.IMPORTANCE_DEFAULT
                ))
            }
            val open = PendingIntent.getActivity(context, 0, Intent(context, MainActivity::class.java),
                PendingIntent.FLAG_IMMUTABLE)
            val notification = NotificationCompat.Builder(context, channel)
                .setSmallIcon(android.R.drawable.ic_dialog_info)
                .setContentTitle(task.getString("title"))
                .setContentText("Haven task reminder")
                .setAutoCancel(true)
                .setContentIntent(open)
                .build()
            manager.notify(task.getString("id"), 0, notification)
        }
    }
}
