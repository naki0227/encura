package com.enludus.encura

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class HomeWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_layout).apply {
                val title = widgetData.getString("title", "StudyReel")
                val message = widgetData.getString("message", "No Data")
                setTextViewText(R.id.widget_title, title)
                setTextViewText(R.id.widget_message, message)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
